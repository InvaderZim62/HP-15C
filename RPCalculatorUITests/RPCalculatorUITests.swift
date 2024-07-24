//
//  RPCalculatorUITests.swift
//  RPCalculatorUITests
//
//  Created by Phil Stern on 7/23/24.
//
//  Good tips:
//  https://masilotti.com/ui-testing-cheat-sheet/
//
//  Re-set each time app is opened in Xcode:
//  - to prevent unit test from hanging in the simulator (showing testing...):
//    select: Test navigator (command 6) | PRCalculator (Autocreated) | Tests | PRCalculatorUITests | Options...
//    uncheck: Execute in parallel (if possible) | Don't Save
//
//  Test cases don't have access to application variables (just labels, buttons, table entries,... that appear on screen).
//  You can access variables in a stand-alone class/struct/enum, by declaring it inside the test case file (see Project39Tests).
//  Verifying results below required adding a clear-colored label to mirror displayString (hidden label doesn't work).
//  https://stackoverflow.com/a/34622903/2526464
//

import XCTest

final class RPCalculatorUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
//        app.launch()
        app.activate()

        // always set display format to fixed with 4 digits (do it manually, for now)
//        app.buttons["f"].tapElement()
//        app.buttons["7"].tapElement()
//        app.buttons["4"].tapElement()

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false  // stop existing test case from continuing

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // test if "5" button appears on-screen
    func testButtonExists() {
        let window = app.windows.element(boundBy: 0)
        let element = app.buttons["5"]
        XCTAssert(window.frame.contains(element.frame))
    }

    // verify 5 ENTER 2 x = 10
    func testArithmetic() {
        app.buttons["5"].tapElement()
        app.buttons["E N T E R"].tapElement()
        app.buttons["2"].tapElement()
        app.buttons["×"].tapElement()
        let label = app.staticTexts["10.0000"]  // see if the expected result appears in any on-screen label (s/b clear label)
        XCTAssert(label.exists, "Display should show 10.0000")
    }
    
    // verify 5 RCL STO 1 stores 5 in register 1
    // ie. only the last prefix "STO" is used
    func testResettingPrefixes1() {
        // setup
        app.buttons["8"].tapElement()  // store 8 in register 1 first, to verify it gets overwritten
        app.buttons["STO"].tapElement()
        app.buttons["1"].tapElement()
        // test
        app.buttons["5"].tapElement()
        app.buttons["RCL"].tapElement()  // set prefix to RCL
        app.buttons["STO"].tapElement()  // reset prefix to STO
        app.buttons["1"].tapElement()  // store 5 to register 1
        // breakdown
        app.buttons["7"].tapElement()
        app.buttons["E N T E R"].tapElement()  // overwrite display to 7
        // results
        app.buttons["RCL"].tapElement()
        app.buttons["1"].tapElement()  // display register 1
        let label = app.staticTexts["5.0000"]  // see if the expected result appears in any on-screen label
        XCTAssert(label.exists, "Register 1 should contain 5.0000")
    }
    
    // verify 5 GTO CHS 00 STO .1 stored 5 in register .1
    // ie. only the last prefix "STO" is used
    func testResettingPrefixes2() {
        // setup
        app.buttons["8"].tapElement()  // store 8 in register .1 first, to verify it gets overwritten
        app.buttons["STO"].tapElement()
        app.buttons["·"].tapElement()  // button label is not a period
        app.buttons["1"].tapElement()
        // test
        app.buttons["5"].tapElement()
        app.buttons["GTO"].tapElement()  // set prefix to GTO (start of GTO-CHS-nnn)
        app.buttons["CHS"].tapElement()  // set prefix to CHS
        app.buttons["0"].tapElement()
        app.buttons["0"].tapElement()
        app.buttons["STO"].tapElement()  // reset prefix to STO
        app.buttons["·"].tapElement()
        app.buttons["1"].tapElement()  // store 5 to register .1
        // breakdown
        app.buttons["7"].tapElement()
        app.buttons["E N T E R"].tapElement()  // overwrite display to 7
        // results
        app.buttons["RCL"].tapElement()
        app.buttons["·"].tapElement()
        app.buttons["1"].tapElement()  // display register .1
        let label = app.staticTexts["5.0000"]  // see if the expected result appears in any on-screen label
        XCTAssert(label.exists, "Register .1 should contain 5.0000")
    }
    
    // enter program:
    //   LBL A
    //   10 x
    //   GSB 0
    //   10 ÷
    //   RTN
    //
    //   LBL 0
    //   2 +
    //   RTN
    //
    // verify 5 LBL A = 5.2
    func testGSBInProgram() {
        // setup
        app.buttons["g"].tapElement()
        app.buttons["R/S"].tapElement()  // enter program mode
        app.buttons["f"].tapElement()
        app.buttons["R↓"].tapElement()  // CLEAR PRGM (delete prior program, if any)
        var label = app.staticTexts["000-"]
        XCTAssert(label.exists, "Instruction for new program should be '000-'")
        
        // program
        app.buttons["f"].tapElement()
        app.buttons["SST"].tapElement()
        app.buttons["√x"].tapElement()  // LBL A
        label = app.staticTexts["001-42,21,11"]
        XCTAssert(label.exists, "Instruction for for LBL A should be '000-42,21,11'")

        app.buttons["1"].tapElement()
        app.buttons["0"].tapElement()
        app.buttons["×"].tapElement()
        
        app.buttons["GSB"].tapElement()
        app.buttons["0"].tapElement()  // GSB 0
        label = app.staticTexts["005-  32 0"]
        XCTAssert(label.exists, "Instruction for for GSB 0 should be '005-  32 0'")
        
        app.buttons["1"].tapElement()
        app.buttons["0"].tapElement()
        app.buttons["÷"].tapElement()
        
        app.buttons["g"].tapElement()
        app.buttons["GSB"].tapElement()  // RTN
        label = app.staticTexts["009- 43 32"]
        XCTAssert(label.exists, "Instruction for for RTN should be '009- 43 32'")

        app.buttons["f"].tapElement()
        app.buttons["SST"].tapElement()
        app.buttons["0"].tapElement()  // LBL 0
        label = app.staticTexts["010-42,21, 0"]
        XCTAssert(label.exists, "Instruction for for LBL 0 should be '010-42,21, 0'")

        app.buttons["2"].tapElement()
        app.buttons["+"].tapElement()
        
        app.buttons["g"].tapElement()
        app.buttons["GSB"].tapElement()  // RTN
        label = app.staticTexts["013- 43 32"]
        XCTAssert(label.exists, "Instruction for for RTN should be '013- 43 32'")

        app.buttons["g"].tapElement()
        app.buttons["R/S"].tapElement()  // exit program mode
        
        // test
        app.buttons["5"].tapElement()  // enter 5
        app.buttons["f"].tapElement()
        app.buttons["√x"].tapElement()  // run LBL A
        // results
        label = app.staticTexts["5.2000"]  // see if the expected result appears in any on-screen label
        XCTAssert(label.waitForExistence(timeout: 5), "Results of program should be 5.2000")  // allow time for running program
        
        // potentially, test single-step mode SST, while program is entered
    }

//    func testLaunchPerformance() throws {
//        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
//            // This measures how long it takes to launch your application.
//            measure(metrics: [XCTApplicationLaunchMetric()]) {
//                XCUIApplication().launch()
//            }
//        }
//    }
}

// Fix for .tap() causing Objective-C exception; "Failed to scroll to visible (by AX action) Button"
// from: https://stackoverflow.com/a/33534187/2526464
extension XCUIElement {
    func tapElement() {
        if self.isHittable {
            self.tap()
        }
        else {
            let coordinate: XCUICoordinate = self.coordinate(withNormalizedOffset: CGVectorMake(0.0, 0.0))
            coordinate.tap()
        }
    }
}
