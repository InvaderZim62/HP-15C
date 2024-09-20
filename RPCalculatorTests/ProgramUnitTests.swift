//
//  ProgramUnitTests.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 8/3/24.
//
//  Test cases:
//  - test01FLabel
//  - test02DropFBeforeLabel
//  - test03FCausesRestart
//  - test04F4Thru9Trig
//  - test05F7Thru9Label
//  - test06F4Thru6LabelTrig
//  - test07ConditionalTest
//  - test08ConditionalTest
//  - test09Flags
//  - test10Flags
//  - test11DSE
//  - test12ISG
//  - test13RootSolving
//

import XCTest
@testable import RPCalculator

class ProgramUnitTests: XCTestCase {
    
    var cvc: CalculatorViewController!
    
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
    
    // test unique way HP-15C converts instruction for f-label
    // verify:
    // - f A => GSB A
    // note: entering a label is intended to start program running from label;
    //       by using GSB label, the HP-15C treats it as a subroutine call
    func test01FLabel() {
        startNewProgram()
        // f A
        pressButton(title: "f")
        pressButton(title: "√x")
        // GSB: 32, A: 11
        XCTAssertEqual(cvc.program.currentInstruction, "001- 32 11", "Instruction is not correct")
    }
    
    // test instructions that drop "f" before a label
    // verify:
    // - GTO A     => GTO A (try first without f)
    // - GTO f A   => GTO A (same answer)
    // - GSB f B   => GSB B
    // - STO f C   => STO C
    // - STO + f C => STO + C
    // - STO - f C => STO - C
    // - RCL × f D => RCL × D
    // - RCL ÷ f D => RCL ÷ D
    // - f 4 f E   => f 4 E
    // - f 4 f E   => f 4 E
    // - f ÷ f E   => f ÷ E
    // - f × f E   => f × E
    // - f SST A   => f SST A (try first without f)
    // - f SST f A => f SST A (same answer)
    func test02DropFBeforeLabel() {
        startNewProgram()
        // GTO A => GTO A
        pressButton(title: "GTO")
        pressButton(title: "√x")
        XCTAssertEqual(cvc.program.currentInstruction, "001- 22 11", "Instruction is not correct")
        
        // GTO f A => GTO A
        pressButton(title: "GTO")
        pressButton(title: "f")
        pressButton(title: "√x")
        // currentInstructionCodeString doesn't include line number, to allow easier cut-and-paste
        XCTAssertEqual(cvc.program.currentInstructionCodeString, " 22 11", "Instruction codes are not correct")
        
        // GSB f B => GSB B
        pressButton(title: "GSB")
        pressButton(title: "f")
        pressButton(title: "ex")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, " 32 12", "Instruction codes are not correct")
        
        // STO f C => STO C
        pressButton(title: "STO")
        pressButton(title: "f")
        pressButton(title: "10x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, " 44 13", "Instruction codes are not correct")
        
        // STO + f C => STO + C
        pressButton(title: "STO")
        pressButton(title: "+")
        pressButton(title: "f")
        pressButton(title: "10x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "44,40,13", "Instruction codes are not correct")
        
        // STO - f C => STO – C
        pressButton(title: "STO")
        pressButton(title: "–")
        pressButton(title: "f")
        pressButton(title: "10x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "44,30,13", "Instruction codes are not correct")

        // RCL × f D => RCL × D
        pressButton(title: "RCL")
        pressButton(title: "×")
        pressButton(title: "f")
        pressButton(title: "yx")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "45,20,14", "Instruction codes are not correct")

        // RCL ÷ f D => RCL ÷ D
        pressButton(title: "RCL")
        pressButton(title: "÷")
        pressButton(title: "f")
        pressButton(title: "yx")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "45,10,14", "Instruction codes are not correct")

        // f 4 f E => f 4 E
        pressButton(title: "f")
        pressButton(title: "4")
        pressButton(title: "f")
        pressButton(title: "1/x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 4,15", "Instruction codes are not correct")

        // f ÷ f E => f ÷ E
        pressButton(title: "f")
        pressButton(title: "÷")
        pressButton(title: "f")
        pressButton(title: "1/x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42,10,15", "Instruction codes are not correct")

        // f × f E => f × E
        pressButton(title: "f")
        pressButton(title: "×")
        pressButton(title: "f")
        pressButton(title: "1/x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42,20,15", "Instruction codes are not correct")

        // f SST f A => f SST A
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "f")
        pressButton(title: "√x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42,21,11", "Instruction codes are not correct")

        // f SST A => f SST A
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "√x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42,21,11", "Instruction codes are not correct")
    }
    
    // test instructions that start over when "f" pressed but not followed by a label
    // verify:
    // - GTO f 1   => f 1
    // - GSB f TAN => f TAN
    func test03FCausesRestart() {
        startNewProgram()
        // GTO f 1 => f 1
        pressButton(title: "GTO")
        pressButton(title: "f")
        pressButton(title: "1")
        XCTAssertEqual(cvc.program.currentInstruction, "001-  42 1", "Instruction is not correct")
        // GSB f TAN => f TAN
        pressButton(title: "GSB")
        pressButton(title: "f")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, " 32 25", "Instruction codes are not correct")
    }
    
    // test f 4 thru 9 followed by SIN, COS, TAN
    // verify:
    // - f 4 SIN => SIN
    // - f 5 SIN => SIN
    // - f 6 SIN => SIN
    // - f 7 SIN => SIN
    // - f 8 SIN => SIN
    // - f 9 SIN => SIN
    //
    // - f 4 COS => f 4 COS
    // - f 5 COS => f 5 COS
    // - f 6 COS => f 6 COS
    // - f 7 COS => COS
    // - f 8 COS => COS
    // - f 9 COS => COS
    //
    // - f 4 TAN => f 4 TAN
    // - f 5 TAN => f 5 TAN
    // - f 6 TAN => f 6 TAN
    // - f 7 TAN => f 7 TAN
    // - f 8 TAN => f 8 TAN
    // - f 9 TAN => f 9 TAN
    func test04F4Thru9Trig() {
        startNewProgram()
        // f 4 SIN => SIN
        pressButton(title: "f")
        pressButton(title: "4")
        pressButton(title: "SIN")
        XCTAssertEqual(cvc.program.currentInstruction, "001-    23", "Instruction is not correct")
        // f 5 SIN => SIN
        pressButton(title: "f")
        pressButton(title: "5")
        pressButton(title: "SIN")
        // currentInstructionCodeString doesn't include line number, to allow easier cut-and-paste
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    23", "Instruction codes are not correct")
        // f 6 SIN => SIN
        pressButton(title: "f")
        pressButton(title: "6")
        pressButton(title: "SIN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    23", "Instruction codes are not correct")
        // f 7 SIN => SIN
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "SIN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    23", "Instruction codes are not correct")
        // f 8 SIN => SIN
        pressButton(title: "f")
        pressButton(title: "8")
        pressButton(title: "SIN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    23", "Instruction codes are not correct")
        // f 9 SIN => SIN
        pressButton(title: "f")
        pressButton(title: "9")
        pressButton(title: "SIN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    23", "Instruction codes are not correct")
        
        // f 4 COS => f 4 COS
        pressButton(title: "f")
        pressButton(title: "4")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 4,24", "Instruction codes are not correct")
        // f 5 COS => f 5 COS
        pressButton(title: "f")
        pressButton(title: "5")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 5,24", "Instruction codes are not correct")
        // f 6 COS => f 6 COS
        pressButton(title: "f")
        pressButton(title: "6")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 6,24", "Instruction codes are not correct")
        // f 7 COS => COS
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    24", "Instruction codes are not correct")
        // f 8 COS => COS
        pressButton(title: "f")
        pressButton(title: "8")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    24", "Instruction codes are not correct")
        // f 9 COS => COS
        pressButton(title: "f")
        pressButton(title: "9")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    24", "Instruction codes are not correct")
        
        // f 4 TAN => f 4 TAN
        pressButton(title: "f")
        pressButton(title: "4")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 4,25", "Instruction codes are not correct")
        // f 5 TAN => f 5 TAN
        pressButton(title: "f")
        pressButton(title: "5")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 5,25", "Instruction codes are not correct")
        // f 6 TAN => f 6 TAN
        pressButton(title: "f")
        pressButton(title: "6")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 6,25", "Instruction codes are not correct")
        // f 7 TAN => f 7 TAN
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 7,25", "Instruction codes are not correct")
        // f 8 TAN => f 8 TAN
        pressButton(title: "f")
        pressButton(title: "8")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 8,25", "Instruction codes are not correct")
        // f 9 TAN => f 9 TAN
        pressButton(title: "f")
        pressButton(title: "9")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "42, 9,25", "Instruction codes are not correct")
    }
    
    // test f 7 thru 9 followed by A - E
    // verify:
    // - f 7 A => A
    // - f 8 B => B
    // - f 9 C => C
    func test05F7Thru9Label() {
        startNewProgram()
        // f 7 A => A
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "√x")
        XCTAssertEqual(cvc.program.currentInstruction, "001-    11", "Instruction is not correct")
        // f 8 B => B
        pressButton(title: "f")
        pressButton(title: "8")
        pressButton(title: "ex")
        // currentInstructionCodeString doesn't include line number, to allow easier cut-and-paste
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    12", "Instruction codes are not correct")
        // f 9 C => C
        pressButton(title: "f")
        pressButton(title: "9")
        pressButton(title: "10x")
        // currentInstructionCodeString doesn't include line number, to allow easier cut-and-paste
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    13", "Instruction codes are not correct")
    }
    
    // test g 4 thru 6 followed by A - E, SIN, COS, TAN
    // verify:
    // - g 4 A   => A (ie. HP-15C ignores the g 4)
    // - g 5 B   => B
    // - g 6 C   => C
    // - g 4 SIN => SIN
    // - g 5 COS => COS
    // - g 5 TAN => g 5 TAN (ie. clear flag number store in register I)
    // - g 6 TAN => g 6 TAN (ie. test if flag number stored in register I is set)
    func test06F4Thru6LabelTrig() {
        startNewProgram()
        // g 4 A => A
        pressButton(title: "g")
        pressButton(title: "4")
        pressButton(title: "√x")
        XCTAssertEqual(cvc.program.currentInstruction, "001-    11", "Instruction is not correct")
        // g 5 B => B
        pressButton(title: "g")
        pressButton(title: "5")
        pressButton(title: "ex")
        // currentInstructionCodeString doesn't include line number, to allow easier cut-and-paste
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    12", "Instruction codes are not correct")
        // g 6 C => C
        pressButton(title: "g")
        pressButton(title: "6")
        pressButton(title: "10x")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    13", "Instruction codes are not correct")
        // g 4 SIN => SIN
        pressButton(title: "g")
        pressButton(title: "4")
        pressButton(title: "SIN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    23", "Instruction codes are not correct")
        // g 5 COS => COS
        pressButton(title: "g")
        pressButton(title: "5")
        pressButton(title: "COS")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "    24", "Instruction codes are not correct")
        // g 5 TAN => g 5 TAN
        pressButton(title: "g")
        pressButton(title: "5")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "43, 5,25", "Instruction codes are not correct")
        // g 6 TAN => g 6 TAN
        pressButton(title: "g")
        pressButton(title: "6")
        pressButton(title: "TAN")
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "43, 6,25", "Instruction codes are not correct")
    }
    
    //  n  test    n  test
    //  -  -----   -  -----
    //  0  x ≠ 0   6  x ≠ y
    //  1  x > 0   7  x > y
    //  2  x < 0   8  x < y
    //  3  x ≥ 0   9  x ≥ y
    //  4  x ≤ 0  10  x ≤ y
    //  5  x = y  11  x = 0

    // test conditional test, where true continues to next line, and false skips a line
    // enter program:
    //   LBL A
    //   1
    //   -
    //   R/S
    //   g TEST 1
    //   GTO A
    //   99 ENTER
    //
    // verify: display counts down from initial value to zero, stopping at each number
    func test07ConditionalTest() {
        // enter program
        startNewProgram()
        // LBL A
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "√x")
        // 1 –
        pressButton(title: "1")
        pressButton(title: "–")
        // R/S
        pressButton(title: "R/S")
        // TEST 1
        pressButton(title: "g")
        pressButton(title: "–")
        pressButton(title: "1")
        // GTO A (if true)
        pressButton(title: "GTO")
        pressButton(title: "√x")
        // 99 ENTER (if false)
        pressButton(title: "9")
        pressButton(title: "9")
        pressButton(title: "ENTER")
        // end program
        pressButton(title: "g")
        pressButton(title: "R/S")
        
        // run program
        // set display to 4 digits fixed
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "4")
        // start with 3 in display
        pressButton(title: "3")
        // run from LBL A
        pressButton(title: "f")
        pressButton(title: "√x")
        // verify display = 2.0000
        let exp1 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp1], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "2.0000", "Display is not correct")
        // continue
        pressButton(title: "R/S")
        // verify display = 1.0000
        let exp2 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp2], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "1.0000", "Display is not correct")
        // continue
        pressButton(title: "R/S")
        // verify display = 0.0000
        let exp3 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp3], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "0.0000", "Display is not correct")
        // continue
        pressButton(title: "R/S")
        // verify display = 99.0000
        let exp4 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp4], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "99.0000", "Display is not correct")
    }

    // conditional test from p.94 of Owner's Handbook
    // enter program:
    //   LBL A
    //   RCL 0
    //   f PSE
    //   8
    //   ÷
    //   CHS
    //   2
    //   x≷y
    //   yx
    //   RCL x 1
    //   f PSE
    //   RCL 2
    //   g TEST 9
    //   g RTN
    //   3
    //   STO + 0
    //   GTO A
    //
    // setup:
    //   2 STO 0
    //   100 STO 1
    //   50 STO 2
    //
    // verify: display shows the following numbers, with a pause between each
    //   2.0000, 84.0896, 5.0000, 64.8420, 8.0000, 50.0000, 50.0000
    func test08ConditionalTest() {
        startNewProgram()
        // LBL A
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "√x")
        // RCL 0
        pressButton(title: "RCL")
        pressButton(title: "0")
        // f PSE
        pressButton(title: "f")
        pressButton(title: "R/S")
        // 8 ÷ CHS
        pressButton(title: "8")
        pressButton(title: "÷")
        pressButton(title: "CHS")
        // 2 x≷y yx
        pressButton(title: "2")
        pressButton(title: "x≷y")
        pressButton(title: "yx")
        // RCL x 1
        pressButton(title: "RCL")
        pressButton(title: "×")
        pressButton(title: "1")
        // f PSE
        pressButton(title: "f")
        pressButton(title: "R/S")
        // RCL 2
        pressButton(title: "RCL")
        pressButton(title: "2")
        // g TEST 9
        pressButton(title: "g")
        pressButton(title: "–")
        pressButton(title: "9")
        // g RTN
        pressButton(title: "g")
        pressButton(title: "GSB")
        // 3
        pressButton(title: "3")
        // STO + 0
        pressButton(title: "STO")
        pressButton(title: "+")
        pressButton(title: "0")
        // GTO A
        pressButton(title: "GTO")
        pressButton(title: "√x")
        // end program
        pressButton(title: "g")
        pressButton(title: "R/S")
        
        // setup
        // set display to 4 digits fixed
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "4")
        // 2 STO 0
        pressButton(title: "2")
        pressButton(title: "STO")
        pressButton(title: "0")
        // 100 STO 1
        pressButton(title: "1")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "STO")
        pressButton(title: "1")
        // 50 STO 2
        pressButton(title: "5")
        pressButton(title: "0")
        pressButton(title: "STO")
        pressButton(title: "2")
        
        // run from LBL A
        pressButton(title: "f")
        pressButton(title: "√x")
        // verify display = 2.0000
        let factor = 2.0  // found by trial and error (1.9 - 2.2 works, independent of device)
        let exp1 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp1], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "2.0000", "Display is not correct")
        // verify display = 84.0896
        let exp2 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp2], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "84.0896", "Display is not correct")
        // verify display = 5.0000
        let exp3 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp3], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "5.0000", "Display is not correct")
        // verify display = 64.8420
        let exp4 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp4], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "64.8420", "Display is not correct")
        // verify display = 8.0000
        let exp5 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp5], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "8.0000", "Display is not correct")
        // verify display = 50.0000
        let exp6 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp6], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "50.0000", "Display is not correct")
        // verify display = 50.0000
        let exp7 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp7], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "50.0000", "Display is not correct")
    }

    // test flags, where true continues to next line, and false skips a line
    // enter program:
    //   LBL A
    //   g F? 1
    //   GTO .2
    //   1 –
    //   g RTN
    //   LBL .2
    //   1 +
    //   g RTN
    //
    // verify: add one to display if flag 1 is set;
    //         subtract 1 from display if flag is cleared
    func test09Flags() {
        startNewProgram()
        // LBL A
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "√x")
        // g F? 1
        pressButton(title: "g")
        pressButton(title: "6")
        pressButton(title: "1")
        // GTO .2
        pressButton(title: "GTO")
        pressButton(title: "·")
        pressButton(title: "2")
        // 1 –
        pressButton(title: "1")
        pressButton(title: "–")
        // g RTN
        pressButton(title: "g")
        pressButton(title: "GSB")
        // LBL .2
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "·")
        pressButton(title: "2")
        // 1 +
        pressButton(title: "1")
        pressButton(title: "+")
        // g RTN
        pressButton(title: "g")
        pressButton(title: "GSB")
        // end program
        pressButton(title: "g")
        pressButton(title: "R/S")
        
        // set display to 4 digits fixed
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "4")
        // set flag 1
        pressButton(title: "g")
        pressButton(title: "4")
        pressButton(title: "1")
        // start with 3 in display
        pressButton(title: "3")
        // run from LBL A
        pressButton(title: "f")
        pressButton(title: "√x")
        // verify display = 4
        let exp1 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp1], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "4.0000", "Display is not correct")
        // clear flag 1
        pressButton(title: "g")
        pressButton(title: "5")
        pressButton(title: "1")
        // run from LBL A
        pressButton(title: "f")
        pressButton(title: "√x")
        // verify display = 3
        let exp2 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp2], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "3.0000", "Display is not correct")
    }
    
    // test flags (from p.96 Owner's Handbook)
    // enter program:
    //   LBL B
    //   g CF 0
    //   GTO 1
    //   f LBL E
    //   g SF 0
    //   f LBL 1
    //   STO 1
    //   1 +
    //   x≷y
    //   CHS
    //   yx
    //   CHS
    //   1 +
    //   RCL ÷ 1
    //   ×
    //   g F? 0
    //   g RTN
    //   RCL 1
    //   1 + x
    //   g RTN
    // setup:
    //   250 ENTER 48 ENTER .005
    // verify: result of running from LBL B is 10698.3049
    //         result of running from LBL E is 10645.0795
    func test10Flags() {
        startNewProgram()
        // LBL B
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "ex")
        // g CF 0
        pressButton(title: "g")
        pressButton(title: "5")
        pressButton(title: "0")
        // GTO 1
        pressButton(title: "GTO")
        pressButton(title: "1")
        // f LBL E
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "1/x")
        // g SF 0
        pressButton(title: "g")
        pressButton(title: "4")
        pressButton(title: "0")
        // f LBL 1
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "1")
        // STO 1
        pressButton(title: "STO")
        pressButton(title: "1")
        // 1 +
        pressButton(title: "1")
        pressButton(title: "+")
        // x≷y
        pressButton(title: "x≷y")
        // CHS
        pressButton(title: "CHS")
        // yx
        pressButton(title: "yx")
        // CHS
        pressButton(title: "CHS")
        // 1 +
        pressButton(title: "1")
        pressButton(title: "+")
        // RCL ÷ 1
        pressButton(title: "RCL")
        pressButton(title: "÷")
        pressButton(title: "1")
        // x
        pressButton(title: "×")
        // g F? 0
        pressButton(title: "g")
        pressButton(title: "6")
        pressButton(title: "0")
        // g RTN
        pressButton(title: "g")
        pressButton(title: "GSB")
        // RCL 1
        pressButton(title: "RCL")
        pressButton(title: "1")
        // 1 + x
        pressButton(title: "1")
        pressButton(title: "+")
        pressButton(title: "×")
        // g RTN
        pressButton(title: "g")
        pressButton(title: "GSB")
        // end program
        pressButton(title: "g")
        pressButton(title: "R/S")
        
        // setup
        setupFlagsTest()
        // run from LBL B
        pressButton(title: "f")
        pressButton(title: "ex")
        // verify display = 10698.3049
        let exp1 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp1], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "10698.3048", "Display is not correct")  // s/b 10698.3049 (close enough)
        
        // setup
        setupFlagsTest()
        // run from LBL E
        pressButton(title: "f")
        pressButton(title: "1/x")
        // verify display = 10645.0795
        let exp2 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp2], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "10645.0794", "Display is not correct")  // s/b 10645.0795 (close enough)
    }
    
    // test DSE (decrement loop control)
    // enter program:
    //   LBL A
    //   f PSE
    //   1 –
    //   f DSE 3  <- use loop counter in storage register 3
    //   GTO A
    //   g RTN
    // setup:
    //   5.00001 STO 3  <- loop counter starts at 5 and counts down by 1, until reaching 0 (ccccc.tttii)
    //   10
    // verify: display counts down from 10 to 5
    func test11DSE() {
        startNewProgram()
        // LBL A
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "√x")
        // f PSE
        pressButton(title: "f")
        pressButton(title: "R/S")
        // 1 –
        pressButton(title: "1")
        pressButton(title: "–")
        // f DSE 3
        pressButton(title: "f")
        pressButton(title: "5")
        pressButton(title: "3")
        // GTO A
        pressButton(title: "GTO")
        pressButton(title: "√x")
        // g RTN
        pressButton(title: "g")
        pressButton(title: "GSB")
        // end program
        pressButton(title: "g")
        pressButton(title: "R/S")

        // setup
        // set display to 4 digits fixed
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "4")
        // 5.00001 STO 3
        pressButton(title: "5")
        pressButton(title: "·")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "3")
        // 10
        pressButton(title: "1")
        pressButton(title: "0")
        // run from LBL A
        pressButton(title: "f")
        pressButton(title: "√x")
        let factor = 2.0  // found by trial and error
        // verify display = 10
        let exp0 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp0], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "10.0000", "Display is not correct")
        // verify display = 9
        let exp1 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp1], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "9.0000", "Display is not correct")
        // verify display = 8
        let exp2 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp2], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "8.0000", "Display is not correct")
        // verify display = 7
        let exp3 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp3], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "7.0000", "Display is not correct")
        // verify display = 6
        let exp4 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp4], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "6.0000", "Display is not correct")
        // verify display = 5
        let exp5 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp5], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "5.0000", "Display is not correct")
    }
    
    // test ISG (increment loop control)
    // enter program:
    //   LBL A
    //   f PSE
    //   1 +
    //   f ISG .3  <- use loop counter in storage register .3
    //   GTO A
    //   g RTN
    // setup:
    //   0.00401 STO .3  <- loop counter starts at 0 and counts up by 1, until reaching 4 (ccccc.tttii)
    //   5
    // verify: display counts down from 5 to 10
    func test12ISG() {
        startNewProgram()
        // LBL A
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "√x")
        // f PSE
        pressButton(title: "f")
        pressButton(title: "R/S")
        // 1 +
        pressButton(title: "1")
        pressButton(title: "+")
        // f ISG .3
        pressButton(title: "f")
        pressButton(title: "6")
        pressButton(title: "·")
        pressButton(title: "3")
        // GTO A
        pressButton(title: "GTO")
        pressButton(title: "√x")
        // g RTN
        pressButton(title: "g")
        pressButton(title: "GSB")
        // end program
        pressButton(title: "g")
        pressButton(title: "R/S")

        // setup
        // set display to 4 digits fixed
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "4")
        // 0.00401 STO .3
        pressButton(title: "·")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "4")
        pressButton(title: "0")
        pressButton(title: "1")
        pressButton(title: "STO")
        pressButton(title: "·")
        pressButton(title: "3")
        // 5
        pressButton(title: "5")
        // run from LBL A
        pressButton(title: "f")
        pressButton(title: "√x")
        let factor = 2.0  // found by trial and error
        // verify display = 5
        let exp0 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp0], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "5.0000", "Display is not correct")
        // verify display = 6
        let exp1 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp1], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "6.0000", "Display is not correct")
        // verify display = 7
        let exp2 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp2], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "7.0000", "Display is not correct")
        // verify display = 8
        let exp3 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp3], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "8.0000", "Display is not correct")
        // verify display = 9
        let exp4 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp4], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "9.0000", "Display is not correct")
        // verify display = 10
        let exp5 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp5], timeout: factor * Pause.running)
        XCTAssertEqual(cvc.displayString, "10.0000", "Display is not correct")
    }

    // test root solver (from p.182 Owner's Handbook)
    // enter program:
    //   LBL A
    //   3
    //   –
    //   x
    //   10
    //   –
    //   RTN
    //
    // verify: root = 5, with initial guesses of 0 and 10
    func test13RootSolving() {
        startNewProgram()
        // LBL A
        pressButton(title: "f")
        pressButton(title: "SST")
        pressButton(title: "√x")
        // 3 – x 10
        pressButton(title: "3")
        pressButton(title: "–")
        pressButton(title: "×")
        pressButton(title: "1")
        pressButton(title: "0")
        pressButton(title: "–")
        // RTN
        pressButton(title: "g")
        pressButton(title: "GSB")
        // end program
        pressButton(title: "g")
        pressButton(title: "R/S")
        
        // initial guesses of 0 and 10
        pressButton(title: "0")
        pressButton(title: "ENTER")
        pressButton(title: "1")
        pressButton(title: "0")
        // SOLVE A
        pressButton(title: "f")
        pressButton(title: "÷")
        pressButton(title: "√x")
        // verify display = 5.0000
        let exp1 = expectation(description: "Wait for results to display")
        _ = XCTWaiter.wait(for: [exp1], timeout: 1.1 * Pause.running)
        XCTAssertEqual(cvc.displayString, "5.0000", "Display is not correct")
    }

    // MARK: - Utilities

    func startNewProgram() {
        // enter program mode
        pressButton(title: "g")
        pressButton(title: "R/S")
        // clear past program, if any
        pressButton(title: "f")
        pressButton(title: "R↓")
        XCTAssertEqual(cvc.program.currentInstruction, "000-", "Instruction is not correct")
    }
    
    func setupFlagsTest() {
        // set display to 4 digits fixed
        pressButton(title: "f")
        pressButton(title: "7")
        pressButton(title: "4")
        // 250 ENTER
        pressButton(title: "2")
        pressButton(title: "5")
        pressButton(title: "0")
        pressButton(title: "ENTER")
        // 48 ENTER
        pressButton(title: "4")
        pressButton(title: "8")
        pressButton(title: "ENTER")
        // .005
        pressButton(title: "·")
        pressButton(title: "0")
        pressButton(title: "0")
        pressButton(title: "5")
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
