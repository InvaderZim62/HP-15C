//
//  StatisticsUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 9/23/24.
//
//  Test cases:
//  - test01BasicStatistics
//  - test02StatisticsErrors
//

import XCTest
@testable import RPCalculator

class StatisticsUnitTests: XCTestCase {

    var cvc: CalculatorViewController!
    var button = UIButton()
    var savePrefix: Prefix!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try? super.setUpWithError()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        cvc = storyboard.instantiateViewController(withIdentifier: "CVC") as? CalculatorViewController  // identifier added in Storyboard
        cvc.beginAppearanceTransition(true, animated: false)  // run lifecycle, connect outlets
        cvc.endAppearanceTransition()
        continueAfterFailure = false  // stop existing test case from continuing after failure
        
        cvc.isUserMode = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }
    
    // MARK: - Tests
    
    // test mean, standard deviation, linear regression (line fit), and linear estimation
    // enter:
    //   g xbar          puts mean of x values in X register and mean of y values in Y register
    //   g s             puts standard deviation of x values in X register and deviation of y values in Y register
    //   f L.R.          puts y-intercept of best-fit line in X register and slope of best-fit line in Y register
    //   x f yhat,r      puts y-value of line corresponding to input x in X register and correlation coefficient of line in Y register
    func test01BasicStatistics() {
        // set 2 significant digits
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "2")
        
        create5DataPoints()
        
        // verify mean
        // g xbar
        pressButton(title: "g")
        pressButton(title: "0")
        // verify 40 x≷y 6.40 (X and Y registers)
        XCTAssertEqual(cvc.displayStringNumber, 40, "mean of x values is not correct")
        pressButton(title: "x≷y")
        XCTAssertEqual(cvc.displayStringNumber, 6.40, "mean of y values is not correct")
        
        // verify standard deviation
        // g s
        pressButton(title: "g")
        pressButton(title: "·")
        // verify 31.62 x≷y 1.24 (X and Y registers)
        XCTAssertEqual(cvc.displayStringNumber, 31.62, "standard deviation of x values is not correct")
        pressButton(title: "x≷y")
        XCTAssertEqual(cvc.displayStringNumber, 1.24, "standard deviation of y values is not correct")
        
        // verify linear regression (line fit)
        // f L.R.
        pressButton(title: "f")
        pressButton(title: "Σ+")
        // verify 4.86 x≷y 0.04 (X and Y registers)
        XCTAssertEqual(cvc.displayStringNumber, 4.86, "y-intercept of line is not correct")
        pressButton(title: "x≷y")
        XCTAssertEqual(cvc.displayStringNumber, 0.04, "correlation coefficient of line is not correct")
        
        // verify linear estimation
        // 70 f yhat,r
        pressButton(title: "7")
        pressButton(title: "0")
        pressButton(title: "f")
        pressButton(title: "·")
        // verify 7.56 x≷y 0.99 (X and Y registers)
        XCTAssertEqual(cvc.displayStringNumber, 7.56, "y-value corresponding to input x-value is not correct")
        pressButton(title: "x≷y")
        XCTAssertEqual(cvc.displayStringNumber, 0.99, "correlation coefficient of the line fit is not correct")
    }
    
    // test error cases
    // - verify mean with no point gives Error 2
    // - verify standard deviation with 0 or 1 point gives Error 2
    // - verify trying to add a matrix to the points gives Error 1
    func test02StatisticsErrors() {
        // f CLEAR Σ
        pressButton(title: "f")
        pressButton(title: "GSB")
        // g xbar (mean)
        pressButton(title: "g")
        pressButton(title: "0")
        XCTAssertEqual(cvc.displayString, "  Error  2", "Taking mean with no points should show Error 2")
        // clear error
        pressButton(title: "ENTER")  // any button clears an error
        
        // g s (standard deviation)
        pressButton(title: "g")
        pressButton(title: "·")
        XCTAssertEqual(cvc.displayString, "  Error  2", "Taking deviation with no points should show Error 2")
        // 1 ENTER 2 Σ+ (add one point)
        pressButton(title: "1")
        pressButton(title: "ENTER")
        pressButton(title: "2")
        pressButton(title: "Σ+")
        // g s (standard deviation)
        pressButton(title: "g")
        pressButton(title: "·")
        XCTAssertEqual(cvc.displayString, "  Error  2", "Taking deviation with 1 point should show Error 2")
        // 3 ENTER 4 Σ+ (add second point)
        pressButton(title: "3")
        pressButton(title: "ENTER")
        pressButton(title: "4")
        pressButton(title: "Σ+")
        // g s (standard deviation) - no error for 2 points
        pressButton(title: "g")
        pressButton(title: "·")
        XCTAssertEqual(cvc.displayStringNumber, 1.41, "standard deviation of x values is not correct")
        
        // RCL MATRIX A Σ+
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        pressButton(title: "Σ+")
        XCTAssertEqual(cvc.displayString, "  Error  1", "trying to add a matrix point for statistics should show Error 1")
    }

    // MARK: - Utilities

    // from Owner's Handbook p.51 (with corrected point from p.52)
    // https://www.hp.com/ctg/Manual/c03030589.pdf
    //
    // data points
    //   X:    0,   20,   40,   60,   80
    //   Y: 4.63, 5.78, 6.61, 7.21, 7.78
    //
    //   f CLEAR Σ       clear statistics storage registers (registers 2 - 9)
    //   y ENTER x Σ+    add data point (display number of points entered)
    //   ...
    func create5DataPoints() {
        // f CLEAR Σ
        pressButton(title: "f")
        pressButton(title: "GSB")
        // 4.63 ENTER 0 Σ+
        pressButton(title: "4")
        pressButton(title: "·")
        pressButton(title: "6")
        pressButton(title: "3")
        pressButton(title: "ENTER")
        pressButton(title: "0")
        pressButton(title: "Σ+")
        // 5.78 ENTER 20 Σ+
        pressButton(title: "5")
        pressButton(title: "·")
        pressButton(title: "7")
        pressButton(title: "8")
        pressButton(title: "ENTER")
        pressButton(title: "2")
        pressButton(title: "0")
        pressButton(title: "Σ+")
        // 6.61 ENTER 40 Σ+
        pressButton(title: "6")
        pressButton(title: "·")
        pressButton(title: "6")
        pressButton(title: "1")
        pressButton(title: "ENTER")
        pressButton(title: "4")
        pressButton(title: "0")
        pressButton(title: "Σ+")
        // 7.21 ENTER 60 Σ+
        pressButton(title: "7")
        pressButton(title: "·")
        pressButton(title: "2")
        pressButton(title: "1")
        pressButton(title: "ENTER")
        pressButton(title: "6")
        pressButton(title: "0")
        pressButton(title: "Σ+")
        // 7.78 ENTER 80 Σ+
        pressButton(title: "7")
        pressButton(title: "·")
        pressButton(title: "7")
        pressButton(title: "8")
        pressButton(title: "ENTER")
        pressButton(title: "8")
        pressButton(title: "0")
        pressButton(title: "Σ+")
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
