//
//  CalculatorUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 7/25/24.
//
//  Method for testing UIViewController obtained from:
//  https://oliverpeate.com/testing-a-uiviewcontroller/
//
//  Test cases:
//  - test01Basic
//  - test02RectangularToPolar
//  - test03PolarToRectangular
//  - test04HourToHourMinSec
//  - test05HoursMinSecToHours
//  - test06PiWhileEnteringDigits
//  - test07PiAfterEnter
//

import XCTest
@testable import RPCalculator

class CalculatorUnitTests: XCTestCase {

    var cvc: CalculatorViewController!
    var button = UIButton()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try? super.setUpWithError()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        cvc = storyboard.instantiateViewController(withIdentifier: "CVC") as? CalculatorViewController  // identifier added in Storyboard
        cvc.beginAppearanceTransition(true, animated: false)  // run lifecycle, connect outlets
        cvc.endAppearanceTransition()
        
        // use this to set display format to 4 digit fixed width before each test
//        pressButton(title: "f")
//        pressButton(title: "7")  // f-7 is FIX
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
    
    // test conversion from rectangular to polar coordinates
    // definitions: y ENTER x →P, radius in display, angle in Y register
    // verify: 3 ENTER 4 →P = 5 x≷y 36.8699
    func test02RectangularToPolar() {
        // set units to degrees
        pressButton(title: "g")
        pressButton(title: "7")  // g-7 is DEG
        // 3 ENTER 4 →P
        pressButton(title: "3")
        pressButton(title: "ENTER")
        pressButton(title: "4")
        pressButton(title: "g")
        pressButton(title: "1")  // g-1 is →P
        // results: 5 x≷y 36.8699
        XCTAssertEqual(cvc.displayStringNumber, 5)
        pressButton(title: "x≷y")
        XCTAssertEqual(cvc.displayStringNumber, 36.8699, "Conversion from rectangular to polar coordinates is not correct")
    }
    
    // test conversion from polar to rectangular coordinates
    // definitions: angle ENTER radius →R, x in display, y in Y register
    // verify: 30 ENTER 1 →R = 0.8660 x≷y 0.5000
    func test03PolarToRectangular() {
        // set units to degrees
        pressButton(title: "g")
        pressButton(title: "7")  // g-7 is DEG
        // 30 ENTER 1 →R
        pressButton(title: "3")
        pressButton(title: "0")
        pressButton(title: "ENTER")
        pressButton(title: "1")
        pressButton(title: "f")
        pressButton(title: "1")  // f-1 is →R
        // results: 0.8660 x≷y 0.5000
        XCTAssertEqual(cvc.displayStringNumber, 0.8660, "Conversion from polar to rectangular coordinates is not correct")
        pressButton(title: "x≷y")
        XCTAssertEqual(cvc.displayStringNumber, 0.5, "Conversion from polar to rectangular coordinates is not correct")
    }
    
    // test conversion from decimal hours to hours.minutesSeconds
    // results: H.MMSS.SSSSS
    // verify 1.2345 →H.MS = 1.14042 (1 hr, 14 min, 4.2 sec)
    func test04HourToHourMinSec() {
        // show 5 significant figures
        pressButton(title: "f")
        pressButton(title: "7")  // f-7 is FIX
        pressButton(title: "5")
        // 1.2345 →H.MS
        pressButton(title: "1")
        pressButton(title: "·")
        pressButton(title: "2")
        pressButton(title: "3")
        pressButton(title: "4")
        pressButton(title: "5")
        pressButton(title: "f")
        pressButton(title: "2")  // f-2 is →H.MS
        // results: 1.14042
        XCTAssertEqual(cvc.displayStringNumber, 1.14042, "Conversion from decimal hours to hours.minutesSeconds is not correct")
        // return to 4 significant figures
        pressButton(title: "f")
        pressButton(title: "7")  // f-7 is FIX
        pressButton(title: "4")
    }
    
    // test conversion from hours.minutesSeconds to decimal hours
    // results: H.HHHHH
    // verify 10.30 (10 hr, 30 min) →H = 10.5 hours
    func test05HoursMinSecToHours() {
        // 10.30 →H
        pressButton(title: "1")
        pressButton(title: "0")
        pressButton(title: "·")
        pressButton(title: "3")
        pressButton(title: "0")
        pressButton(title: "g")
        pressButton(title: "2")  // g-2 is →H
        // results: 10.5
        XCTAssertEqual(cvc.displayStringNumber, 10.5, "Conversion from hours.minutesSeconds to decimal hours is not correct")
    }
    
    // test pi while user entering digits
    // enter: 10 π x
    // verify:
    // - π during digit entry, ends digit entry (in x register), and pushes π onto stack
    // - T register is duplicated when stack drops (after x)
    func test06PiWhileEnteringDigits() {
        // set stack to known condition
        //   T: 1.0000
        //   Z: 2.0000
        //   Y: 3.0000
        //   X: 4.0000
        // stack lift is enabled
        setupStack()
        // 10 π
        pressButton(title: "1")
        pressButton(title: "0")  // still entering digits
        XCTAssertTrue(cvc.liftStack, "Number keys should not change stack lift")
        pressButton(title: "g")
        pressButton(title: "EEX")  // g-EXE is π
        // verify stack
        //   T: 3.0000
        //   Z: 4.0000
        //   Y: 10.0000
        //   X: 3.1416
        XCTAssertEqual(cvc.displayStringNumber, 3.1416, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 10.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 4.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.1416, "Stack is not correct")
        // multiply x and y registers, drop stack
        pressButton(title: "×")
        // verify stack
        //   T: 3.0000
        //   Z: 3.0000
        //   Y: 4.0000
        //   X: 31.4159
        XCTAssertEqual(cvc.displayStringNumber, 31.4159, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 4.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 31.4159, "Stack is not correct")
    }

    // test pi after enter pressed
    // enter: 10 ENTER π x
    // verify:
    // - π after ENTER overwrite x register
    // - ENTER key disables stack lift
    func test07PiAfterEnter() {
        // set stack to known condition
        //   T: 1.0000
        //   Z: 2.0000
        //   Y: 3.0000
        //   X: 4.0000
        // stack lift is enabled
        setupStack()
        // 10 ENTER
        pressButton(title: "1")
        pressButton(title: "0")
        pressButton(title: "ENTER")
        XCTAssertTrue(!cvc.liftStack, "Enter key should disable stack lift")
        // verify stack
        //   T: 3.0000
        //   Z: 4.0000
        //   Y: 10.0000
        //   X: 10.0000
        XCTAssertEqual(cvc.displayStringNumber, 10.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertTrue(!cvc.liftStack, "R↓ key should re-enable stack lift")
        XCTAssertEqual(cvc.displayStringNumber, 10.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 4.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 10.0000, "Stack is not correct")
        // π
        pressButton(title: "g")
        pressButton(title: "EEX")  // g-EXE is π
        // verify stack
        //   T: 3.0000
        //   Z: 4.0000
        //   Y: 10.0000
        //   X: 3.1416
        XCTAssertEqual(cvc.displayStringNumber, 3.1416, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 10.000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 4.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.1416, "Stack is not correct")
        // multiply x and y registers, drop stack
        pressButton(title: "×")
        // verify stack
        //   T: 3.0000
        //   Z: 3.0000
        //   Y: 4.0000
        //   X: 31.4159
        XCTAssertEqual(cvc.displayStringNumber, 31.4159, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 4.000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 3.0000, "Stack is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, 31.4159, "Stack is not correct")
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
            cvc.subtractButtonPressed(button)
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
            cvc.addButtonPressed(button)
        case "ENTER":  // ENTER is written vertically on the button, but title is not used in enterButtonPressed(button)
            cvc.enterButtonPressed(button)
        default:
            break
        }
    }
}
