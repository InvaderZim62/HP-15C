//
//  ProgramUnitTest.swift
//  RPCalculatorTests
//
//  Created by Phil Stern on 8/3/24.
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
    // - GTO B     => GTO B (try first without f)
    // - GTO f B   => GTO B (same answer)
    // - GSB f C   => GSB C
    // - STO f D   => STO D
    // - STO + f E => STO + E
    //
    // "GTO", "GSB", "STO", "STO+", "STO–", "STO×", "STO÷", "RCL", "RCL+", "RCL–", "RCL×", "RCL÷", "f4", "f÷", "f×", "fSST":
    func test02DropFBeforeLabel() {
        startNewProgram()
        // GTO B
        pressButton(title: "GTO")
        pressButton(title: "ex")
        // GTO: 22, B: 12
        XCTAssertEqual(cvc.program.currentInstruction, "001- 22 12", "Instruction is not correct")
        
        // GTO f B
        pressButton(title: "GTO")
        pressButton(title: "f")
        pressButton(title: "ex")
        // GTO: 22, B: 12 (f is dropped)
        // currentInstructionCodeString doesn't include line number, to allow easier cut-and-paste
        XCTAssertEqual(cvc.program.currentInstructionCodeString, " 22 12", "Instruction codes are not correct")
        
        // GSB f C
        pressButton(title: "GSB")
        pressButton(title: "f")
        pressButton(title: "10x")
        // GSB: 32, C: 13 (f is dropped)
        XCTAssertEqual(cvc.program.currentInstructionCodeString, " 32 13", "Instruction codes are not correct")
        
        // STO f D
        pressButton(title: "STO")
        pressButton(title: "f")
        pressButton(title: "yx")
        // STO: 44, D: 14 (f is dropped)
        XCTAssertEqual(cvc.program.currentInstructionCodeString, " 44 14", "Instruction codes are not correct")
        
        // STO + f E
        pressButton(title: "STO")
        pressButton(title: "+")
        pressButton(title: "f")
        pressButton(title: "1/x")
        // STO: 44, +: 40, E: 15 (f is dropped)
        XCTAssertEqual(cvc.program.currentInstructionCodeString, "44,40,15", "Instruction codes are not correct")
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
