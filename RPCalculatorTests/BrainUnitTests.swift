//
//  BrainUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 7/25/24.
//
//  Test cases:
//  - test01Trig
//  - test02HyperbolicTrig
//

import XCTest
@testable import RPCalculator

final class BrainUnitTests: XCTestCase {
    
    let brain = Brain()
    var difference = 0.0
    var xRegister: Double {
        get {
            return brain.xRegister as! Double
        }
        set {
            brain.xRegister = Complex(real: newValue, imag: 0)
        }
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try? super.setUpWithError()
        continueAfterFailure = false  // stop existing test case from continuing after failure
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }
    
    // MARK: - Tests

    // test trig functions in radians and degrees
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
        xRegister = .pi / 2
        brain.performOperation("nSIN")
        difference = xRegister - 1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Sine of number in radians is not correct")
        // cos(π) = -1.0000
        xRegister = .pi
        brain.performOperation("nCOS")
        difference = xRegister - -1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Cosine of number in radians is not correct")
        // tan(π/4) = 1.0000
        xRegister = .pi / 4
        brain.performOperation("nTAN")
        difference = xRegister - 1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Tangent of number in radians is not correct")
        
        brain.trigUnits = TrigUnits.DEG

        // sin(30) = 0.5000
        xRegister = 30
        brain.performOperation("nSIN")
        difference = xRegister - 0.5000
        XCTAssertLessThan(abs(difference), Test.threshold, "Sine of number in degrees is not correct")
        // cos(30) = 0.8660
        xRegister = 30
        brain.performOperation("nCOS")
        difference = xRegister - 0.8660
        XCTAssertLessThan(abs(difference), Test.threshold, "Cosine of number in degrees is not correct")
        // tan(45) = 1.0000
        xRegister = 45
        brain.performOperation("nTAN")
        difference = xRegister - 1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Tangent of number in degrees is not correct")
    }
    
    // test hyperbolic and inverse hyperbolic trig functions in radians and degrees
    // verify (radians):
    //   sinh(1) = 1.1752 and sinh-1() = 1.0
    //   cosh(1) = 1.5431 and cosh-1() = 1.0
    //   tanh(1) = 0.7616 and tanh-1() = 1.0
    // verify (degrees):
    //   (same)
    // note: Owner's Handbook p.26 says "The trigonometric functions operate in the trigonometric mode you select",
    //       but this does not appear to be true for the hyperbolic trig functions.  They all operate in radians
    //       for real and complex numbers.
    // note: argument for brain.performOperation is "pKEY"  // first letter is prefix (H: HYP, h: HYP-1)
    func test02HyperbolicTrig() {
        brain.isComplexMode = false
        brain.trigUnits = TrigUnits.RAD
        
        // sinh(1) = 1.1752
        xRegister = 1
        brain.performOperation("HSIN")
        difference = xRegister - 1.1752
        XCTAssertLessThan(abs(difference), Test.threshold, "Hyperbolic sine of number in radians is not correct")
        // sinh-1() = 1.0
        brain.performOperation("hSIN")
        difference = xRegister - 1.000
        XCTAssertLessThan(abs(difference), Test.threshold, "Inverse hyperbolic sine of number in radians is not correct")
        // cosh(1) = 1.5431
        xRegister = 1
        brain.performOperation("HCOS")
        difference = xRegister - 1.5431
        XCTAssertLessThan(abs(difference), Test.threshold, "Hyperbolic cosine of number in radians is not correct")
        // cosh-1() = 1.0
        brain.performOperation("hCOS")
        difference = xRegister - 1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Inverse hyperbolic cosine of number in radians is not correct")
        // tanh(1) = 0.7616
        xRegister = 1
        brain.performOperation("HTAN")
        difference = xRegister - 0.7616
        XCTAssertLessThan(abs(difference), Test.threshold, "Hyperbolic tangent of number in radians is not correct")
        // tanh-1() = 1.0
        brain.performOperation("hTAN")
        difference = xRegister - 1.0000
        XCTAssertLessThan(abs(difference), Test.threshold, "Inverse hyperbolic tangent of number in radians is not correct")

        brain.trigUnits = TrigUnits.DEG
        
        // sinh(1) = 1.1752
        xRegister = 1
        brain.performOperation("HSIN")
        difference = xRegister - 1.1752
        XCTAssertLessThan(abs(difference), Test.threshold, "Hyperbolic sine of number in degrees is not correct")
        // cosh(1) = 1.5431
        xRegister = 1
        brain.performOperation("HCOS")
        difference = xRegister - 1.5431
        XCTAssertLessThan(abs(difference), Test.threshold, "Hyperbolic cosine of number in degrees is not correct")
        // tanh(1) = 0.7616
        xRegister = 1
        brain.performOperation("HTAN")
        difference = xRegister - 0.7616
        XCTAssertLessThan(abs(difference), Test.threshold, "Hyperbolic tangent of number in degrees is not correct")
    }
}
