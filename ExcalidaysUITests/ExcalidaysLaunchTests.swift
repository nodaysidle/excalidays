import XCTest

@MainActor
final class ExcalidaysLaunchTests: XCTestCase {
    func testApplicationLaunches() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()
        XCTAssertTrue(application.windows.firstMatch.waitForExistence(timeout: 5))
    }
}
