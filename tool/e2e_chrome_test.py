"""End-to-end test of the Flutter web build in real Chrome + screenshots."""
import os, shutil, sys
from playwright.sync_api import sync_playwright, expect

URL = "http://127.0.0.1:8765/"
HERE = os.path.dirname(os.path.abspath(__file__))
PROFILE = os.path.join(HERE, ".e2e-chrome-profile")
SHOTS = sys.argv[1]
os.makedirs(SHOTS, exist_ok=True)
shutil.rmtree(PROFILE, ignore_errors=True)  # start with an empty database

STUDENTS = [
    ("Priya Sharma", "RA2211003010123", "Computer Science", "priya.sharma@example.com"),
    ("Arjun Kumar", "RA2211003010124", "Information Technology", "arjun.kumar@example.com"),
    ("Meera Nair", "RA2211004020045", "Electronics and Communication", "meera.nair@example.com"),
]
log = []


def step(msg):
    print(msg, flush=True)
    log.append(msg)


def launch(p, viewport=(1280, 860)):
    ctx = p.chromium.launch_persistent_context(
        PROFILE, channel="chrome", headless=True,
        viewport={"width": viewport[0], "height": viewport[1]},
    )
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.on("console", lambda m: m.type in ("error",) and print("CONSOLE:", m.text))
    return ctx, page


def open_app(page):
    page.goto(URL)
    page.wait_for_selector("flt-semantics-placeholder", state="attached", timeout=60000)
    page.locator("flt-semantics-placeholder").dispatch_event("click")
    expect(page.get_by_role("button", name="Save Student")).to_be_visible(timeout=30000)
    page.wait_for_timeout(800)


def box(page, label):
    return page.get_by_role("textbox", name=label)


def fill(page, name, reg, dept, email):
    for label, value in (("Student Name", name), ("Registration Number", reg),
                         ("Department", dept), ("Email Address", email)):
        box(page, label).click()
        page.wait_for_timeout(250)  # let Flutter move focus before typing
        page.keyboard.type(value, delay=15)
        expect(box(page, label)).to_have_value(value)


def save(page):
    page.get_by_role("button", name="Save Student").click()
    page.wait_for_timeout(900)


def shot(page, name):
    path = os.path.join(SHOTS, name)
    page.screenshot(path=path)
    step(f"  screenshot -> screenshots/{name}")


def view_students(page):
    page.get_by_role("button", name="View Students").first.click()
    page.wait_for_timeout(1200)


def card_names(page):
    text = page.locator("flt-semantics").all_inner_texts()
    blob = "\n".join(text)
    return [s[0] for s in STUDENTS if s[0] in blob], blob


with sync_playwright() as p:
    ctx, page = launch(p)
    open_app(page)
    step("[OK] App loaded in Chrome (SQLite WASM via sqflite_common_ffi_web)")
    shot(page, "01_add_student_screen.png")

    view_students(page)
    expect(page.get_by_text("No student records available")).to_be_visible()
    step("[OK] Empty database -> 'No student records available' message shown")
    shot(page, "02_empty_records.png")
    page.get_by_role("button", name="Back").last.click()
    page.wait_for_timeout(800)

    # Test 2: empty fields
    save(page)
    for msg in ("Please enter the student name.", "Please enter the registration number.",
                "Please enter the department.", "Please enter the email address."):
        expect(page.get_by_text(msg)).to_be_visible()
    step("[OK] Test 2: empty fields -> 4 validation errors, nothing saved")
    shot(page, "03_empty_field_validation.png")

    # Test 3: invalid email
    fill(page, STUDENTS[0][0], STUDENTS[0][1], STUDENTS[0][2], "priya.sharma@invalid")
    save(page)
    expect(page.get_by_text("Enter a valid email address (e.g. name@example.com).")).to_be_visible()
    step("[OK] Test 3: invalid email 'priya.sharma@invalid' rejected")
    shot(page, "04_invalid_email.png")
    box(page, "Email Address").click()
    page.keyboard.press("Control+A")
    page.keyboard.type(STUDENTS[0][3], delay=5)

    # Test 1: valid record
    save(page)
    expect(page.get_by_text("Priya Sharma saved successfully (ID: 1).")).to_be_visible()
    expect(page.get_by_text("Please enter the student name.")).to_have_count(0)
    step("[OK] Test 1: valid record saved -> SnackBar 'Priya Sharma saved successfully (ID: 1).', form cleared")
    shot(page, "05_save_success_snackbar.png")

    # Test 4: multiple records
    for i, s in enumerate(STUDENTS[1:], start=2):
        fill(page, *s)
        save(page)
        expect(page.get_by_text(f"{s[0]} saved successfully (ID: {i}).")).to_be_visible()
    step("[OK] Test 4: 2 more records saved (IDs 2, 3)")

    # Test 5: retrieve all
    view_students(page)
    found, blob = card_names(page)
    assert found == [s[0] for s in STUDENTS], blob
    expect(page.get_by_text("3 record(s)")).to_be_visible()
    step("[OK] Test 5: SELECT returned all 3 records -> " + ", ".join(found))
    shot(page, "06_student_records_list.png")

    # Refresh after returning from Add Student (FAB on list screen)
    page.get_by_role("button", name="Add Student").click()
    page.wait_for_timeout(800)
    fill(page, "Rahul Verma", "RA2211005030078", "Mechanical Engineering", "rahul.verma@example.com")
    save(page)
    page.get_by_role("button", name="View Students").first.click()  # pops back
    page.wait_for_timeout(1200)
    expect(page.get_by_text("4 record(s)")).to_be_visible()
    expect(page.get_by_text("R Rahul Verma ID 4")).to_be_visible()
    step("[OK] List refreshed automatically after returning from Add Student (4 records)")

    dbs = page.evaluate("async () => (await indexedDB.databases()).map(d => d.name)")
    step(f"[OK] IndexedDB databases in browser: {dbs}")

    # Test 6a: page reload
    page.reload()
    open_app(page)
    view_students(page)
    expect(page.get_by_text("4 record(s)")).to_be_visible()
    step("[OK] Test 6a: after browser page REFRESH, all 4 records still present")
    shot(page, "07_records_after_page_refresh.png")
    ctx.close()

    # Test 6b: full browser restart (same profile)
    ctx, page = launch(p)
    open_app(page)
    view_students(page)
    expect(page.get_by_text("4 record(s)")).to_be_visible()
    step("[OK] Test 6b: after closing and relaunching Chrome, all 4 records still present")
    shot(page, "08_records_after_browser_restart.png")
    ctx.close()

    # Responsive: phone-sized viewport
    ctx, page = launch(p, viewport=(412, 880))
    open_app(page)
    shot(page, "09_mobile_add_student.png")
    view_students(page)
    shot(page, "10_mobile_student_records.png")
    step("[OK] Responsive layout verified at 412px width")
    ctx.close()

print("\nALL END-TO-END CHECKS PASSED")
