//
//  ProgramUnitTest.swift
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
    
    // create button with input title, and invoke the button action
    func pressButton(title: String) {
        let button = UIButton()
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
            assert(false, "No button has the title \"\(title)\"")
        }
    }
}
