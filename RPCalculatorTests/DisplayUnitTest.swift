//
//  DisplayUnitTest.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 8/20/24.
//
//  Note: Extension at bottom of DigitView file allows access to private var digitViews,
//        using a trick from: https://stackoverflow.com/a/50136916/2526464
//
//  Test cases:
//  - test01NegativeSigns
//  - test02SignificantDigits
//

import XCTest
@testable import RPCalculator

class DisplayUnitTest: XCTestCase {

    var cvc: CalculatorViewController!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try? super.setUpWithError()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        cvc = storyboard.instantiateViewController(withIdentifier: "CVC") as? CalculatorViewController  // identifier added in Storyboard
        cvc.beginAppearanceTransition(true, animated: false)  // run lifecycle, connect outlets
        cvc.endAppearanceTransition()
        continueAfterFailure = false  // stop existing test case from continuing after failure
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }
    
    // MARK: - Tests
    
    // test negative number with negative exponent
    // verify: -1.234567-89
    func test01NegativeSigns() {
        pressButton(title: "1")
        pressButton(title: "·")
        pressButton(title: "2")
        pressButton(title: "3")
        pressButton(title: "4")
        pressButton(title: "5")
        pressButton(title: "6")
        pressButton(title: "7")
        pressButton(title: "CHS")
        pressButton(title: "EEX")
        pressButton(title: "8")
        pressButton(title: "9")
        pressButton(title: "CHS")
        verifyDigitView(index: 0, digit: "-", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "1", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 2, digit: "2", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: "4", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: "5", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: "6", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 7, digit: "7", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: "-", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: "8", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: "9", trailingDecimal: false, trailingComma: false)
    }
    
    // test significant digits for FIX, SCI, and ENG display formats
    // setup: π 10000 × = 314159.2654
    // verify:
    //   FIX 2   = 314,159.27
    //   FIX 1   = 314,159.3
    //   FIX 0   = 314,159.
    //
    //   SCI 2   = 3.14   05
    //   SCI 1   = 3.1    05
    //   SCI 0   = 3.     05
    //
    //   ENG 3   = 314.2  03
    //   ENG 2   = 314.   03
    //   ENG 1   = 310.   03
    //   ENG 0   = 300.   03
    func test02SignificantDigits() {
        // setup
        // π 10000 ×
        pressButton(title: "g")
        pressButton(title: "EEX")
        pressButton(title: "1")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "×")
        // FIX 2 = 314,159.27
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "2")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "4", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 4, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: "5", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: "9", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 7, digit: "2", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: "7", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: " ", trailingDecimal: false, trailingComma: false)
        // FIX 1 = 314,159.3
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "1")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "4", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 4, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: "5", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: "9", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 7, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: " ", trailingDecimal: false, trailingComma: false)
        // FIX 0 = 314,159.
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "0")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "4", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 4, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: "5", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: "9", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 7, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: " ", trailingDecimal: false, trailingComma: false)
        
        // SCI 2 = 3.14   05
        pressButton(title: "f")
        pressButton(title: "8")
        pressButton(title: "2")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 2, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "4", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 7, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: "0", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: "5", trailingDecimal: false, trailingComma: false)
        // SCI 1 = 3.1    05
        pressButton(title: "f")
        pressButton(title: "8")
        pressButton(title: "1")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 2, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 7, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: "0", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: "5", trailingDecimal: false, trailingComma: false)
        // SCI 0 = 3.     05
        pressButton(title: "f")
        pressButton(title: "8")
        pressButton(title: "0")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 2, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 7, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: "0", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: "5", trailingDecimal: false, trailingComma: false)
        
        // ENG 3 = 314.2  03
        pressButton(title: "f")
        pressButton(title: "9")
        pressButton(title: "3")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "4", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 4, digit: "2", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 7, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: "0", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: "3", trailingDecimal: false, trailingComma: false)
        
        // ENG 2 = 314.   03
        pressButton(title: "f")
        pressButton(title: "9")
        pressButton(title: "2")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "4", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 4, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 7, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: "0", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: "3", trailingDecimal: false, trailingComma: false)
        
        // ENG 1 = 310.   03
        pressButton(title: "f")
        pressButton(title: "9")
        pressButton(title: "1")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: "1", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "0", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 4, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 7, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: "0", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: "3", trailingDecimal: false, trailingComma: false)
        
        // ENG 0 = 300.   03
        pressButton(title: "f")
        pressButton(title: "9")
        pressButton(title: "0")
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "3", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: "0", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: "0", trailingDecimal: true, trailingComma: false)
        verifyDigitView(index: 4, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 5, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 6, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 7, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 8, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 9, digit: "0", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 10, digit: "3", trailingDecimal: false, trailingComma: false)
    }
    
    func verifyDigitView(index: Int, digit: Character, trailingDecimal: Bool, trailingComma: Bool) {
        XCTAssertEqual(cvc.displayView.privateDigitViews[index].digit, digit, "digit \(index) is not correct")
        if trailingDecimal {
            XCTAssertTrue(cvc.displayView.privateDigitViews[index].trailingDecimal, "digit \(index) is missing a decimal point")
        } else {
            XCTAssertFalse(cvc.displayView.privateDigitViews[index].trailingDecimal, "digit \(index) shouldn't have a decimal point")
        }
        if trailingComma {
            XCTAssertTrue(cvc.displayView.privateDigitViews[index].trailingComma, "digit \(index) is missing a comma")
        } else {
            XCTAssertFalse(cvc.displayView.privateDigitViews[index].trailingComma, "digit \(index) should not have a comma")
        }
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
