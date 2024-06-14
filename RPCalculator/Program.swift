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
    
    let buttons = [
        [ "√x",  "ex", "10x",  "yx", "1/x",   "CHS", "7", "8",  "9", "÷"],
        ["SST", "GTO", "SIN", "COS", "TAN",   "EEX", "4", "5",  "6", "×"],
        ["R/S", "GSB",  "R↓", "x≷y",   "←", "ENTER", "1", "2",  "3", "–"],
        [ "ON",   "f",   "g", "STO", "RCL",      "", "0", ".", "Σ+", "+"]
    ]
    
    // note: period is used (replaced in digitKeyPressed), instead of "MIDDLE-DOT" (actual key label)
    
    let keycodes: [String: String] = [  // [button label: key-code]
         "√x": "11",  "ex": "12", "10x": "13",  "yx": "14", "1/x": "15",   "CHS": "16", "7": " 7", "8": " 8",  "9": " 9", "÷": "10",
        "SST": "21", "GTO": "22", "SIN": "23", "COS": "24", "TAN": "25",   "EEX": "26", "4": " 4", "5": " 5",  "6": " 6", "×": "20",
        "R/S": "31", "GSB": "32",  "R↓": "33", "x≷y": "34",   "←": "35", "ENTER": "36", "1": " 1", "2": " 2",  "3": " 3", "–": "30",
         "ON": "41",   "f": "42",   "g": "43", "STO": "44", "RCL": "45",                "0": " 0", ".": "48", "Σ+": "49", "+": "40"]
    
    func addInstruction(_ keySequence: String) -> String {
        let keycode = keycodes[keySequence]!
        let lineNumber = String(format: "%03d", instructions.count)
        let instruction = "\(lineNumber)-\(keycode)"
        instructions.append(instruction)
        print(instructions)
        return instruction
    }
}
