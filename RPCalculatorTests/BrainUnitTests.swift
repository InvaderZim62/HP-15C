//
//  BrainUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 7/25/24.
//

import XCTest
@testable import RPCalculator

final class BrainUnitTests: XCTestCase {
    
    let brain = CalculatorBrain()
    var difference = 0.0

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try? super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }

    // test trig functions in degrees and radians
    // verify (radians):
    //   sin(π/2) =  1.0000
    //   cos(π)   = -1.0000
    //   tan(π/4) =  1.0000
    // verify (degrees):
    //   sin(30)  =  0.5000
    //   cos(30)  =  0.8660
    //   tan(45)  =  1.0000
    // note: argument for brain.performOperation is "pKEY"  // first letter is prefix (n: no prefix)
    func test01Trig() {
        brain.isComplexMode = false
        brain.trigUnits = TrigUnits.RAD

        // sin(π/2) = 1.0000
        brain.xRegister = .pi / 2
        brain.performOperation("nSIN")
        difference = brain.xRegister! - 1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Sine of number in radians is not correct")
        // cos(π) = -1.0000
        brain.xRegister = .pi
        brain.performOperation("nCOS")
        difference = brain.xRegister! - -1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Cosine of number in radians is not correct")
        // tan(π/4) = 1.0000
        brain.xRegister = .pi / 4
        brain.performOperation("nTAN")
        difference = brain.xRegister! - 1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Tangent of number in radians is not correct")
        
        brain.trigUnits = TrigUnits.DEG

        // sin(30) = 0.5000
        brain.xRegister = 30
        brain.performOperation("nSIN")
        difference = brain.xRegister! - 0.5000
        XCTAssertLessThan(abs(difference), Test.threshold, "Sine of number in degrees is not correct")
        // cos(30) = 0.8660
        brain.xRegister = 30
        brain.performOperation("nCOS")
        difference = brain.xRegister! - 0.8660
        XCTAssertLessThan(abs(difference), Test.threshold, "Cosine of number in degrees is not correct")
        // tan(45) = 1.0000
        brain.xRegister = 45
        brain.performOperation("nTAN")
        difference = brain.xRegister! - 1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Tangent of number in degrees is not correct")
    }
}
