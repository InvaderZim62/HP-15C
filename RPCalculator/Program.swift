//
//  Program.swift
//  RPCalculator
//
//  Created by Phil Stern on 6/14/24.
//
//  Each line of a program is an instruction.
//  An instruction is a line number followed by 1 to 3 key-codes.
//  If there are three key-codes, they are separated by commas, otherwise they are separated by spaces.
//  A key-code is the row and column of the button, except for number keys, which are just represented by the numbers themselves.
//  Rows go from 1...4 (top to bottom).
//  Columns go from 1...9, 0 (left to right), where 0 is the 10th column.
//
//  Ex. "006-44,40, 1"
//    006 is the line number = 6
//     44 is row 1, col 4    = "STO"
//     40 is row 4, col 10   = "+"
//      1 is the number key  = "1"
//
//  Ex. "003-      20"
//    003 is the line number = 3
//     20 is row 2, col 10   = "x"
//
// Goto line number (GTO-CHS-nnn) can be issued in program mode or run mode (non-program mode)...
//
// program mode:
// - programKeyPressed sends "GTO" to prefixKeyPressed
// - prefixKeyPressed sends "GTO" to buildInstructionWith (and sets prefix = .GTO in CalculatorViewController)
//   > buildInstructionWith changes prefix to "GTO" (sets instructionCodes = [22])
// - operationKeyPressed sends "CHS" to buildInstructionWith (and sets prefix = nil in CalculatorViewController)
//   > buildInstructionWith changes prefix to "GTOCHS" (sets instructionCodes = [], since changing line is non-programmable)
// - digitKeyPressed sends numbers to buildInstructionWith
//   > buildInstructionWith accumulates 3 line numbers, then increments program line number
//
// run mode:
// - programKeyPressed sends "GTO" to prefixKeyPressed
// - prefixKeyPressed changes prefix to .GTO (in CalculatorViewController)
// - operationKeyPressed sends "CHS" to prefixKeyPressed
// - prefixKeyPressed changes prefix to .GTO_CHS (in CalculatorViewController)
// - digitKeyPressed accumulates 3 line numbers, then increments program line number
//

import UIKit

protocol ProgramDelegate: AnyObject {
    func prepStackForOperation()
    func setError(_ number: Int)
    var buttons: [UIButton]! { get }
    var isRunMode: Bool { get set }
    var useSimButton: Bool { get set }
}

class Program: Codable {
    
    weak var delegate: ProgramDelegate?
    
    var brain: CalculatorBrain!
    
    var instructions = [String]()
    var currentLineNumber = 0
    var prefix = ""
    var instructionCodes = [String]()  // used for building up compound instructions
    var gotoLineNumberDigits = [Int]()
    let codeStart = "nnn-".index("nnn-".startIndex, offsetBy: 4)

    // note: period is used (replaced in digitKeyPressed), instead of "MIDDLE-DOT" (actual key label);
    //       minus sign is an "EN DASH" (U+2013)

    static let keycodes: [String: String] = [  // [button title: key-code]
         "√x": "11",  "ex": "12", "10x": "13",  "yx": "14", "1/x": "15",           "CHS": "16", "7": " 7", "8": " 8",  "9": " 9", "÷": "10",
        "SST": "21", "GTO": "22", "SIN": "23", "COS": "24", "TAN": "25",           "EEX": "26", "4": " 4", "5": " 5",  "6": " 6", "×": "20",
        "R/S": "31", "GSB": "32",  "R↓": "33", "x≷y": "34",   "←": "35", "E\nN\nT\nE\nR": "36", "1": " 1", "2": " 2",  "3": " 3", "–": "30",
         "ON": "41",   "f": "42",   "g": "43", "STO": "44", "RCL": "45",                        "0": " 0", ".": "48", "Σ+": "49", "+": "40"]

    // inverse of keycodes dictionary
    static let buttonTitles = Dictionary(uniqueKeysWithValues: keycodes.map({ ($1, $0) }))
    
    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case instructions, currentLine }
    
    init() { }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.instructions = try container.decode([String].self, forKey: .instructions)
        self.currentLineNumber = try container.decode(Int.self, forKey: .currentLine)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.instructions, forKey: .instructions)
        try container.encode(self.currentLineNumber, forKey: .currentLine)
    }
    
    // MARK: - Start of code
    
    func incrementCurrentLine() {
        currentLineNumber = (currentLineNumber + 1) % instructions.count
    }

    func enterProgramMode() {
        if instructions.count <= 1 {
            instructions = ["000-"]
            currentLineNumber = 0
        }
        prefix = ""
        instructionCodes = []
    }
    
    func clearProgram() {
        instructions = []
        instructionCodes = []
        currentLineNumber = 0
    }
    
    func forwardStep() -> String {
        prefix = ""
        instructionCodes = []
        currentLineNumber = (currentLineNumber + 1) % instructions.count  // pws: prior to incrementing, if current instruction is RTN [43, 32], go to line 000
        return currentInstruction
    }
    
    func backStep() -> String {
        prefix = ""
        instructionCodes = []
        currentLineNumber = (currentLineNumber - 1) % instructions.count
        if currentLineNumber < 0 { currentLineNumber += instructions.count }
        return currentInstruction
    }
    
    // search forward through program, until label found; return false, if not found;
    // leave program at line with label, or original location, if label not found
    func gotoLabel(_ label: String) -> Bool {
        var labelFound = false
        let labelCodeString = "42,21,\(Program.keycodes[label]!)"  // ex. "42,21,11" for Label A
        for _ in 0..<instructions.count {
            if currentInstructionCodeString == labelCodeString {
                labelFound = true
                break
            }
            _ = forwardStep()
        }
        return labelFound
    }
    
    private func deleteCurrentInstruction() {
        guard currentLineNumber > 0 else { return }
        instructions.remove(at: currentLineNumber)
        renumberInstructions()
        currentLineNumber -= 1  // leave at prior instruction
    }
    
    private func renumberInstructions() {
        for index in 0..<instructions.count {
            instructions[index] = index.asThreeDigitString + "-" + codeStringFromInstruction(instructions[index])
        }
    }

    // Prefix   buttonLabel(s)
    // f        f    // basic (single digit)
    // g        g
    // GTO      GTO
    // STO      STO
    // RCL      RCL
    // GTO_CHS  GTO CHS  // compound (two digits)
    // LBL      f SST
    // FIX      f 7
    // SCI      f 8
    // ENG      f 9
    // HYP      f GTO
    // HYP1     g GTO
    // SF       g 4
    // CF       g 5
    // STO_ADD  STO +
    // STO_SUB  STO –
    // STO_MUL  STO ×
    // STO_DIV  STO ÷
    // RCL_ADD  RCL +
    // RCL_SUB  RCL –
    // RCL_MUL  RCL ×
    // RCL_DIV  RCL ÷

    // in program mode, CalculatorViewController sends all button labels directly to buildInstructionWith
    // (except for "program buttons"); buildInstructionWith accumulates labels in the form of key codes,
    // until a complete instruction is formed and returned; the complete instruction may have up to two
    // prefixes; buildInstructionWith returns nil while prefixes are received.
    
    // some program buttons manipulate the program (SST, BST, ←, GTO-CHS, ...) and are not added to the
    // instructions (return nil); others are added to the instructions (R/S, RTN, GTO, ...);

    func buildInstructionWith(_ buttonLabel: String) -> String? {
        switch buttonLabel {
        case "f", "g":
            // any time "f" or "g" is entered, the program instruction starts over
            prefix = buttonLabel
            instructionCodes = [Program.keycodes[buttonLabel]!]
        case "GTO", "STO", "RCL", "SST":
            if instructionCodes.isEmpty || prefix == "GTO" || prefix == "STO" || prefix == "RCL" || prefix == "LBL" {
                // if there is no other current prefix, these three can override each other;
                // start the program instruction over with the latest one
                prefix = buttonLabel
                instructionCodes = [Program.keycodes[buttonLabel]!]
            } else if (prefix == "f" || prefix == "g") && buttonLabel == "GTO" {
                // compound prefix (HYP or HYP-1)
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else if prefix == "f" && buttonLabel == "SST" {
                // compound prefix (LBL)
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return insertedInstruction
            }
        case "√x", "ex", "10x", "yx", "1/x":
            // instruction complete
            instructionCodes.append(Program.keycodes[buttonLabel]!)
            return insertedInstruction
        case "CHS":
            if prefix == "GTO" {  // non-programmable
                // compound prefix
                prefix += buttonLabel
                instructionCodes = []
                gotoLineNumberDigits = []
            }
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            if prefix == "GTOCHS" {  // non-programmable
                // add buttonLabel to gotoLineNumber
                gotoLineNumberDigits.append(Int(buttonLabel)!)
                if gotoLineNumberDigits.count == 3 {
                    // all goto line number received
                    prefix = ""
                    let gotoLineNumber = 100 * gotoLineNumberDigits[0] + 10 * gotoLineNumberDigits[1] + gotoLineNumberDigits[2]
                    if gotoLineNumber >= instructions.count {
                        // line number past end of program
                        delegate?.setError(4)  // have CalculatorViewController process the error
                    } else {
                        // line number within program
                        currentLineNumber = gotoLineNumber
                        return currentInstruction
                    }
                }
            } else if prefix == "f" && (buttonLabel == "7" || buttonLabel == "8" || buttonLabel == "9") {
                // compound prefix (FIX, SCI, or ENG)
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else if prefix == "g" && (buttonLabel == "4" || buttonLabel == "5") {
                // compound prefix (SF or CF)
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return insertedInstruction
            }
        case ".":
            if prefix == "LBL" {
                // compound prefix (LBL .)
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return insertedInstruction
            }
        case "+", "–", "×", "÷":  // minus sign is an "EN DASH"
            if prefix == "STO" || prefix == "RCL" {
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return insertedInstruction
            }
        case "COS":
            if prefix == "f" {
                // (i) (non-programmable)
                prefix = ""
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return insertedInstruction
            }
        case "R↓":
            if prefix == "f" {
                // CLEAR PRGM (non-programmable)
                prefix = ""
                clearProgram()
                return insertedInstruction
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return insertedInstruction
            }
        case "←":
            switch prefix {
            case "":
                // ←
                // delete instruction (non-programmable)
                deleteCurrentInstruction()
                return currentInstruction
            case "g":
                // CLX
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return insertedInstruction
            default:
                // ex. PREFIX (non-programmable)
                prefix = ""
            }
        default:
            // instruction complete
            instructionCodes.append(Program.keycodes[buttonLabel]!)
            return insertedInstruction
        }
        return nil  // continue adding instructionCodes
    }

    // create and insert instruction
    // format:
    // 3 codes: "nnn-42,22,23" <=> f GTO SIN (commas get attached to prior digit in DisplayView)
    // 3 codes: "nnn-42, 7, 4" <=> f 7 4
    // 2 codes: "nnn- 43 24"   <=> g COS
    // 2 codes: "nnn-  44 1"   <=> STO 1
    // 1 code:  "nnn-    12"   <=> e^x
    var insertedInstruction: String {
        if instructions.isEmpty {
            instructions.append("000-")
            return "000-"
        } else {
            currentLineNumber += 1
            let instruction = "\(currentLineNumber.asThreeDigitString)-\(codeString)"
            instructions.insert(instruction, at: currentLineNumber)
            renumberInstructions()
            instructionCodes.removeAll()  // start new
            prefix = ""
            return instruction
        }
    }
    
    // MARK: - Run Program
    
    func runFrom(label: String, completion: @escaping () -> Void) {
        if gotoLabel(label) {
            runFromCurrentLine(completion: completion)
        } else {
            delegate?.setError(4)  // label not found
        }
    }
    
    func runFromCurrentLine(completion: @escaping () -> Void) {
        // run instructions from current line, until one of the following is found:
        // - last instruction (go to line 0 and stop)
        // - R/S instruction found (go to next line and stop)
        // - PSE pause for 1.2 sec and continue (1.2 sec for each, if multiple PSE in-a-row)
        // - ignore any labels, and continue
        while currentLineNumber > 0 {
            if isCurrentInstructionARunStop {
                // stop running - increment line number
                _ = forwardStep()
                break  // exit while loop
            } else if isCurrentInstructionAReturn {
                // stop running - goto line 0
                currentLineNumber = 0
                break  // exit while loop
            } else if isCurrentInstructionAPause {
                // pause and continue, recursively
                DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) { [unowned self] in
                    delegate?.isRunMode = true  // show "running" when continuing after pause
                    DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) { [unowned self] in
                        _ = forwardStep()
                        runFromCurrentLine(completion: completion)
                    }
                }
                return  // stop and wait for pause to restart program
            } else {
                // run instruction
                //---------------------
                runCurrentInstruction()
                //---------------------
                if brain.error == .none {
                    _ = forwardStep()
                } else {
                    delegate?.isRunMode = false
                    return  // stop for errors
                }
            }
        }
        delegate?.isRunMode = false
        completion()
    }

    func runCurrentInstruction() {
        if isCurrentInstructionALabel {
            // non-executable instruction - if user was entering digits, send display to stack
            delegate?.prepStackForOperation()
        } else {
            // executable instruction - run it
            let titles = currentInstructionTitles  // ex. ["f", "GTO", "SIN"]
            for title in titles {
                let button = delegate?.buttons.first(where: { $0.currentTitle == title })
                delegate?.useSimButton = false  // don't play click sound
                //----------------------------------
                button?.sendActions(for: .touchDown)
                //----------------------------------
                delegate?.useSimButton = true
            }
        }
    }

    // MARK: - Utilities
    
    var currentInstruction: String {
        instructions[currentLineNumber]
    }
    
    // "001-42,22,23" => "42,22,23"
    func codeStringFromInstruction(_ instruction: String) -> String {
        String(instruction.suffix(from: codeStart))
    }
    
    // code string from current instruction
    // ex. "42,"22",23"
    var currentInstructionCodeString: String {
        codeStringFromInstruction(currentInstruction)
    }

    // key-codes in current instruction
    // ex. [42, 22, 23]
    var currentInstructionCodes: [Int] {
        codesFrom(codeString: currentInstructionCodeString)
    }
    
    // button titles for current instruction
    // ex. ["f", "GTO", "SIN"]
    var currentInstructionTitles: [String] {
        return titlesFrom(keyCodes: currentInstructionCodes)
    }
    
    // when running a program, labels are non-executable
    var isCurrentInstructionALabel: Bool {
        isLabel(codes: currentInstructionCodes)
    }

    // a label is contained in a single instruction with these codes:
    // [42, 11-15]     = "f A-E", or
    // [42, 21, 11-15] = "f LBL A-E"
    func isLabel(codes: [Int]) -> Bool {
        (codes.count == 2 && codes[0] == 42 && codes[1] >= 11 && codes[1] <= 15) ||
        (codes.count == 3 && codes[0] == 42 && codes[1] == 21 && codes[2] >= 11 && codes[2] <= 15)
    }

    // stop running when R/S found
    var isCurrentInstructionARunStop: Bool {
        isRunStop(codes: currentInstructionCodes)
    }
    
    func isRunStop(codes: [Int]) -> Bool {
        codes == [31]
    }

    // stop running and goto line 0 when RTN found
    var isCurrentInstructionAReturn: Bool {
        isReturn(codes: currentInstructionCodes)
    }
    
    func isReturn(codes: [Int]) -> Bool {
        codes == [43, 32]
    }

    var isCurrentInstructionAPause: Bool {
        isPause(codes: currentInstructionCodes)
    }
    
    func isPause(codes: [Int]) -> Bool {
        codes == [42, 31]
    }

//    var isLastLine: Bool {
//        currentLineNumber == instructions.count - 1
//    }
    
    // convert from code string to array of codes
    // ex. "42,22,23" => [42, 22, 23]
    //     "42, 7, 4" => [42, 7, 4]
    //       " 43 24" => [43, 24]
    //       "  44 1" => [44, 1]
    func codesFrom(codeString: String) -> [Int] {
        guard !codeString.isEmpty else { return [] }
        let delimiter = codeString.contains(",") ? "," : " "
        let codesArray = codeString.trimmingCharacters(in: .whitespaces).components(separatedBy: delimiter)
        return codesArray.map { Int($0.trimmingCharacters(in: .whitespaces))! }
    }
    
    // convert from array of codes to array of button labels
    // ex. [42, 22, 23] => ["f", "GTO", "SIN"]
    //         [43, 24] => ["g", "COS"]
    //          [44, 1] => ["STO", "1"]
    func titlesFrom(keyCodes: [Int]) -> [String] {
        keyCodes.map { Program.buttonTitles[String(format: "%2d", $0)]! }
    }

    // convert from array of codes to code string
    // ex. [42, 22, 23] => "42,22,23"
    //       [42, 7, 4] => "42, 7, 4"
    //         [43, 24] => " 43 24"
    //          [44, 1] => "  44 1"
    var codeString: String {
        var codes = ""
        switch instructionCodes.count {
        case 1:
            codes = "    " + instructionCodes[0]
        case 2:
            if instructionCodes[1].first == " " {
                // single digit second code (ex. ["12"," 3"])
                codes = "  " + instructionCodes[0] + instructionCodes[1]
            } else {
                // two-digit second code (ex. ["12","34"])
                codes = " " + instructionCodes[0] + " " + instructionCodes[1]
            }
        case 3:
            codes = instructionCodes[0] + "," + instructionCodes[1] + "," + instructionCodes[2]
        default:
            break
        }
        return codes
    }
}

extension Int {
    var asThreeDigitString: String {
        String(format: "%03d", self)
    }
}

extension String {
    var isInstruction: Bool {
        if self.count < 4 {
            return false
        } else {
            let ndash = self.index(self.startIndex, offsetBy: 3)
            return self[ndash] == "-"
        }
    }
}
