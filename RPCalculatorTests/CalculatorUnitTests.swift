//
//  CalculatorUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 7/25/24.
//
//  Method for testing UIViewController obtained from:
//  https://oliverpeate.com/testing-a-uiviewcontroller/
//
//  Unit test asserts:
//    XCTAssertEqual(cvc.program.currentInstruction, "001- 32 11", "Instruction is not correct")
//    XCTAssertTrue(cvc.liftStack, "STO key should enable stack lift")
//
//    // wait before continuing test
//    let exp = expectation(description: "Wait for results to display")
//    _ = XCTWaiter.wait(for: [exp], timeout: 1.5)
//
//  Test cases:
//  - test01Basic
//  - test02ConsecutivePrefixes
//  - test03ConsecutivePrefixes
//  - test04RectangularToPolar
//  - test05PolarToRectangular
//  - test06HourToHourMinSec
//  - test07HoursMinSecToHours
//

import XCTest
@testable import RPCalculator

class CalculatorUnitTests: XCTestCase {

    var cvc: CalculatorViewController!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try? super.setUpWithError()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        cvc = storyboard.instantiateViewController(withIdentifier: "CVC") as? CalculatorViewController  // identifier added in Storyboard
        cvc.beginAppearanceTransition(true, animated: false)  // run lifecycle, connect outlets
        cvc.endAppearanceTransition()
        continueAfterFailure = false  // stop existing test case from continuing after failure

        // use this to set display format to 4 digit fixed width before each test
//        pressButton(title: "f")
//        pressButton(title: "7")  // f-7 = FIX
//        pressButton(title: "4")
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }
    
    // MARK: - Tests
    
    // test basic arithmetic
    // verify: 5 ENTER 2 x = 10
    func test01Basic() {
        pressButton(title: "5")
        pressButton(title: "ENTER")
        pressButton(title: "2")
        pressButton(title: "×")
        XCTAssertEqual(cvc.displayStringNumber, 10)
    }
    
    // test last prefix entered is used, if consecutive prefixes entered
    // verify: 5 RCL STO 1 stores 5 in register 1 (ie. STO overrides RCL)
    func test02ConsecutivePrefixes() {
        // STO 8 in register 1
        pressButton(title: "8")
        pressButton(title: "STO")
        pressButton(title: "1")
        // 5 RCL STO 1
        pressButton(title: "5")
        pressButton(title: "RCL")  // set prefix to RCL
        pressButton(title: "STO")  // reset prefix to STO
        pressButton(title: "1")  // store 5 to register 1
        // RCL 1
        pressButton(title: "RCL")
        pressButton(title: "1")
        XCTAssertEqual(cvc.displayStringNumber, 5.0000, "Register 1 is not correct")
    }
    
    // test last prefix entered is used, if consecutive prefixes entered
    // verify: 5 GTO CHS 00 STO .1 stores 5 in register .1 (GTO, CHS after GTO, and STO are all prefixes)
    func test03ConsecutivePrefixes() {
        // STO 8 in register .1
        pressButton(title: "8")
        pressButton(title: "STO")
        pressButton(title: "·")  // button label is not a period
        pressButton(title: "1")
        // 5 GTO CHS 00 STO .1
        pressButton(title: "5")
        pressButton(title: "GTO")  // set prefix to GTO (start of GTO-CHS-nnn)
        pressButton(title: "CHS")  // set prefix to CHS
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "STO")  // reset prefix to STO
        pressButton(title: "·")
        pressButton(title: "1")  // store 5 to register .1
        // RCL .1
        pressButton(title: "RCL")
        pressButton(title: "·")
        pressButton(title: "1")
        XCTAssertEqual(cvc.displayStringNumber, 5.0000, "Register 1 is not correct")
    }

    // test conversion from rectangular to polar coordinates
    // definitions: y ENTER x →P, radius in display, angle in Y register
    // verify: 3 ENTER 4 →P = 5 x≷y 36.8699
    func test04RectangularToPolar() {
        // set units to degrees
        pressButton(title: "g")
        pressButton(title: "7")  // g-7 = DEG
        // 3 ENTER 4 →P
        pressButton(title: "3")
        pressButton(title: "ENTER")
        pressButton(title: "4")
        pressButton(title: "g")
        pressButton(title: "1")  // g-1 = →P
        // results: 5 x≷y 36.8699
        XCTAssertEqual(cvc.displayStringNumber, 5)
        pressButton(title: "x≷y")
        XCTAssertEqual(cvc.displayStringNumber, 36.8699, "Conversion from rectangular to polar coordinates is not correct")
    }
    
    // test conversion from polar to rectangular coordinates
    // definitions: angle ENTER radius →R, x in display, y in Y register
    // verify: 30 ENTER 1 →R = 0.8660 x≷y 0.5000
    func test05PolarToRectangular() {
        // set units to degrees
        pressButton(title: "g")
        pressButton(title: "7")  // g-7 = DEG
        // 30 ENTER 1 →R
        pressButton(title: "3")
        pressButton(title: "0")
        pressButton(title: "ENTER")
        pressButton(title: "1")
        pressButton(title: "f")
        pressButton(title: "1")  // f-1 = →R
        // results: 0.8660 x≷y 0.5000
        XCTAssertEqual(cvc.displayStringNumber, 0.8660, "Conversion from polar to rectangular coordinates is not correct")
        pressButton(title: "x≷y")
        XCTAssertEqual(cvc.displayStringNumber, 0.5, "Conversion from polar to rectangular coordinates is not correct")
    }
    
    // test conversion from decimal hours to hours.minutesSeconds
    // results: H.MMSS.SSSSS
    // verify 1.2345 →H.MS = 1.14042 (1 hr, 14 min, 4.2 sec)
    func test06HourToHourMinSec() {
        // show 5 significant figures
        pressButton(title: "f")
        pressButton(title: "7")  // f-7 = FIX
        pressButton(title: "5")
        // 1.2345 →H.MS
        pressButton(title: "1")
        pressButton(title: "·")
        pressButton(title: "2")
        pressButton(title: "3")
        pressButton(title: "4")
        pressButton(title: "5")
        pressButton(title: "f")
        pressButton(title: "2")  // f-2 = →H.MS
        // results: 1.14042
        XCTAssertEqual(cvc.displayStringNumber, 1.14042, "Conversion from decimal hours to hours.minutesSeconds is not correct")
        // return to 4 significant figures
        pressButton(title: "f")
        pressButton(title: "7")  // f-7 = FIX
        pressButton(title: "4")
    }
    
    // test conversion from hours.minutesSeconds to decimal hours
    // results: H.HHHHH
    // verify 10.30 (10 hr, 30 min) →H = 10.5 hours
    func test07HoursMinSecToHours() {
        // 10.30 →H
        pressButton(title: "1")
        pressButton(title: "0")
        pressButton(title: "·")
        pressButton(title: "3")
        pressButton(title: "0")
        pressButton(title: "g")
        pressButton(title: "2")  // g-2 = →H
        // results: 10.5
        XCTAssertEqual(cvc.displayStringNumber, 10.5, "Conversion from hours.minutesSeconds to decimal hours is not correct")
    }
    
    // MARK: - Utilities
    
    // set stack to known condition
    //   T: 1.0000
    //   Z: 2.0000
    //   Y: 3.0000
    //   X: 4.0000
    // verify: setup leaves stack lift enabled
    func setupStack() {
        // store 1 to register 0, to add to x register, without lifting stack
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "0")
        XCTAssertTrue(cvc.liftStack, "STO key should enable stack lift")
        // setup
        pressButton(title: "1")
        pressButton(title: "ENTER")
        pressButton(title: "2")
        pressButton(title: "ENTER")
        pressButton(title: "3")
        pressButton(title: "ENTER")
        XCTAssertTrue(!cvc.liftStack, "Enter key should disable stack lift")
        pressButton(title: "RCL")
        pressButton(title: "+")
        pressButton(title: "0")  // add register 0 to display (xRegister)
        XCTAssertEqual(cvc.displayStringNumber, 4.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 2.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 1.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 4.0000, "Stack is not correct")
        XCTAssertTrue(cvc.liftStack, "Setup should leave stack lift enabled")
    }

    // create button with input title, and invoke the button action
    func pressButton(title: String) {
        let button = UIButton()
        button.setTitle(title, for: .normal)
        switch title {
        case "√x", "ex", "10x", "yx", "1/x":
            cvc.aToEButtonPressed(button)
        case "CHS":
            cvc.chsButtonPressed(button)
        case "7":
            cvc.sevenButtonPressed(button)
        case "8":
            cvc.eightButtonPressed(button)
        case "9":
            cvc.nineButtonPressed(button)
        case "÷":
            cvc.divideButtonPressed(button)
        case "SST":
            cvc.sstButtonPressed(button)
        case "GTO":
            cvc.gtoButtonPressed(button)
        case "SIN":
            cvc.sinButtonPressed(button)
        case "COS":
            cvc.cosButtonPressed(button)
        case "TAN":
            cvc.tanButtonPressed(button)
        case "EEX":
            cvc.eexButtonPressed(button)
        case "4":
            cvc.fourButtonPressed(button)
        case "5":
            cvc.fiveButtonPressed(button)
        case "6":
            cvc.sixButtonPressed(button)
        case "×":
            cvc.multiplyButtonPressed(button)
        case "R/S":
            cvc.rsButtonPressed(button)
        case "GSB":
            cvc.gsbButtonPressed(button)
        case "R↓":
            cvc.rDownArrowButtonPressed(button)
        case "x≷y":
            cvc.xyButtonPressed(button)
        case "←":
            cvc.leftArrowButtonPressed(button)
        case "1":
            cvc.oneButtonPressed(button)
        case "2":
            cvc.twoButtonPressed(button)
        case "3":
            cvc.threeButtonPressed(button)
        case "–":
            cvc.minusButtonPressed(button)
        case "f":
            cvc.fButtonPressed(button)
        case "g":
            cvc.gButtonPressed(button)
        case "STO":
            cvc.stoButtonPressed(button)
        case "RCL":
            cvc.rclButtonPressed(button)
        case "0":
            cvc.zeroButtonPressed(button)
        case "·":
            cvc.decimalPointButtonPressed(button)
        case "Σ+":
            cvc.summationPlusButtonPressed(button)
        case "+":
            cvc.plusButtonPressed(button)
        case "ENTER":  // ENTER is written vertically on the button, but title is not used in enterButtonPressed(button)
            cvc.enterButtonPressed(button)
        default:
            break
        }
    }
}
