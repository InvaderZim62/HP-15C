//
//  Program.swift
//  RPCalculator
//
//  Created by Phil Stern on 6/14/24.
//
//  Each line of a program is an instruction.
//  An instruction is a line number followed by 1 to 3 key-codes.
//  If there are three key-codes, they are separated by commas, otherwise they are separated by spaces.
//  A key-code is the row and column of the button, except for number keys, which are just represented by the number itself.
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

import Foundation

class Program {
    
    var instructions = [String]()
    var prefix = ""
    var instructionCodes = [String]()
    
    // note: period is used (replaced in digitKeyPressed), instead of "MIDDLE-DOT" (actual key label)
    //       minus sign is an "EN DASH"

    let keycodes: [String: String] = [  // [button label: key-code]
         "√x": "11",  "ex": "12", "10x": "13",  "yx": "14", "1/x": "15",   "CHS": "16", "7": " 7", "8": " 8",  "9": " 9", "÷": "10",
        "SST": "21", "GTO": "22", "SIN": "23", "COS": "24", "TAN": "25",   "EEX": "26", "4": " 4", "5": " 5",  "6": " 6", "×": "20",
        "R/S": "31", "GSB": "32",  "R↓": "33", "x≷y": "34",   "←": "35", "ENTER": "36", "1": " 1", "2": " 2",  "3": " 3", "–": "30",
         "ON": "41",   "f": "42",   "g": "43", "STO": "44", "RCL": "45",                "0": " 0", ".": "48", "Σ+": "49", "+": "40"]

    // Prefix   buttonLabel(s)
    // f        f    // basic (single digit)
    // g        g
    // STO      STO
    // RCL      RCL
    // FIX      f 7  // compound (two digits)
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
            instructionCodes = [keycodes[buttonLabel]!]
        case "STO":
            if instructionCodes.isEmpty || prefix == "RCL" {
                // if "RCL" is entered after "STO" (with no prior prefix), the program instruction starts over
                prefix = buttonLabel
                instructionCodes = [keycodes[buttonLabel]!]
            } else {
                // instruction complete
                instructionCodes.append(keycodes[buttonLabel]!)
                return instruction
            }
        case "RCL":
            if instructionCodes.isEmpty || prefix == "STO" {
                // if "STO" is entered after "RCL" (with no prior prefix), the program instruction starts over
                prefix = buttonLabel
                instructionCodes = [keycodes[buttonLabel]!]
            } else {
                // instruction complete
                instructionCodes.append(keycodes[buttonLabel]!)
                return instruction
            }
        case "7", "8", "9":
            if prefix == "f" {
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(keycodes[buttonLabel]!)
                return instruction
            }
        case "GTO":
            if prefix == "f" || prefix == "g" {
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(keycodes[buttonLabel]!)
                return instruction
            }
        case "4", "5":
            if prefix == "g" {
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(keycodes[buttonLabel]!)
                return instruction
            }
        case "+", "–", "×", "÷":  // minus sign is an "EN DASH"
            if prefix == "STO" || prefix == "RCL" {
                // compound prefix
                prefix += buttonLabel
                instructionCodes.append(keycodes[buttonLabel]!)
            } else {
                // instruction complete
                instructionCodes.append(keycodes[buttonLabel]!)
                return instruction
            }
        default:
            // instruction complete
            instructionCodes.append(keycodes[buttonLabel]!)
            return instruction
        }
        return nil  // continue adding instructionCodes
    }

    // format
    // 3 codes: "nnn-cc,cc,cc" (commas get attached to prior digit in DisplayView)
    // 2 codes: "nnn- cc cc"  ex. g COS
    // 2 codes: "nnn-  cc c"  ex. STO 1
    // 1 code:  "nnn-    cc"

    var instruction: String {
        let lineNumber = String(format: "%03d", instructions.count)
        var codes = ""
        switch instructionCodes.count {
        case 1:
            codes = "    " + instructionCodes[0]
        case 2:
            if instructionCodes[1].first == " " {
                codes = "  " + instructionCodes[0] + instructionCodes[1]
            } else {
                codes = " " + instructionCodes[0] + " " + instructionCodes[1]
            }
        case 3:
            codes = instructionCodes[0] + "," + instructionCodes[1] + "," + instructionCodes[2]
        default:
            break
        }
        let instruction = "\(lineNumber)-\(codes)"
        instructions.append(instruction)
        instructionCodes.removeAll()  // start new
        prefix = ""
        print(instruction)
        return instruction
    }
}
