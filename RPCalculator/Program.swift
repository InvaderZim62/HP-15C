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

protocol ProgramDelegate: AnyObject {
    func setError(_ number: Int)
}

import Foundation

class Program: Codable {
    
    weak var delegate: ProgramDelegate?
    
    var instructions = [String]()
    var currentLine = 0
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
        self.currentLine = try container.decode(Int.self, forKey: .currentLine)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.instructions, forKey: .instructions)
        try container.encode(self.currentLine, forKey: .currentLine)
    }
    
    // MARK: - Start of code
    
    var currentInstruction: String {
        instructions[currentLine]
    }
    
    func incrementCurrentLine() {
        currentLine = (currentLine + 1) % instructions.count
    }
    
    var currentInstructionCodes: [Int] {
        let instruction = currentInstruction  // "nnn-42,22,23"
        let codeString = String(instruction.suffix(from: codeStart))  // "42,22,23"
        return codesFrom(codeString: codeString)  // [42, 22, 23]
    }
    
    var currentInstructionTitles: [String] {
        return titlesFrom(keyCodes: currentInstructionCodes)  // ["f", "GTO", "SIN"]
    }

    func enterProgramMode() {
        if instructions.count <= 1 {
            instructions = ["000-"]
            currentLine = 0
        }
        prefix = ""
        instructionCodes = []
    }
    
    func clearProgram() {
        instructions = []
        instructionCodes = []
        currentLine = 0
    }
    
    func forwardStep() -> String {
        prefix = ""
        instructionCodes = []
        currentLine = (currentLine + 1) % instructions.count
        return currentInstruction
    }
    
    func backStep() -> String {
        prefix = ""
        instructionCodes = []
        currentLine = (currentLine - 1) % instructions.count
        if currentLine < 0 { currentLine += instructions.count }
        return currentInstruction
    }
    
    func deleteCurrentInstruction() {
        guard currentLine > 0 else { return }
        instructions.remove(at: currentLine)
        renumberInstructions()
        currentLine -= 1  // leave at prior instruction
    }
    
    func renumberInstructions() {
        for index in 0..<instructions.count {
            instructions[index] = index.asThreeDigitString + "-" + instructions[index].suffix(from: codeStart)
        }
    }

    // MARK: - Start of code

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
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else if prefix == "f" && buttonLabel == "SST" {
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return instruction
            }
        case "√x", "ex", "10x", "yx", "1/x":
            if prefix == "fSST" {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return instruction
            }
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
                        currentLine = gotoLineNumber
                        return currentInstruction
                    }
                }
            } else if prefix == "f" && (buttonLabel == "7" || buttonLabel == "8" || buttonLabel == "9") {
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else if prefix == "g" && (buttonLabel == "4" || buttonLabel == "5") {
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return instruction
            }
        case "+", "–", "×", "÷":  // minus sign is an "EN DASH"
            if prefix == "STO" || prefix == "RCL" {
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(Program.keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return instruction
            }
        case "R↓":
            if prefix == "f" {
                // CLEAR PRGM
                clearProgram()
                return instruction
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return instruction
            }
        case "←":
            switch prefix {
            case "":  // non-programmable
                deleteCurrentInstruction()
                return currentInstruction
            case "g":
                // CLX
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonLabel]!)
                return instruction
            default:
                prefix = ""
                break  // non-programmable
            }
        default:
            // instruction complete
            instructionCodes.append(Program.keycodes[buttonLabel]!)
            return instruction
        }
        return nil  // continue adding instructionCodes
    }

    // instruction format:
    // 3 codes: "nnn-42,22,23" <=> f GTO SIN (commas get attached to prior digit in DisplayView)
    // 3 codes: "nnn-42, 7, 4" <=> f 7 4
    // 2 codes: "nnn- 43 24"   <=> g COS
    // 2 codes: "nnn-  44 1"   <=> STO 1
    // 1 code:  "nnn-    12"   <=> e^x
    var instruction: String {
        if instructions.isEmpty {
            instructions.append("000-")
            return "000-"
        } else {
            currentLine += 1
            let instruction = "\(currentLine.asThreeDigitString)-\(codeString)"
            instructions.insert(instruction, at: currentLine)
            renumberInstructions()
            instructionCodes.removeAll()  // start new
            prefix = ""
            return instruction
        }
    }
    
    // convert from array of codes to string, with specific spacing
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
    
    func isLabel(codes: [Int]) -> Bool {
        // label if f-key A-E, or f-LBL A-E
        (codes.count == 2 && codes[0] == 42 && codes[1] >= 11 && codes[1] <= 15) ||
        (codes.count == 3 && codes[0] == 42 && codes[1] == 21 && codes[2] >= 11 && codes[2] <= 15)
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
