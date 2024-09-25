//
//  MatrixUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 9/5/24.
//
//  Note: Extension at bottom of CalculatorViewController file allows access to private
//        func privateStoreMatrixButtonReleased and privateRecallMatrixButtonReleased,
//        using a trick from: https://stackoverflow.com/a/50136916/2526464
//
//  Test cases:
//  - test01MatrixEntryAndRecall
//  - test02CopyThenClearMatrices
//  - test03MatrixInversion
//  - test04MatrixMultiplication
//  - test05MatrixTimesScalar
//

import XCTest
@testable import RPCalculator

class MatrixUnitTests: XCTestCase {

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

        // use this to set display format to 4 digit fixed width before each test
        pressButton(title: "f")
        pressButton(title: "7")  // f-7 = FIX
        pressButton(title: "4")

        cvc.isUserMode = true  // turn on auto-incrementing of matrix indices
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try? super.tearDownWithError()
    }
    
    // MARK: - Tests
    
    // test matrix entry and recall
    // create 2 x 3 matrix
    //   | 1 2 3 |
    //   | 4 5 6 |
    // enter:
    //   2 STO 0 STO 1        set to known values before changing with next sequence
    //   f MATRIX 1           set matrix indices to 1, 1 (row, col) in storage registers 1 and 0
    //   create2x3MatrixA
    //   RCL MATRIX A         verify display shows " A     2  3"
    //   RCL A                verify display shows " A  1,1", followed by 1
    //   RCL A                verify display shows " A  1,2", followed by 2
    //   RCL A                verify display shows " A  1,3", followed by 3
    //   RCL A                verify display shows " A  2,1", followed by 4
    //   RCL A                verify display shows " A  2,2", followed by 5
    //   RCL A                verify display shows " A  2,3", followed by 6
    func test01MatrixEntryAndRecall() {
        // 2 STO 0 STO 1
        pressButton(title: "2")
        pressButton(title: "STO")
        pressButton(title: "0")
        pressButton(title: "STO")
        pressButton(title: "1")
        // f MATRIX 1
        pressButton(title: "f")
        pressButton(title: "CHS")
        pressButton(title: "1")
        XCTAssertEqual(cvc.brain.valueFromStorageRegister("0") as! Double, 1, "Storage register 0 is not correct")
        XCTAssertEqual(cvc.brain.valueFromStorageRegister("1") as! Double, 1, "Storage register 1 is not correct")
        // create matrix A
        create2x3MatrixA()
        // RCL MATRIX A
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        // verify: " A     2  3"
        verifyDisplayView(" A     2  3")
        
        // RCL A
        pressButton(title: "RCL")
        pressButton(title: "√x")
        // verify: " A  1,1"
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "A", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: "1", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 5, digit: "1", trailingDecimal: false, trailingComma: false)
        releaseCurrentButton()
        // verify 1
        XCTAssertEqual(cvc.displayStringNumber, 1, "matrix A(1,1) is not correct")
        
        // RCL A
        pressButton(title: "RCL")
        pressButton(title: "√x")
        // verify: " A  1,2"
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "A", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: "1", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 5, digit: "2", trailingDecimal: false, trailingComma: false)
        releaseCurrentButton()
        // verify 2
        XCTAssertEqual(cvc.displayStringNumber, 2, "matrix A(1,2) is not correct")
        
        // RCL A
        pressButton(title: "RCL")
        pressButton(title: "√x")
        // verify: " A  1,3"
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "A", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: "1", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 5, digit: "3", trailingDecimal: false, trailingComma: false)
        releaseCurrentButton()
        // verify 3
        XCTAssertEqual(cvc.displayStringNumber, 3, "matrix A(1,3) is not correct")
        
        // RCL A
        pressButton(title: "RCL")
        pressButton(title: "√x")
        // verify: " A  2,1"
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "A", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: "2", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 5, digit: "1", trailingDecimal: false, trailingComma: false)
        releaseCurrentButton()
        // verify 4
        XCTAssertEqual(cvc.displayStringNumber, 4, "matrix A(2,1) is not correct")
        
        // RCL A
        pressButton(title: "RCL")
        pressButton(title: "√x")
        // verify: " A  2,2"
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "A", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: "2", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 5, digit: "2", trailingDecimal: false, trailingComma: false)
        releaseCurrentButton()
        // verify 5
        XCTAssertEqual(cvc.displayStringNumber, 5, "matrix A(2,2) is not correct")
        
        // RCL A
        pressButton(title: "RCL")
        pressButton(title: "√x")
        // verify: " A  2,3"
        verifyDigitView(index: 0, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 1, digit: "A", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 2, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 3, digit: " ", trailingDecimal: false, trailingComma: false)
        verifyDigitView(index: 4, digit: "2", trailingDecimal: false, trailingComma: true)
        verifyDigitView(index: 5, digit: "3", trailingDecimal: false, trailingComma: false)
        releaseCurrentButton()
        // verify 6
        XCTAssertEqual(cvc.displayStringNumber, 6, "matrix A(2,3) is not correct")
    }
    
    // test copying a matrix, then clearing all matrices using f MATRIX 0
    // enter:
    //   create matrix A
    //   RCL MATRIX A         put matrix A in display
    //   STO MATRIX D         copy matrix A to matrix D
    //   f MATRIX 0           clear all matrices
    func test02CopyThenClearMatrices() {
        create2x3MatrixA()
        // RCL MATRIX A
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        // STO MATRIX D
        pressButton(title: "STO")
        pressButton(title: "CHS")
        pressButton(title: "yx")
        // RCL MATRIX D
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "yx")
        // verify dimensions
        verifyDisplayView(" D     2  3")
        // verify elements
        // f MATRIX 1
        pressButton(title: "f")
        pressButton(title: "CHS")
        pressButton(title: "1")
        // RCL D
        pressButton(title: "RCL")
        pressButton(title: "yx")
        releaseCurrentButton()  // needed, since RCL <label> uses .touchUpInside to do the recalling
        XCTAssertEqual(cvc.displayStringNumber, 1, "matrix D(1,1) is not correct")
        // RCL D
        pressButton(title: "RCL")
        pressButton(title: "yx")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 2, "matrix D(1,2) is not correct")
        // RCL D
        pressButton(title: "RCL")
        pressButton(title: "yx")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 3, "matrix D(1,3) is not correct")
        // RCL D
        pressButton(title: "RCL")
        pressButton(title: "yx")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 4, "matrix D(2,1) is not correct")
        // RCL D
        pressButton(title: "RCL")
        pressButton(title: "yx")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 5, "matrix D(2,2) is not correct")
        // RCL D
        pressButton(title: "RCL")
        pressButton(title: "yx")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 6, "matrix D(2,3) is not correct")
        // f MATRIX 0
        pressButton(title: "f")
        pressButton(title: "CHS")
        pressButton(title: "0")
        // RCL MATRIX A
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        // verify dimensions
        verifyDisplayView(" A     0  0")
        // RCL MATRIX D
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "yx")
        // verify dimensions
        verifyDisplayView(" D     0  0")
    }
    
    // test matrix inversion with results going to matrix B
    //     matrix        inverse
    //  |  3  0  1 |  |  1  1  0 |
    //  | -2  0 -1 |  | -1  0  1 |
    //  |  3  1  1 |  | -2 -3  0 |
    func test03MatrixInversion() {
        create3x3MatrixA()
        // f RESULT B
        pressButton(title: "f")
        pressButton(title: "EEX")
        pressButton(title: "ex")
        // RCL MATRIX A
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        // verify: " A     3  3"
        verifyDisplayView(" A     3  3")
        // inverse
        pressButton(title: "f")  // need "f", since isUserMode = true
        pressButton(title: "1/x")
        // verify matrix B
        // f MATRIX 1
        pressButton(title: "f")
        pressButton(title: "CHS")
        pressButton(title: "1")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()  // needed, since RCL <label> uses .touchUpInside to do the recalling
        XCTAssertEqual(cvc.displayStringNumber, 1, "matrix B(1,1) is not correct")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 1, "matrix B(1,2) is not correct")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix B(1,3) is not correct")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, -1, "matrix B(2,1) is not correct")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix B(2,2) is not correct")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 1, "matrix B(2,3) is not correct")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, -2, "matrix B(3,1) is not correct")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, -3, "matrix B(3,2) is not correct")
        // RCL B
        pressButton(title: "RCL")
        pressButton(title: "ex")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix B(3,3) is not correct")
    }
    
    // verify A × inv(A) = identity
    //  |  3  0  1 |   |  1  1  0 |   | 1  0  0 |
    //  | -2  0 -1 | x | -1  0  1 | = | 0  1  0 |
    //  |  3  1  1 |   | -2 -3  0 |   | 0  0  1 |
    func test04MatrixMultiplication() {
        create3x3MatrixA()
        // f RESULT C
        pressButton(title: "f")
        pressButton(title: "EEX")
        pressButton(title: "10x")
        // RCL MATRIX A
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        // inverse
        pressButton(title: "f")  // need "f", since isUserMode = true
        pressButton(title: "1/x")
        // RCL MATRIX A
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        // RCL MATRIX C ×
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "10x")
        pressButton(title: "×")
        // verify matrix C is identity
        // f MATRIX 1
        pressButton(title: "f")
        pressButton(title: "CHS")
        pressButton(title: "1")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()  // needed, since RCL <label> uses .touchUpInside to do the recalling
        XCTAssertEqual(cvc.displayStringNumber, 1, "matrix C(1,1) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix C(1,2) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix C(1,3) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix C(2,1) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 1, "matrix C(2,2) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix C(2,3) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix C(3,1) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 0, "matrix C(3,2) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 1, "matrix C(3,3) is not correct")
    }
    
    // verify matrix x scalar
    //  |  1  2  3 |       | 2  4  6 |
    //  |  4  5  6 | x 2 = | 8 10 12 |
    func test05MatrixTimesScalar() {
        // f RESULT C
        pressButton(title: "f")
        pressButton(title: "EEX")
        pressButton(title: "10x")
        // create matrix A
        create2x3MatrixA()
        // RCL MATRIX A
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        // 2 ×
        pressButton(title: "2")
        pressButton(title: "×")
        // verify matrix C
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()  // needed, since RCL <label> uses .touchUpInside to do the recalling
        XCTAssertEqual(cvc.displayStringNumber, 2, "matrix C(1,1) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 4, "matrix C(1,2) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 6, "matrix C(1,3) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 8, "matrix C(2,1) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 10, "matrix C(2,2) is not correct")
        // RCL C
        pressButton(title: "RCL")
        pressButton(title: "10x")
        releaseCurrentButton()
        XCTAssertEqual(cvc.displayStringNumber, 12, "matrix C(2,3) is not correct")
    }
    
    // test error cases
    // verify
    //   storing a matrix as an element of a matrix causes Error 1
    //   indexing a matrix with a matrix causes Error 1
    //   trying to access beyond matrix dimensions causes Error 3
    func test06MatrixErrors() {
        // setup
        // create matrix A
        create2x3MatrixA()
        // RCL MATRIX A
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "√x")
        // STO MATRIX B
        pressButton(title: "STO")
        pressButton(title: "CHS")
        pressButton(title: "ex")
        
        // save matrix as an element of a matrix
        // RCL MATRIX B
        pressButton(title: "RCL")
        pressButton(title: "CHS")
        pressButton(title: "ey")
        // STO A
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()  // needed, since STO <label> uses .touchUpInside to do the storing
        XCTAssertEqual(cvc.displayString, "  Error  1", "Storing a matrix in a matrix should show Error 1")
        // clear error
        pressButton(title: "ENTER")  // any button clears an error
        
        // index a matrix with a matrix
        // STO 0 (storage register 0 is the row index of a matrix)
        pressButton(title: "STO")
        pressButton(title: "0")
        // RCL A
        pressButton(title: "RCL")
        pressButton(title: "√x")  // no need to "release button", since error is immediate (doesn't show matrix indices)
        XCTAssertEqual(cvc.displayString, "  Error  1", "Indexing a matrix with a matrix should show Error 1")
        // clear error
        pressButton(title: "ENTER")

        // access beyond matrix dimensions
        // 3 STO 0 (row index, one more than dimension 2)
        pressButton(title: "3")
        pressButton(title: "STO")
        pressButton(title: "0")
        // RCL A
        pressButton(title: "RCL")
        pressButton(title: "√x")  // no need to "release button", since error is immediate (doesn't show matrix indices)
        XCTAssertEqual(cvc.displayString, "  Error  3", "Indexing a matrix outside its dimensions should show Error 3")
        // clear error
        pressButton(title: "ENTER")
    }

    // MARK: - Utilities
    
    //      matrix A
    //    |  1  2  3 |
    //    |  4  5  6 |
    //
    //   f MATRIX 1           set matrix indices to 1, 1 (row, col) in storage registers 1 and 0
    //   2 ENTER 3 f DIM A    set matrix A dimensions to 2 rows by 3 columns
    //   1 STO A              set row 1, col 1 of MATRIX A to 1, and register 0 to 2
    //   2 STO A              set row 1, col 2 of MATRIX A to 2, and register 0 to 3
    //   3 STO A              set row 1, col 3 of MATRIX A to 3, and register 0 to 1, and register 1 to 2
    //   4 STO A              set row 2, col 1 of MATRIX A to 4, and register 0 to 2
    //   5 STO A              set row 2, col 2 of MATRIX A to 5, and register 0 to 3
    //   6 STO A              set row 2, col 3 of MATRIX A to 6, and register 0 to 1, and register 1 to 1 (back to start)
    func create2x3MatrixA() {
        // f MATRIX 1
        pressButton(title: "f")
        pressButton(title: "CHS")
        pressButton(title: "1")
        // 2 ENTER 3 f DIM A
        pressButton(title: "2")
        pressButton(title: "ENTER")
        pressButton(title: "3")
        pressButton(title: "f")
        pressButton(title: "SIN")
        pressButton(title: "√x")
        // 1 STO A
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()  // needed, since STO <label> uses .touchUpInside to do the storing
        // 2 STO A
        pressButton(title: "2")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 3 STO A
        pressButton(title: "3")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 4 STO A
        pressButton(title: "4")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 5 STO A
        pressButton(title: "5")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 6 STO A
        pressButton(title: "6")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
    }
    
    //      matrix A
    //    |  3  0  1 |
    //    | -2  0 -1 |
    //    |  3  1  1 |
    func create3x3MatrixA() {
        // f MATRIX 1
        pressButton(title: "f")
        pressButton(title: "CHS")
        pressButton(title: "1")
        // 3 ENTER 3 f DIM A
        pressButton(title: "3")
        pressButton(title: "ENTER")
        pressButton(title: "3")
        pressButton(title: "f")
        pressButton(title: "SIN")
        pressButton(title: "√x")
        // 3 STO A
        pressButton(title: "3")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()  // needed, since STO <label> uses .touchUpInside to do the storing
        // 0 STO A
        pressButton(title: "0")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 1 STO A
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // -2 STO A
        pressButton(title: "2")
        pressButton(title: "CHS")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 0 STO A
        pressButton(title: "0")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // -1 STO A
        pressButton(title: "1")
        pressButton(title: "CHS")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 3 STO A
        pressButton(title: "3")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 1 STO A
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
        // 1 STO A
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "√x")
        releaseCurrentButton()
    }

    func verifyDisplayView(_ display: String) {
        for (index, digit) in display.enumerated() {
            verifyDigitView(index: index, digit: digit, trailingDecimal: false, trailingComma: false)
        }
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

    // create button with input title, and invoke the button action;
    // save prefix, in case it's needed later, since each of these clears prefix
    func pressButton(title: String) {
        savePrefix = cvc.prefix
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
    
    // use this for button actions that have a separate action for .touchUpInside to
    // perform the actual action - ie. STO A-E, RCL A-E, SST, g-SST (BST), f-COS (i);
    // must be called after pressButton, to store the prefix and button title
    func releaseCurrentButton() {
        switch button.currentTitle {
        case "√x", "ex", "10x", "yx", "1/x":  // note: if cvc.isUserMode = true, these will be the non-f prefix versions
            // in run mode, the appropriate _MatrixButtonReleased is called automatically;
            // in test mode, _MatrixButtonReleased must be called manually;
            // since aToEButtonPressed() clears the prefix, use a saved version to determine which to call
            if savePrefix == .STO {
                cvc.privateStoreMatrixButtonReleased(button)
            } else if savePrefix == .RCL {
                cvc.privateRecallMatrixButtonReleased(button)
            }
            let exp = expectation(description: "Wait for matrix dimensions to clear and matrix element to be stored or recalled")
            _ = XCTWaiter.wait(for: [exp], timeout: 1.1 * Pause.matrix)
        case "SST":
            if savePrefix == .none {
                cvc.privateSstButtonReleased(button)
            } else if savePrefix == .g {
                cvc.privateBstButtonReleased(button)
            }
        case "COS":
            if savePrefix == .f {
                cvc.privateIButtonReleased(button)
                let exp = expectation(description: "Wait for imaginary part of complex number to be replaced by real part")
                _ = XCTWaiter.wait(for: [exp], timeout: 1.1 * Pause.running)
            }
        default:
            break
        }
    }
}
