//
//  StackUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 8/1/24.
//
//  Test cases:
//  - test01XYSwap
//  - test02LastX
//  - test03RollDownWhileEnteringDigits
//  - test04RollUpWhileEnteringDigits
//  - test05PiWhileEnteringDigits
//  - test06PiAfterEnter
//

import XCTest
@testable import RPCalculator

class StackUnitTests: XCTestCase {

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
        pressButton(title: "f")
        pressButton(title: "7")  // f-7 = FIX
        pressButton(title: "4")
        
        cvc.isUserMode = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }
    
    // MARK: - Tests
    
    //==============================================================//
    // All tests are started with setupStack, setting the stack to: //
    //    T: 1.0000                                                 //
    //    Z: 2.0000                                                 //
    //    Y: 3.0000                                                 //
    //    X: 4.0000                                                 //
    // LSTx: 5.0000                                                 //
    //==============================================================//

    // test swapping X and Y registers using the x≷y button
    // verify:
    //   T: 1.0000     1.0000
    //   Z: 2.0000     2.0000
    //   Y: 3.0000     4.0000
    //   X: 4.0000     3.0000
    //  keys:      x≷y
    func test01XYSwap() {
        setupStack()
        // x≷y
        pressButton(title: "x≷y")
        verifyStack(x: 3.0000, y: 4.0000, z: 2.0000, t: 1.0000)
    }
    
    // test operations (ex. +, SQRT, SIN, →DEG) copy X register to Last X register,
    // but entering numbers or rolling the stack does not; also, pressing LSTx pushes
    // the Last X register onto the stack
    //
    //    T: 1.0000     1.0000     1.0000     7.0000     4.0000     4.0000     4.0000     4.0000     9.0000     9.0000     3.0000
    //    Z: 2.0000     1.0000     2.0000     4.0000     9.0000     4.0000     4.0000     9.0000     3.0000     3.0000     9.0000
    //    Y: 3.0000     2.0000     7.0000     9.0000     9.0000     9.0000     9.0000     3.0000     9.0000     9.0000    28.6479
    //    X: 4.0000     7.0000     4.0000     9.0000     4.0000     9.0000     3.0000     9.0000     0.5000    28.6479     0.5000
    //   keys:       +         LSTx     9 ENTER      LSTx        R↓         √x        LSTx      30 SIN      →DEG       LSTx
    // LSTx: 5.0000     4.0000     4.0000     4.0000     4.0000     4.0000     9.0000     9.0000     9.0000     0.5000     0.5000
    func test02LastX() {
        setupStack()
        // +
        pressButton(title: "+")
        verifyStack(x: 7.0000, y: 2.0000, z: 1.0000, t: 1.0000)
        // LSTx
        pressButton(title: "g")
        pressButton(title: "ENTER")  // g-ENTER = LSTx
        verifyStack(x: 4.0000, y: 7.0000, z: 2.0000, t: 1.0000)
        // 9 ENTER
        pressButton(title: "9")
        pressButton(title: "ENTER")
        verifyStack(x: 9.0000, y: 9.0000, z: 4.0000, t: 7.0000)
        // LSTx
        pressButton(title: "g")
        pressButton(title: "ENTER")  // g-ENTER = LSTx
        verifyStack(x: 4.0000, y: 9.0000, z: 9.0000, t: 4.0000)
        // R↓
        pressButton(title: "R↓")
        verifyStack(x: 9.0000, y: 9.0000, z: 4.0000, t: 4.0000)
        // √x
        pressButton(title: "√x")
        verifyStack(x: 3.0000, y: 9.0000, z: 4.0000, t: 4.0000)
        // LSTx
        pressButton(title: "g")
        pressButton(title: "ENTER")  // g-ENTER = LSTx
        verifyStack(x: 9.0000, y: 3.0000, z: 9.0000, t: 4.0000)
        // 30 SIN
        pressButton(title: "3")
        pressButton(title: "0")
        pressButton(title: "SIN")
        verifyStack(x: 0.5000, y: 9.0000, z: 3.0000, t: 9.0000)
        // →DEG
        pressButton(title: "g")
        pressButton(title: "3")  // g-3 = →DEG
        verifyStack(x: 28.6479, y: 9.0000, z: 3.0000, t: 9.0000)
        // LSTx
        pressButton(title: "g")
        pressButton(title: "ENTER")  // g-ENTER = LSTx
        verifyStack(x: 0.5000, y: 28.6479, z: 9.0000, t: 3.0000)
    }
    
    //==============================================================//
    //  R↓ moves X register to top of stack (T) and the rest down   //
    //  R↑ moves T register to bottom of stack (X) and the rest up  //
    //==============================================================//

    // test pressing R↓ while entering digits
    // verify:
    // - digits are pushed onto stack, before stack is rolled
    //
    //                    inter.    final
    //   T: 1.0000        2.0000  10.0000
    //   Z: 2.0000        3.0000   2.0000
    //   Y: 3.0000        4.0000   3.0000
    //   X: 4.0000       10.0000   4.0000
    //  keys:      10 R↓
    func test03RollDownWhileEnteringDigits() {
        setupStack()
        // 10 R↓
        pressButton(title: "1")
        pressButton(title: "0")  // still entering digits
        pressButton(title: "R↓")
        verifyStack(x: 4.0000, y: 3.0000, z: 2.0000, t: 10.0000)
    }
    
    // test pressing R↑ while entering digits
    // verify:
    // - digits are pushed onto stack, before stack is rolled
    //
    //                    inter.    final
    //   T: 1.0000        2.0000   3.0000
    //   Z: 2.0000        3.0000   4.0000
    //   Y: 3.0000        4.0000  10.0000
    //   X: 4.0000       10.0000   2.0000
    //  keys:      10 R↑
    func test04RollUpWhileEnteringDigits() {
        setupStack()
        // 10 R↑
        pressButton(title: "1")
        pressButton(title: "0")  // still entering digits
        pressButton(title: "g")
        pressButton(title: "R↓")  // g-R↓ = R↑
        verifyStack(x: 2.0000, y: 10.0000, z: 4.0000, t: 3.0000)
    }

    // test pi while user entering digits
    // verify:
    // - π during digit entry, ends digit entry (in x register), and pushes π onto stack
    // - T register is duplicated when stack drops (after x)
    //
    //                   inter.    final
    //   T: 1.0000       2.0000   3.0000     3.0000
    //   Z: 2.0000       3.0000   4.0000     3.0000
    //   Y: 3.0000       4.0000  10.0000     4.0000
    //   X: 4.0000      10.0000   3.1416    31.4159
    //  keys:      10 π                   x
    func test05PiWhileEnteringDigits() {
        setupStack()  // stack lift is enabled
        // 10 π
        pressButton(title: "1")
        pressButton(title: "0")  // still entering digits
        XCTAssertTrue(cvc.liftStack, "Number keys should not change stack lift")
        pressButton(title: "g")
        pressButton(title: "EEX")  // g-EXE = π
        verifyStack(x: 3.1416, y: 10.0000, z: 4.0000, t: 3.0000)
        // x
        pressButton(title: "×")
        verifyStack(x: 31.4159, y: 4.0000, z: 3.0000, t: 3.0000)
    }

    // test pi after enter pressed
    // enter: 10 ENTER π x
    // verify:
    // - π after ENTER overwrite x register
    // - ENTER key disables stack lift
    //
    //   T: 1.0000           3.0000     3.0000     3.0000
    //   Z: 2.0000           4.0000     4.0000     3.0000
    //   Y: 3.0000          10.0000    10.0000     4.0000
    //   X: 4.0000          10.0000     3.1416    31.4159
    //  keys:      10 ENTER          π          x
    func test06PiAfterEnter() {
        // stack lift is enabled
        setupStack()  // stack lift is enabled
        // 10 ENTER
        pressButton(title: "1")
        pressButton(title: "0")
        pressButton(title: "ENTER")
        // verify liftStack and stack
        XCTAssertTrue(!cvc.liftStack, "Enter key should disable stack lift")
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
        pressButton(title: "EEX")  // g-EXE = π
        verifyStack(x: 3.1416, y: 10.0000, z: 4.0000, t: 3.0000)
        // x
        pressButton(title: "×")
        verifyStack(x: 31.4159, y: 4.0000, z: 3.0000, t: 3.0000)
    }

    // MARK: - Utilities
    
    // set stack to known condition
    //    T: 1.0000
    //    Z: 2.0000
    //    Y: 3.0000
    //    X: 4.0000
    // LSTx: 5.0000
    // verify: setup leaves stack lift enabled
    func setupStack() {
        // store 5 as last x
        pressButton(title: "5")
        pressButton(title: "+")
        // verify last x
        pressButton(title: "g")
        pressButton(title: "ENTER")  // g-ENTER = LSTx
        XCTAssertEqual(cvc.displayStringNumber, 5.0000, "LSTx is not correct")
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
        verifyStack(x: 4.0000, y: 3.0000, z: 2.0000, t: 1.0000)
        XCTAssertTrue(cvc.liftStack, "Setup should leave stack lift enabled")
    }
    
    func verifyStack(x: Double, y: Double, z: Double, t: Double) {
        XCTAssertEqual(cvc.displayStringNumber, x, "X register is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, y, "Y register is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, z, "Z register is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, t, "T register is not correct")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.displayStringNumber, x, "X register is not correct")
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
            assert(false, "No button has the title \"\(title)\"")
        }
    }
}
