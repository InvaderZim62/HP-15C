//
//  ComplexUnitTests.swift
//  ComplexUnitTests
//
//  Created by Phil Stern on 7/24/24.
//
//  To add unit test capability:
//  - select: File | New | Target... | Test | Unit Testing Bundle
//  - other test files can be added to the unit test project, if they import XCTest
//    and subclass XCTestCase
//
//  Notes:
//  - to prevent unit test from hanging in the simulator (stuck on showing "testing..."):
//    select: Test navigator (command 6) | PRCalculator (Autocreated) | Tests | PRCalculatorTests | Options...
//    uncheck: Execute in parallel (if possible) | Save
//  - test cases are run in alphabetic order
//

import XCTest
@testable import RPCalculator

struct Test {
    static let threshold = 0.0001
}

final class ComplexUnitTests: XCTestCase {

    let complexA = Complex(real: 1, imag: 2)  // 1 + 2i
    let complexB = Complex(real: 3, imag: 4)  // 3 + 4i
    var difference: Complex!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try? super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }
        
    // test complex number arithmetic
    // verify:
    //   (1 + 2i) + (3 + 4i) =  4 + 6i
    //   (1 + 2i) - (3 + 4i) = -2 - 2i
    //   (1 + 2i) x (4 + 4i) = -5 + 10i
    //   (1 + 2i) / (3 + 4i) =  0.44 + 0.08i
    func test01ComplexArithmetic() {
        XCTAssertEqual(complexA + complexB, Complex(real: 4, imag: 6), "Addition of complex numbers is not correct")
        XCTAssertEqual(complexA - complexB, Complex(real: -2, imag: -2), "Subtraction of complex numbers is not correct")
        XCTAssertEqual(complexA * complexB, Complex(real: -5, imag: 10), "Multiplication of complex numbers is not correct")
        XCTAssertEqual(complexA / complexB, Complex(real: 0.44, imag: 0.08), "Division of complex numbers is not correct")
    }
    
    // test trig operations on complex numbers
    // verify:
    //   sin(1 + 2i) = 3.1658 + 1.9596i and asin() = 1 + 2i
    //   cos(1 + 2i) = 2.0327 - 3.0519i and acos() = 1 + 2i (or -1 - 2i)
    //   tan(1 + 2i) = 0.0338 + 1.0148i and atan() = 1 + 2i
    func test02ComplexTrig() {
        // verify: f(A) - expected result < test threshold
        // sin
        difference = complexA.sine - Complex(real: 3.1658, imag: 1.9596)
        XCTAssertLessThan(difference.mag, Test.threshold, "Sine of complex numbers is not correct")
        // asin
        difference = complexA.sine.arcsin - Complex(real: 1.0000, imag: 2.0000)
        XCTAssertLessThan(difference.mag, Test.threshold, "Arcsine of complex numbers is not correct")
        // cos
        difference = complexA.cosine - Complex(real: 2.0327, imag: -3.0519)
        XCTAssertLessThan(difference.mag, Test.threshold, "Cosine of complex numbers is not correct")
        // acos
        let difference1 = complexA.cosine.arccos - Complex(real: 1.0000, imag: 2.0000)
        let difference2 = complexA.cosine.arccos - Complex(real: -1.0000, imag: -2.0000)
        XCTAssert(difference1.mag < Test.threshold || difference2.mag < Test.threshold, "Arccosine of complex numbers is not correct")
        // tan
        difference = complexA.tangent - Complex(real: 0.0338, imag: 1.0148)
        XCTAssertLessThan(difference.mag, Test.threshold, "Tangent of complex numbers is not correct")
        // atan
        difference = complexA.tangent.arctan - Complex(real: 1.0000, imag: 2.0000)
        XCTAssertLessThan(difference.mag, Test.threshold, "Arctangent of complex numbers is not correct")
    }
    
    // test hyperbolic trig operations on complex numbers
    // verify:
    //   sinh(1 + 2i) = -0.4891 + 1.4031i and asin() = -1 + 1.1416i <- not sure why HP-15C returns this, rather then 1 + 2i
    //   cosh(1 + 2i) = -0.6421 + 1.0686i and acos() =  1 + 2i      (or -1 - 2i)
    //   tanh(1 + 2i) =  1.1667 - 0.2435i and atan() =  1 - 1.1416i
    func test03ComplexHyperbolicTrig() {
        // verify: f(A) - expected result < test threshold
        // sinh
        difference = complexA.sinhyp - Complex(real: -0.4891, imag: 1.4031)
        XCTAssertLessThan(difference.mag, Test.threshold, "Hyperbolic sine of complex numbers is not correct")
        // asinh
        difference = complexA.sinhyp.arcsinh - Complex(real: -1.0000, imag: 1.1416)
        XCTAssertLessThan(difference.mag, Test.threshold, "Arc-hyperbolic sine of complex numbers is not correct")
        // cosh
        difference = complexA.coshyp - Complex(real: -0.6421, imag: 1.0686)
        XCTAssertLessThan(difference.mag, Test.threshold, "Hyperbolic cosine of complex numbers is not correct")
        // acosh
        let difference1 = complexA.coshyp.arccosh - Complex(real: 1.0000, imag: 2.0000)
        let difference2 = complexA.coshyp.arccosh - Complex(real: -1.0000, imag: -2.0000)
        XCTAssert(difference1.mag < Test.threshold || difference2.mag < Test.threshold, "Arc-hyperbolic cosine of complex numbers is not correct")
        // tanh
        difference = complexA.tanhyp - Complex(real: 1.1667, imag: -0.2435)
        XCTAssertLessThan(difference.mag, Test.threshold, "Hyperbolic tangent of complex numbers is not correct")
        // atanh
        difference = complexA.tanhyp.arctanh - Complex(real: 1.0000, imag: -1.1416)
        XCTAssertLessThan(difference.mag, Test.threshold, "Arc-hyperbolic tangent of complex numbers is not correct")
    }

    // test other operations on complex numbers
    // verify:
    //      sqrt(1 + 2i) =  1.2720 + 0.7862i
    //        (1 + 2i)^2 = -3.0000 + 4.0000i
    //        e^(1 + 2i) = -1.1312 + 2.4717i
    //        ln(1 + 2i) =  0.8047 + 1.1071i
    //       10^(1 + 2i) = -1.0701 - 9.9426i
    //       log(1 + 2i) =  0.3495 + 0.4808i
    // (1 + 2i)^(3 + 4i) =  0.1290 + 0.0339i
    //      1 / (1 + 2i) =  0.2000 - 0.4000i
    func test04OtherComplexOperations() {
        // verify: f(A) - expected result < test threshold
        // square root
        difference = complexA.squareRoot - Complex(real: 1.2720, imag: 0.7862)
        XCTAssertLessThan(difference.mag, Test.threshold, "Square root of complex numbers is not correct")
        // squared
        difference = complexA.squared - Complex(real: -3.0000, imag: 4.0000)
        XCTAssertLessThan(difference.mag, Test.threshold, "Complex number squared is not correct")
        // exponential
        difference = complexA.exponential - Complex(real: -1.1312, imag: 2.4717)
        XCTAssertLessThan(difference.mag, Test.threshold, "Exponential of complex numbers is not correct")
        // natural log
        difference = complexA.naturalLog - Complex(real: 0.8047, imag: 1.1071)
        XCTAssertLessThan(difference.mag, Test.threshold, "Natural log of complex numbers is not correct")
        // 10 to the power of
        difference = complexA.tenToThePowerOf - Complex(real: -1.0701, imag: -9.9426)
        XCTAssertLessThan(difference.mag, Test.threshold, "10 to the power of complex numbers is not correct")
        // log base 10
        difference = complexA.logBase10 - Complex(real: 0.3495, imag: 0.4808)
        XCTAssertLessThan(difference.mag, Test.threshold, "Log base 10 of complex numbers is not correct")
        // complex to the power of complex
        difference = complexA^complexB - Complex(real: 0.1290, imag: 0.0339)
        XCTAssertLessThan(difference.mag, Test.threshold, "Log base 10 of complex numbers is not correct")
        // inverse
        difference = complexA.inverse - Complex(real: 0.2000, imag: -0.4000)
        XCTAssertLessThan(difference.mag, Test.threshold, "Inverse of complex numbers is not correct")
    }
}
