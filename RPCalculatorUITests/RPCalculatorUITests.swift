//
//  RPCalculatorUITests.swift
//  RPCalculatorUITests
//
//  Created by Phil Stern on 7/23/24.
//
//  Good tips:
//  https://masilotti.com/ui-testing-cheat-sheet/
//
//  To add unit test capability:
//  - Select: File | New | Target... | Test | UI Testing Bundle
//  - other test files can be added to the unit test project, if they import XCTest
//    and subclass XCTestCase
//
//  Notes:
//  - to prevent unit test from hanging in the simulator (stuck on showing "testing..."):
//    select: Test navigator (command 6) | PRCalculator (Autocreated) | Tests | PRCalculatorUITests | Options...
//    uncheck: Execute in parallel (if possible) | Save
//  - test cases are run in alphabetic order
//  - UI test cases don't have access to application variables (just labels, buttons, table
//    entries,... that appear on screen)
//  - verifying results below required adding a clear-colored label to the app, that is kept in
//    sync with displayString (hidden label doesn't work)
//

import XCTest

// test01ButtonExists
// test02Arithmetic
// test03ConsecutivePrefixes
// test04ConsecutivePrefixes
// test05RadiansDegreesTrig
//
final class RPCalculatorUITests: XCTestCase {

    let app = XCUIApplication()
    var label: XCUIElement!

    // this method is called before the invocation of each test method in the class
    override func setUpWithError() throws {
//        app.launch()  // re-launch app between test cases
        app.activate()  // keep app running between test cases (pick up where previous left off)

        // use this to set display format to 4 digit fixed width before each test
//        app.buttons["f"].tapElement()
//        app.buttons["7"].tapElement()
//        app.buttons["4"].tapElement()

        continueAfterFailure = false  // stop existing test case from continuing after failure
    }

    // this method is called after the invocation of each test method in the class
    override func tearDownWithError() throws {
    }
    
    // test ability to find elements on screen
    // verify "5" button appears on screen
    func test01ButtonExists() {
        let window = app.windows.element(boundBy: 0)
        let element = app.buttons["5"]
        XCTAssert(window.frame.contains(element.frame))
    }

    // test basic arithmetic buttons
    // verify 5 ENTER 2 x = 10
    func test02Arithmetic() {
        app.buttons["5"].tapElement()
        app.buttons["E N T E R"].tapElement()
        app.buttons["2"].tapElement()
        app.buttons["×"].tapElement()
        label = app.staticTexts["10.0000"]  // see if the expected result appears in any on-screen label (clear label)
        XCTAssert(label.exists, "Display should show 10.0000")
    }
    
    // test last prefix entered is used, if consecutive prefixes entered
    // verify 5 RCL STO 1 stores 5 in register 1 (RCL and STO are both prefixes)
    func test03ConsecutivePrefixes() {
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
        label = app.staticTexts["5.0000"]
        XCTAssert(label.exists, "Register 1 should contain 5.0000")
    }
    
    // test last prefix entered is used, if consecutive prefixes entered
    // verify: 5 GTO CHS 00 STO .1 stored 5 in register .1 (GTO, CHS after GTO, and STO are all prefixes)
    func test04ConsecutivePrefixes() {
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
        label = app.staticTexts["5.0000"]
        XCTAssert(label.exists, "Register .1 should contain 5.0000")
    }
    
    // test hyperbolic and inverse hyperbolic trig functions
    // verify:
    //   sinh(1) = 1.1752 and sinh-1() = 1.0
    //   cosh(1) = 1.5431 and cosh-1() = 1.0
    //   tanh(1) = 0.7616 and tanh-1() = 1.0
    func test05HyperbolicTrig() {
        // sinh(1)
        app.buttons["1"].tapElement()
        app.buttons["f"].tapElement()
        app.buttons["GTO"].tapElement()  // HYP
        app.buttons["SIN"].tapElement()
        var label = app.staticTexts["1.1752"]
        XCTAssert(label.exists, "Display should show 1.1752")
        // sinh-1()
        app.buttons["g"].tapElement()
        app.buttons["GTO"].tapElement()  // HYP-1
        app.buttons["SIN"].tapElement()
        label = app.staticTexts["1.0000"]
        XCTAssert(label.exists, "Display should show 1.0000")
        // cosh(1)
        app.buttons["f"].tapElement()
        app.buttons["GTO"].tapElement()
        app.buttons["COS"].tapElement()
        label = app.staticTexts["1.5431"]
        XCTAssert(label.exists, "Display should show 1.5431")
        // cosh-1()
        app.buttons["g"].tapElement()
        app.buttons["GTO"].tapElement()
        app.buttons["COS"].tapElement()
        label = app.staticTexts["1.0000"]
        XCTAssert(label.exists, "Display should show 1.0000")
        // tanh(1)
        app.buttons["f"].tapElement()
        app.buttons["GTO"].tapElement()
        app.buttons["TAN"].tapElement()
        label = app.staticTexts["0.7616"]
        XCTAssert(label.exists, "Display should show 0.7616")
        // tanh-1()
        app.buttons["g"].tapElement()
        app.buttons["GTO"].tapElement()
        app.buttons["TAN"].tapElement()
        label = app.staticTexts["1.0000"]
        XCTAssert(label.exists, "Display should show 1.0000")
    }
    
    // test manipulation of complex numbers
    // verify:
    //   f-I is used to enter imaginary part of complex number
    //   f-(i) shows imaginary part of complex number
    //   f-Re≷Im swaps real and imaginary parts of complex number in display
    //   (1 + 2i) + (3 + 4i) = 4 + 6i
    // other complex operations included in unit tests
    func test06ComplexArithmetic() {
        // enter 1 + 2i
        app.buttons["1"].tapElement()
        app.buttons["E N T E R"].tapElement()
        app.buttons["2"].tapElement()
        app.buttons["f"].tapElement()
        app.buttons["TAN"].tapElement()  // "I" store imaginary part (also enters complex mode)
        var label = app.staticTexts["1.0000"]
        XCTAssert(label.exists, "Display should show real part of complex number: 1.0000")
        // show imaginary part
        app.buttons["f"].tapElement()
        app.buttons["COS"].tapElement()  // (i) show imaginary part for 1.2 sec
        label = app.staticTexts["2.0000"]
        XCTAssert(label.exists, "Display should show imaginary part of complex number: 2.0000")
        // enter 3 + 4i
        app.buttons["3"].tapElement()
        app.buttons["E N T E R"].tapElement()
        app.buttons["4"].tapElement()
        app.buttons["f"].tapElement()
        app.buttons["TAN"].tapElement()  // "I" store imaginary part
        // add
        app.buttons["+"].tapElement()
        label = app.staticTexts["4.0000"]
        XCTAssert(label.exists, "Display should show real part of complex number: 4.0000")
        // show imaginary part
        app.buttons["f"].tapElement()
        app.buttons["–"].tapElement()  // Re≷Im swap real and imaginary part in display
        label = app.staticTexts["6.0000"]
        XCTAssert(label.exists, "Display should show imaginary part of complex number: 6.0000")
        // exit complex mode
        app.buttons["g"].tapElement()
        app.buttons["5"].tapElement()  // CF clear flag
        app.buttons["8"].tapElement()  // flag 8 is for complex mode
    }

    // test programming
    // enter program:
    //   LBL A
    //   10 x
    //   GSB 0
    //   10 ÷
    //   RTN (returns to line 0)
    //
    //   LBL 0
    //   2 +
    //   RTN (returns to line after GSB 0)
    //
    // verify: 5 LBL A = 5.2
    func test07Programming() {
        // enter program mode
        app.buttons["g"].tapElement()
        app.buttons["R/S"].tapElement()
        // CLEAR PRGM - clear existing program, if any
        app.buttons["f"].tapElement()
        app.buttons["R↓"].tapElement()
        var label = app.staticTexts["000-"]
        XCTAssert(label.exists, "Instruction for new program should be '000-'")
        // LBL A
        app.buttons["f"].tapElement()
        app.buttons["SST"].tapElement()
        app.buttons["√x"].tapElement()
        label = app.staticTexts["001-42,21,11"]
        XCTAssert(label.exists, "Instruction for for LBL A should be '000-42,21,11'")
        // 10 x
        app.buttons["1"].tapElement()
        app.buttons["0"].tapElement()
        app.buttons["×"].tapElement()
        // GSB 0
        app.buttons["GSB"].tapElement()
        app.buttons["0"].tapElement()
        label = app.staticTexts["005-  32 0"]
        XCTAssert(label.exists, "Instruction for for GSB 0 should be '005-  32 0'")
        // 10 ÷
        app.buttons["1"].tapElement()
        app.buttons["0"].tapElement()
        app.buttons["÷"].tapElement()
        // RTN
        app.buttons["g"].tapElement()
        app.buttons["GSB"].tapElement()
        label = app.staticTexts["009- 43 32"]
        XCTAssert(label.exists, "Instruction for for RTN should be '009- 43 32'")
        // LBL 0
        app.buttons["f"].tapElement()
        app.buttons["SST"].tapElement()
        app.buttons["0"].tapElement()
        label = app.staticTexts["010-42,21, 0"]
        XCTAssert(label.exists, "Instruction for for LBL 0 should be '010-42,21, 0'")
        // 2 +
        app.buttons["2"].tapElement()
        app.buttons["+"].tapElement()
        // RTN
        app.buttons["g"].tapElement()
        app.buttons["GSB"].tapElement()
        label = app.staticTexts["013- 43 32"]
        XCTAssert(label.exists, "Instruction for for RTN should be '013- 43 32'")
        // exit program mode
        app.buttons["g"].tapElement()
        app.buttons["R/S"].tapElement()
        // enter 5 and run LBL A
        app.buttons["5"].tapElement()
        app.buttons["f"].tapElement()
        app.buttons["√x"].tapElement()
        // verify result is 5.2
        label = app.staticTexts["5.2000"]
        XCTAssert(label.waitForExistence(timeout: 5), "Results of program should be 5.2000")  // allow time for program to run
        // enter program mode
        app.buttons["g"].tapElement()
        app.buttons["R/S"].tapElement()
        // verify program sitting at line 0
        label = app.staticTexts["000-"]
        XCTAssert(label.exists, "Instruction for final RTN should be '000-'")
        // exit program mode
        app.buttons["g"].tapElement()
        app.buttons["R/S"].tapElement()
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
