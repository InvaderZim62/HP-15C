//
//  CalculatorUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 7/25/24.
//
//  Method for testing UIViewController obtained from:
//  https://oliverpeate.com/testing-a-uiviewcontroller/
//

import XCTest
@testable import RPCalculator

class CalculatorUnitTests: XCTestCase {

    var cvc = CalculatorViewController()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try? super.setUpWithError()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        cvc = storyboard.instantiateViewController(withIdentifier: "CVC") as! CalculatorViewController  // added identifier in Storyboard
        cvc.beginAppearanceTransition(true, animated: false)  // connect outlets
        cvc.endAppearanceTransition()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }
    
    // test basic arithmetic
    // verify: 5 ENTER 2 x = 10
    func testCVC() {
        let button = UIButton()
        button.setTitle("5", for: .normal)
        cvc.fiveButtonPressed(button)
        button.setTitle("ENTER", for: .normal)  // not used by enterButtonPressed
        cvc.enterButtonPressed(button)
        button.setTitle("2", for: .normal)
        cvc.twoButtonPressed(button)
        button.setTitle("×", for: .normal)
        cvc.multiplyButtonPressed(button)
        XCTAssertEqual(cvc.displayStringNumber, 10)
    }
}
