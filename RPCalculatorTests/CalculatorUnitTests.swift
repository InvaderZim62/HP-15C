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
//    XCTAssertEqual(cvc.displayStringNumber, 2, "Display is not correct")
//
//  Test cases:
//  - test01BasicArithmetic
//  - test02StorageRegisters
//  - test03StorageRegisterMath
//  - test04ConsecutivePrefixes
//  - test05ConsecutivePrefixes
//  - test06Xswap
//  - test07RectangularToPolar
//  - test08PolarToRectangular
//  - test09HourToHourMinSec
//  - test10HoursMinSecToHours
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
    func test01BasicArithmetic() {
        pressButton(title: "5")
        pressButton(title: "ENTER")
        pressButton(title: "2")
        pressButton(title: "×")
        XCTAssertEqual(cvc.displayStringNumber, 10)
    }
    
    // test storage registers
    // verify:
    //   1 STO 0, RCL 0
    //   2 STO .0, RCL .0
    //   3 STO 9, RCL 9
    //   4 STO .9, RCL .9
    //   5 STO I, RCL I
    //   6 STO (i), RCL (I), RCL 5  <- store 6 to register pointed to by register I (register 5 from previous step)
    func test02StorageRegisters() {
        // 1 STO 0
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "0")
        // RCL 0
        pressButton(title: "RCL")
        pressButton(title: "0")
        XCTAssertEqual(cvc.displayStringNumber, 1, "Register 0 is not correct")
        // 2 STO .0
        pressButton(title: "2")
        pressButton(title: "STO")
        pressButton(title: "·")
        pressButton(title: "0")
        // RCL .0
        pressButton(title: "RCL")
        pressButton(title: "·")
        pressButton(title: "0")
        XCTAssertEqual(cvc.displayStringNumber, 2, "Register .0 is not correct")
        // 3 STO 9
        pressButton(title: "3")
        pressButton(title: "STO")
        pressButton(title: "9")
        // RCL 9
        pressButton(title: "RCL")
        pressButton(title: "9")
        XCTAssertEqual(cvc.displayStringNumber, 3, "Register 9 is not correct")
        // 4 STO .9
        pressButton(title: "4")
        pressButton(title: "STO")
        pressButton(title: "·")
        pressButton(title: "9")
        // RCL 0
        pressButton(title: "RCL")
        pressButton(title: "·")
        pressButton(title: "9")
        XCTAssertEqual(cvc.displayStringNumber, 4, "Register .9 is not correct")
        // 5 STO I
        pressButton(title: "5")
        pressButton(title: "STO")
        pressButton(title: "TAN")
        // RCL I
        pressButton(title: "RCL")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.displayStringNumber, 5, "Register I is not correct")
        // 6 STO (i)
        pressButton(title: "6")
        pressButton(title: "STO")
        pressButton(title: "COS")
        // RCL I
        pressButton(title: "RCL")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.displayStringNumber, 6, "Register (i) is not correct")
        // RCL 5
        pressButton(title: "RCL")
        pressButton(title: "5")
        XCTAssertEqual(cvc.displayStringNumber, 6, "Register 5 is not correct")
    }
    
    // test storage register math
    // verify:
    //   1 STO 0, 2 STO + 0, RCL 0 (= 3)
    //   5 STO .9, 3 STO - .9, RCL .9 (= 2)
    //   3 STO I, 2 STO x I, RCL I (= 6)
    //   8 STO (i), 2 STO ÷ (i), RCL (i), RCL 6 (= 4)  <- store 8 ÷ 2 to register pointed to by register I (register 6 from previous step)
    func test03StorageRegisterMath() {
        // 1 STO 0
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "0")
        // 2 STO + 0
        pressButton(title: "2")
        pressButton(title: "STO")
        pressButton(title: "+")
        pressButton(title: "0")
        // RCL 0
        pressButton(title: "RCL")
        pressButton(title: "0")
        XCTAssertEqual(cvc.displayStringNumber, 3, "Register 0 is not correct")
        // 5 STO .9
        pressButton(title: "5")
        pressButton(title: "STO")
        pressButton(title: "·")
        pressButton(title: "9")
        // 3 STO – .9
        pressButton(title: "3")
        pressButton(title: "STO")
        pressButton(title: "–")
        pressButton(title: "·")
        pressButton(title: "9")
        // RCL .9
        pressButton(title: "RCL")
        pressButton(title: "·")
        pressButton(title: "9")
        XCTAssertEqual(cvc.displayStringNumber, 2, "Register .9 is not correct")
        // 3 STO I
        pressButton(title: "3")
        pressButton(title: "STO")
        pressButton(title: "TAN")
        // 2 STO × I
        pressButton(title: "2")
        pressButton(title: "STO")
        pressButton(title: "×")
        pressButton(title: "TAN")
        // RCL I
        pressButton(title: "RCL")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.displayStringNumber, 6, "Register I is not correct")
        // 8 STO (i)
        pressButton(title: "8")
        pressButton(title: "STO")
        pressButton(title: "COS")
        // 2 STO ÷ (i)
        pressButton(title: "2")
        pressButton(title: "STO")
        pressButton(title: "÷")
        pressButton(title: "COS")
        // RCL (i)
        pressButton(title: "RCL")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.displayStringNumber, 4, "Register I is not correct")
        // RCL 6
        pressButton(title: "RCL")
        pressButton(title: "6")
        XCTAssertEqual(cvc.displayStringNumber, 4, "Register 6 is not correct")
    }
    
    // test last prefix entered is used, if consecutive prefixes entered
    // verify: 5 RCL STO 1 stores 5 in register 1 (ie. STO overrides RCL)
    func test04ConsecutivePrefixes() {
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
        XCTAssertEqual(cvc.displayStringNumber, 5, "Register 1 is not correct")
    }
    
    // test last prefix entered is used, if consecutive prefixes entered
    // verify: 5 GTO CHS 00 STO .1 stores 5 in register .1 (GTO, CHS after GTO, and STO are all prefixes)
    func test05ConsecutivePrefixes() {
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
        XCTAssertEqual(cvc.displayStringNumber, 5, "Register 1 is not correct")
    }
    
    // test swapping display (X register) with another storage register using the x≷ function
    // setup:
    //   1 STO 0
    //   5 STO .0
    //   4 STO 1
    //   2 STO I
    // verify:
    //   3 x≷ 0 (1 in display, 3 in register 0)
    //   x≷ I   (2 in display, 1 in register I)
    //   x≷ (i) (4 in display, 2 in register 1) - (i) represents register 1, since register I = 1
    //   x≷ .0  (5 in display, 4 in register .0)
    func test06Xswap() {
        // setup
        // 1 STO 0
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "0")
        // 5 STO .0
        pressButton(title: "5")
        pressButton(title: "STO")
        pressButton(title: "·")
        pressButton(title: "0")
        // 4 STO 1
        pressButton(title: "4")
        pressButton(title: "STO")
        pressButton(title: "1")
        // 2 STO I
        pressButton(title: "2")
        pressButton(title: "STO")
        pressButton(title: "TAN")
        
        // test
        // 3 x≷ 0
        pressButton(title: "3")
        pressButton(title: "f")
        pressButton(title: "4")
        pressButton(title: "0")
        XCTAssertEqual(cvc.displayStringNumber, 1, "Display is not correct")
        XCTAssertEqual(cvc.brain.valueFromStorageRegister("0") as! Double, 3, "Storage register 0 is not correct")
        // x≷ I
        pressButton(title: "f")
        pressButton(title: "4")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.displayStringNumber, 2, "Display is not correct")
        XCTAssertEqual(cvc.brain.valueFromStorageRegister("I") as! Double, 1, "Storage register I is not correct")
        // x≷ (i)
        pressButton(title: "f")
        pressButton(title: "4")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.displayStringNumber, 4, "Display is not correct")
        XCTAssertEqual(cvc.brain.valueFromStorageRegister("1") as! Double, 2, "Storage register 1 is not correct")
        // x≷ .0
        pressButton(title: "f")
        pressButton(title: "4")
        pressButton(title: "·")
        pressButton(title: "0")
        XCTAssertEqual(cvc.displayStringNumber, 5, "Display is not correct")
        XCTAssertEqual(cvc.brain.valueFromStorageRegister(".0") as! Double, 4, "Storage register .0 is not correct")
    }

    // test conversion from rectangular to polar coordinates
    // definitions: y ENTER x →P, radius in display, angle in Y register
    // verify: 3 ENTER 4 →P = 5 x≷y 36.8699
    func test07RectangularToPolar() {
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
    func test08PolarToRectangular() {
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
    func test09HourToHourMinSec() {
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
    func test10HoursMinSecToHours() {
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
        XCTAssertEqual(cvc.displayStringNumber, 4, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 2, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 1, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 4, "Stack is not correct")
        XCTAssertTrue(cvc.liftStack, "Setup should leave stack lift enabled")
    }

    // create button with input title, and invoke the button action
    func pressButton(title: String) {
        let button = UIButton()
        button.setTitle(title, for: .normal)
        switch title {
        case "√x", "ex", "10x", "yx", "1/x":  // note: if cvc.isUserMode = true, these will be the non-f prefix versions
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
