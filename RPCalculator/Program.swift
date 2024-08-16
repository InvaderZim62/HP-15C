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
    var flags: [Bool] { get }
    var isProgramRunning: Bool { get set }
    var useSimButton: Bool { get set }
}

class Program: Codable {
    
    weak var delegate: ProgramDelegate?
    
    var brain: Brain!
    
    let semaphore = DispatchSemaphore(value: 1)
    var instructions = [String]()
    var currentLineNumber = 0
    var prefix = ""
    var instructionCodes = [String]()  // used for building up compound instructions
    var gotoLineNumberDigits = [Int]()
    var returnToLineNumbers = [Int]()
    let codeStart = "nnn-".index("nnn-".startIndex, offsetBy: 4)
    var isProgramPaused = false
    var isAnyButtonPressed = false  // use to interrupt running of program

    // note: period is used (replaced in digitKeyPressed), instead of "MIDDLE-DOT" (actual key label);
    //       minus sign is an "EN DASH" (U+2013)

    static let keycodes: [String: String] = [  // [button title: key-code]
         "√x": "11",  "ex": "12", "10x": "13",  "yx": "14", "1/x": "15",           "CHS": "16", "7": " 7", "8": " 8",  "9": " 9", "÷": "10",
        "SST": "21", "GTO": "22", "SIN": "23", "COS": "24", "TAN": "25",           "EEX": "26", "4": " 4", "5": " 5",  "6": " 6", "×": "20",
        "R/S": "31", "GSB": "32",  "R↓": "33", "x≷y": "34",   "←": "35", "E\nN\nT\nE\nR": "36", "1": " 1", "2": " 2",  "3": " 3", "–": "30",
         "ON": "41",   "f": "42",   "g": "43", "STO": "44", "RCL": "45",                        "0": " 0", ".": "48", "Σ+": "49", "+": "40"]

    // inverse of keycodes dictionary [key-code: button title]
    static let buttonTitles = Dictionary(uniqueKeysWithValues: keycodes.map({ ($1, $0) }))

    // these prefixes can be followed by A-E, (i), or I; if "f" appears in-between,
    // it gets removed (ex. GTO-f-A => GTO-A, f-4-f-I => f-4-I,...)
    static let allowableSuffixes: [String: [String]] = [
        //          A     B      C     D      E     (i)     I
        "GTOf"  : ["√x", "ex", "10x", "yx", "1/x",        "TAN"],  // don't include buttons followed by numbers (ex. f FIX 4)
        "GSBf"  : ["√x", "ex", "10x", "yx", "1/x",        "TAN"],
        "STOf"  : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "STO+f" : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "STO–f" : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "STO×f" : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "STO÷f" : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "RCLf"  : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "RCL+f" : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "RCL–f" : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "RCL×f" : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "RCL÷f" : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "f÷f"   : ["√x", "ex", "10x", "yx", "1/x"              ],
        "f×f"   : ["√x", "ex", "10x", "yx", "1/x"              ],
        "fSSTf" : ["√x", "ex", "10x", "yx", "1/x"              ],
        "f7f"   : [                                       "TAN"],
        "f8f"   : [                                       "TAN"],
        "f9f"   : [                                       "TAN"],
        "f4f"   : ["√x", "ex", "10x", "yx", "1/x", "COS", "TAN"],
        "f5f"   : [                                "COS", "TAN"],
        "f6f"   : [                                "COS", "TAN"],
        "g4f"   : [                                       "TAN"],
        "g5f"   : [                                       "TAN"],
        "g6f"   : [                                       "TAN"]
    ]
    
    let specialPrefixes = allowableSuffixes.keys.map { String($0.dropLast()) }
    
    //  n  test    n  test
    //  -  -----   -  -----
    //  0  x ≠ 0   6  x ≠ y
    //  1  x > 0   7  x > y
    //  2  x < 0   8  x < y
    //  3  x ≥ 0   9  x ≥ y
    //  4  x ≤ 0  10  x ≤ y
    //  5  x = y  11  x = 0
    func test(_ number: Int) -> Bool {
        switch number {
        case 0:
            return brain.xRegister! != 0
        case 1:
            return brain.xRegister! > 0
        case 2:
            return brain.xRegister! < 0
        case 3:
            return brain.xRegister! >= 0
        case 4:
            return brain.xRegister! <= 0
        case 5:
            return brain.xRegister! == brain.yRegister
        case 6:
            return brain.xRegister! != brain.yRegister
        case 7:
            return brain.xRegister! > brain.yRegister
        case 8:
            return brain.xRegister! < brain.yRegister
        case 9:
            return brain.xRegister! >= brain.yRegister
        case 10:
            return brain.xRegister! <= brain.yRegister
        case 11:
            return brain.xRegister! == 0
        default:
            return false
        }
    }
    
    // using control number (ccccc.tttii) from storage resister
    // apply increment (ii) to counter (ccccc)
    // return true, if target (ttt) met
    // store updated control number (uuuuu.tttii) in register
    func loop(isDSE: Bool, registerName: String) -> Bool {
        let controlNumber = brain.recallNumberFromStorageRegister(registerName)  // ccccc.tttii
        let counter = Int(controlNumber)  // ccccc
        let xyDecimals = controlNumber - Double(counter)  // 0.tttii
        let shifted = xyDecimals * 1000  // ttt.ii
        let target = Int(shifted)  // xxx
        let yDecimals = shifted - Double(target)  // 0.ii
        var increment = Int(round(yDecimals * 100))  // ii
        if increment == 0 { increment = 1 }  // can't be 0
        var newCounter: Int
        var isLoop: Bool
        if isDSE {
            newCounter = counter - increment
            isLoop = newCounter <= target
        } else {  // else ISG
            newCounter = counter + increment
            isLoop = newCounter > target
        }
        let updatedControlNumber = Double(newCounter) + xyDecimals
        brain.storeResultInRegister(registerName, result: updatedControlNumber)
        return isLoop
    }

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
        returnToLineNumbers = []
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
    
    // search forward through program from current line (wrap around end), until label found; return
    // false, if not found; leave program at line with label, or original location, if label not found
    func gotoLabel(_ label: String) -> Bool {  // label is button title (ex. "√x" for label A, or ".1" for label .1)
        var labelFound = false
        var labelCodeString = ""
        if label.first == "." {
            labelCodeString = "42,21, \(label)"  // ex. "42,21, .1" for Label .1
        } else {
            labelCodeString = "42,21,\(Program.keycodes[label]!)"  // ex. "42,21,11" for Label A, "42,21, 1" for Label 1
        }
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
    
    // MARK: - Create Program

    // Everything that says "prog if followed by..." is added to the instructions once the follow-up
    // keys are entered.  If another key is entered before the specified follow-up, the sequence is
    // cleared, and re-started with the new key.  Any key sequence not listed, is added to the
    // instructions, as is.
    
    // SST     = SST      non-prog (fwd step)
    // GTO     = GTO      prog if followed by 0-9, A-E, ".", I, CHS
    // GTO .   = GTO .    prog if followed by 0-9
    // GTO CHS = GTO CHS  non-prog if followed by nnn (goto nnn)
    // GSB     = GSB      prog if followed by 0-9, A-E, ".", I
    // GSB .   = GSB .    prog if followed by 0-9
    // ←       = ←        non-prog (delete instruction)
    
    // STO     = STO      prog if followed by 0-9, A-E, ".", (i), I
    // STO .   = STO .    prog if followed by 0-9
    // STO +   = STO +    prog if followed by 0-9, A-E, ".", (i), I
    // STO + . = STO + .  prog if followed by 0-9
    // STO –   = STO –    prog if followed by 0-9, A-E, ".", (i), I
    // STO – . = STO – .  prog if followed by 0-9
    // STO ×   = STO ×    prog if followed by 0-9, A-E, ".", (i), I
    // STO × . = STO × .  prog if followed by 0-9
    // STO ÷   = STO ÷    prog if followed by 0-9, A-E, ".", (i), I
    // STO ÷ . = STO ÷ .  prog if followed by 0-9
    
    // RCL (same as above)

    // f GTO   = HYP      prog if followed by SIN, COS, TAN
    // f RCL   = USER     non-prog (toggles user mode)
    // f COS   = (i)      non-prog (no action - ignore)
    // f R↓    = PRGM     non-prog (clear instructions)
    // f ←     = PREFIX   non-prog (no action - ignore)
    // f 5     = DSE      prog if followed by 0-9, ".", (i), I
    // f 6     = ISG      prog if followed by 0-9, ".", (i), I
    // f ÷     = SOLVE    prog if followed by 0-9, A-E, "."
    // f ÷ .   = SOLVE .  prog if followed by 0-9
    // f ×     = ∫xy      prog if followed by 0-9, A-E, "."
    // f × .   = ∫xy .    prog if followed by 0-9
    // f SST   = LBL      prog if followed by 0-9, A-E, "."
    // f SST . = LBL .    prog if followed by 0-9
    // f 7     = FIX      prog if followed by 0-9, I
    // f 8     = SCI      prog if followed by 0-9, I
    // f 9     = ENG      prog if followed by 0-9, I
    // f 4     = x≷       prog if followed by 0-9, A-E, (i), I
    // f 4 .   = x≷ .     prog if followed by 0-9
    // f 5     = DSE ?    prog if followed by 0-9, (i), I
    // f 6     = ISG ?    prog if followed by 0-9, (i), I
    
    // g GTO   = HYP1     prog if followed by SIN, COS, TAN
    // g RCL   = MEM      non-prog (shows memory layout?)
    // g SST   = BST      non-prog (back step)
    // g 4     = SF       prog if followed by 0-9, I
    // g 5     = CF       prog if followed by 0-9, I
    // g 6     = f?  ?    prog if followed by 0-9, I
    // g -     = TEST     prog if followed by 0-9

    // in program mode, CalculatorViewController sends all button labels directly to buildInstructionWith
    // (except for "program buttons"); buildInstructionWith accumulates labels in the form of key codes,
    // until a complete instruction is formed and returned; the complete instruction may have up to two
    // prefixes; buildInstructionWith returns nil while prefixes are received.
    
    // some program buttons manipulate the program (SST, BST, ←, GTO-CHS, ...) and are not added to the
    // instructions (return nil); others are added to the instructions (R/S, RTN, GTO, ...);
    
    // all digit, operation, stack manipulation, and prefix buttons are automatically sent here,
    // so they have to be handled here, if they are non-programmable

    func buildInstructionWith(_ buttonTitle: String) -> String? {
        // first check for cases like: GTO-f-A, STO-f-B, f-÷-f-C (SOLVE C), f-FIX-f-I...
        // and remove the extra "f": GTO-A, STO-B, f-4-C, f-FIX-I...
        switch buttonTitle {
        case "√x", "ex", "10x", "yx", "1/x", "COS", "TAN":
            // label A-E, (i), or I entered
            if let suffixes = Program.allowableSuffixes[prefix] {
                if suffixes.contains(buttonTitle) {
                    // remove "f" or "g" and add label, (i), or I (ex. GTO-f-label => GTO-label)
                    instructionCodes.removeLast()
                    // instruction complete
                    instructionCodes.append(Program.keycodes[buttonTitle]!)
                    return insertedInstruction
                }
            }
        default:
            break
        }
        // after removing trailing f above, if still have any-f or any-g, start over
        // with "f" or "g" (drop "any"), current buttonLabel added in next section
        if prefix.count > 1 && (prefix.last == "f" || prefix.last == "g") {
            prefix = String(prefix.last!)
            // start the program instruction over with "f" or "g"
            instructionCodes = [Program.keycodes[prefix]!]
        }

        switch buttonTitle {
        case "f", "g":
            // any time "f" of "g" is entered (except following GTO, GSB, f-4,...), the program instruction starts over;
            // if "f" or "g" follows GTO, GSB, f-4,..., add it for now, in case it's followed by a label (check above);
            // ie. GTO-f-A becomes GTO-A, f-4-f-A becomes f-4-A, g-4-f-I becomes g-4-I...
            switch prefix {
            case _ where specialPrefixes.contains(prefix):
                // compound prefix (GTOf, GSBf, f4f,...)
                prefix += buttonTitle
                instructionCodes.append(Program.keycodes[buttonTitle]!)
            default:
                // start the program instruction over with "f"
                prefix = buttonTitle
                instructionCodes = [Program.keycodes[buttonTitle]!]
            }
        case "GTO", "GSB", "STO", "RCL":  // pws: what about STO .1 or RCL .1 ?
            if prefix == "f" || prefix == "g" {
                if buttonTitle == "GTO" {
                    // compound prefix (HYP or HYP-1)
                    prefix += buttonTitle
                    instructionCodes.append(Program.keycodes[buttonTitle]!)
                } else if buttonTitle == "RCL" {
                    if prefix == "f" {
                        // USER (non-programable)
                        // pws: TBD toggle USER mode
                    } else {
                        // MEM (non-programmable)
                        // pws: TBD show memory layout?
                    }
                } else {
                    // instruction complete
                    instructionCodes.append(Program.keycodes[buttonTitle]!)
                    return insertedInstruction
                }
            } else if (prefix == "f4" || prefix == "f5" || prefix == "f6" ||
                       prefix == "f7" || prefix == "f8" || prefix == "f9") && buttonTitle == "GTO" {
                // non-programmable (f-FIX-GTO, f-SCI-GTO, f-ENG-GTO)
                prefix = ""
            } else {
                // start the program instruction over with the latest one
                prefix = buttonTitle
                instructionCodes = [Program.keycodes[buttonTitle]!]
            }
        case "SST":
            switch prefix {
            case "f":
                // compound prefix (LBL)
                prefix += buttonTitle
                instructionCodes.append(Program.keycodes[buttonTitle]!)
            case "g":
                // return previous line (BST)
                return backStep()  // non-programmable
            default:
                // return next line (SST)
                return forwardStep()  // non-programmable
            }
        case "√x", "ex", "10x", "yx", "1/x":
            if prefix == "f" {
                // f-label entered - use GSB-label, instead (per HP-15C)
                instructionCodes = [Program.keycodes["GSB"]!]
            } else if prefix == "f7" || prefix == "f8" || prefix == "f9" {
                // clear previous instructions
                instructionCodes = []
            } else if prefix == "g4" || prefix == "g5" || prefix == "g6" {
                // clear previous instructions
                instructionCodes = []
            }
            // instruction complete
            instructionCodes.append(Program.keycodes[buttonTitle]!)
            return insertedInstruction
        case "CHS":
            if prefix == "GTO" {  // non-programmable
                // compound prefix
                prefix += buttonTitle
                instructionCodes = []
                gotoLineNumberDigits = []
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonTitle]!)
                return insertedInstruction
            }
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            if prefix == "GTOCHS" {  // non-programmable
                // add buttonLabel to gotoLineNumber
                gotoLineNumberDigits.append(Int(buttonTitle)!)
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
            } else if prefix == "f" && (buttonTitle == "4" || buttonTitle == "5" || buttonTitle == "6" || buttonTitle == "7" || buttonTitle == "8" || buttonTitle == "9") {
                // compound prefix (x≷, DSE, ISG, FIX, SCI, or ENG)
                prefix += buttonTitle
                instructionCodes.append(Program.keycodes[buttonTitle]!)
            } else if prefix == "g" && (buttonTitle == "4" || buttonTitle == "5" || buttonTitle == "6") {
                // compound prefix (SF, CF, f?)
                prefix += buttonTitle
                instructionCodes.append(Program.keycodes[buttonTitle]!)
            } else if prefix.last == "." {
                // instruction complete (GTO .n, GSB .n, STO .n, STO + .n, RCL .n, RCL + .n, SOLVE .n, ∫xy .n, LBL . n, DSE .n, ISG .n))
                instructionCodes.append(Program.keycodes[buttonTitle]!)
                return insertedInstruction
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonTitle]!)
                return insertedInstruction
            }
        case ".":
            switch prefix {
            case "GTO", "GSB", "STO", "STO+", "STO–", "STO×", "STO÷", "RCL", "RCL+", "RCL–", "RCL×", "RCL÷", "f4", "f5", "f6", "f÷", "f×", "fSST":
                // compound prefix (GTO ., GSB ., ...)
                prefix += buttonTitle
                instructionCodes.append(Program.keycodes[buttonTitle]!)
            default:
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonTitle]!)
                return insertedInstruction
            }
        case "+", "–", "×", "÷":  // minus sign is an "EN DASH"
            if prefix == "STO" || prefix == "RCL" ||
                (prefix == "f" && (buttonTitle == "×" || buttonTitle == "÷")) ||
                (prefix == "g" && buttonTitle == "–") {
                // compound prefix
                prefix += buttonTitle
                instructionCodes.append(Program.keycodes[buttonTitle]!)
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonTitle]!)
                return insertedInstruction
            }
        case "SIN":
            if prefix == "f4" || prefix == "f5" || prefix == "f6" ||
                prefix == "f7" || prefix == "f8" || prefix == "f9" {
                // clear previous instructions
                instructionCodes = []
            } else if prefix == "g4" || prefix == "g5" || prefix == "g6" {
                // clear previous instructions
                instructionCodes = []
            }
            // instruction complete
            instructionCodes.append(Program.keycodes[buttonTitle]!)
            return insertedInstruction
        case "COS":
            if prefix == "f" {
                // (i) (non-programmable)
                prefix = ""  // ignored in program mode (show imaginary part of complex number in normal mode)
                return nil
            } else if prefix == "f7" || prefix == "f8" || prefix == "f9" {
                // clear previous instructions
                instructionCodes = []
            } else if prefix == "g4" || prefix == "g5" || prefix == "g6" {
                // clear previous instructions
                instructionCodes = []
            }
            // instruction complete
            instructionCodes.append(Program.keycodes[buttonTitle]!)
            return insertedInstruction
        case "R↓":
            if prefix == "f" {
                // CLEAR PRGM (non-programmable)
                prefix = ""
                clearProgram()
                return insertedInstruction  // returns line 000
            } else {
                // instruction complete
                instructionCodes.append(Program.keycodes[buttonTitle]!)
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
                instructionCodes.append(Program.keycodes[buttonTitle]!)
                return insertedInstruction
            default:
                // ex. PREFIX (non-programmable)
                prefix = ""
            }
        default:
            // instruction complete
            instructionCodes.append(Program.keycodes[buttonTitle]!)
            return insertedInstruction
        }
        return nil  // continue adding instructionCodes
    }

    // create and insert instruction
    // format:
    // 3 codes: "nnn-42,22,23" <=> f GTO SIN (commas get attached to prior digit in DisplayView)
    // 3 codes: "nnn-42, 7, 4" <=> f 7 4
    // 3 codes: "nnn-42,21,.1" <=> f LBL .1
    // 2 codes: "nnn- 43 24"   <=> g COS
    // 2 codes: "nnn-  44 1"   <=> STO 1
    // 2 codes: "nnn-  32 .2"  <=> GSB .2
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
    
    // note: don't call runFrom recursively, or is may spawn too many tasks
    func runFrom(label: String, completion: @escaping () -> Void) {
        if gotoLabel(label) {
            // label found
            runFromCurrentLine(completion: completion)
        } else {
            delegate?.setError(4)  // label not found
        }
    }
    
    // run instructions from current line, until one of the following is found:
    // - last instruction (go to line 0 and stop)
    // - R/S instruction found (go to next line and stop)
    // - GTO instruction found (go to GTO label and continue)
    // - GSB instruction found (go to GSB label and continue)
    // - RTN instruction found (return to line 0 or line after last GSB)
    // - PSE pause for 1.2 sec and continue (1.2 sec for each, if multiple PSE in-a-row)
    // - ignore any labels, and continue
    // notes:
    // - runFromCurrentLine may not be at a label when called (ex. if called after pause)
    // - if adding a new "else if" section, also add to runCurrentInstruction,
    //   since runFromCurrentLine isn't used for single-step mode (SST)
    func runFromCurrentLine(completion: @escaping () -> Void) {
        var isStopRunning = isAnyButtonPressed
        isProgramPaused = false
        while currentLineNumber > 0 && !isStopRunning {
            if isCurrentInstructionARunStop {
                // stop running - increment line number and quit running
                isStopRunning = isAnyButtonPressed
                _ = forwardStep()
                break  // exit while
            } else if let label = labelIfCurrentInstructionIsGoto {
                // goto label (if found) and continue running
                isStopRunning = isAnyButtonPressed
                if !gotoLabel(label) {
                    delegate?.setError(4)  // label not found
                    break  // exit while, if error
                }
            } else if let label = labelIfCurrentInstructionIsGoSub {
                // goto subroutine label and continue running, until return found, then return to instruction after go-sub
                isStopRunning = isAnyButtonPressed
                returnToLineNumbers.append((currentLineNumber + 1) % instructions.count)
                if !gotoLabel(label) {
                    delegate?.setError(4)  // label not found
                    break  // exit while, if error
                }
            } else if isCurrentInstructionAReturn {
                // go to previous subroutine call and continue running, or to start of program and stop
                isStopRunning = isAnyButtonPressed
                currentLineNumber = returnToLineNumbers.popLast() ?? 0
            } else if isCurrentInstructionAPause {
                // pause and continue, recursively
                isStopRunning = isAnyButtonPressed
                // show results on display, pause, show "running", pause, continue running
                DispatchQueue.main.async {
                    self.delegate?.isProgramRunning = false  // removes "running" from display
                    self.isProgramPaused = true
                }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Pause.time) { [unowned self] in
                    if !isAnyButtonPressed {
                        DispatchQueue.main.async {
                            self.delegate?.isProgramRunning = true  // show "running" when continuing after pause
                            self.isProgramPaused = false
                        }
                    }
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Pause.time) { [unowned self] in
                        _ = forwardStep()
                        runFromCurrentLine(completion: completion)
                    }
                }
                break  // stop and wait for pause to restart program
            } else {
                // run instruction
                semaphore.wait()  // throttle calls, or foreground may get blocked
                //---------------------
                runCurrentInstruction()
                //---------------------
                if brain.error == .none {
                    _ = forwardStep()  // increment currentLineNumber
                } else {
                    // error - stop running
                    return  // pws: should this be a break, like errors above?
                }
            }
        }
        completion()
    }

    // called from either runFromCurrentLine (looping through several instructions) or during
    // single-stepping (SST); handle labels, gotos, gosubs, and returns separately, otherwise
    // parse current instruction and "press" buttons to implement it
    func runCurrentInstruction() {
        if isCurrentInstructionALabel {
            // non-executable instruction - if user was entering digits, send display to stack
            DispatchQueue.main.sync {
                self.delegate?.prepStackForOperation()  // main queue, since it updates displayString
                self.semaphore.signal()
            }
        } else if let label = labelIfCurrentInstructionIsGoto {
            // goto label
            if gotoLabel(label) {
                // label found
                _ = backStep()  // back-step, since SST increments current line number
            } else {
                delegate?.setError(4)  // label not found
            }
            semaphore.signal()
        } else if let label = labelIfCurrentInstructionIsGoSub {
            // goto subroutine label
            returnToLineNumbers.append(currentLineNumber)
            if gotoLabel(label) {
                // label found
                _ = backStep()  // back-step, since SST increments current line number
            } else {
                delegate?.setError(4)  // label not found
            }
            semaphore.signal()
        } else if let testNumber = testNumberIfCurrentInstructionIsTest {
            // skip next line if test is false, else continue
            if !test(testNumber) { _ = forwardStep() }
            semaphore.signal()
        } else if let flagNumber = flagNumberIfCurrentInstructionIsFQM {  // F Question Mark (F?)
            // skip next line if flag is false, else continue
            if !delegate!.flags[flagNumber] { _ = forwardStep() }
            semaphore.signal()
        } else if let registerName = storageRegisterNameIfCurrentInstructionIsDSE {
            // skip next line if loop control is true, else continue
            if loop(isDSE: true, registerName: registerName) { _ = forwardStep() }
            semaphore.signal()
        } else if let registerName = storageRegisterNameIfCurrentInstructionIsISG {
            // skip next line if loop control is true, else continue
            if loop(isDSE: false, registerName: registerName) { _ = forwardStep() }
            semaphore.signal()
        } else if isCurrentInstructionAReturn {
            // go to previous subroutine call or start of program
            currentLineNumber = returnToLineNumbers.popLast() ?? 0
            semaphore.signal()
        } else {
            // executable instruction - run it
            let titles = currentInstructionTitles  // ex. ["f", "GTO", "SIN"]
            for title in titles {
                // run on main queue for button.currentTitle, button.tag, button.sendAction, and digitView.setNeedsDisplay
                DispatchQueue.main.sync {  // sync (wait for completion), so runFromCurrentLine doesn't get ahead of button presses
                    let button = self.delegate?.buttons.first(where: { $0.currentTitle == title })
                    self.delegate?.useSimButton = false  // don't play click sound
                    button?.tag = 1  // 1 indicates button "pressed" by program
                    //----------------------------------
                    button?.sendActions(for: .touchDown)
                    //----------------------------------
                    self.delegate?.useSimButton = true
                    button?.tag = 0
                    self.semaphore.signal()
                }
            }
        }
    }

    // MARK: - Utilities
    
    var currentInstruction: String {
        instructions[currentLineNumber]
    }
    
    // ex. "001-42,22,23" => "42,22,23"
    //     "001-42,21,.1" => "42,21,.1"
    func codeStringFromInstruction(_ instruction: String) -> String {
        String(instruction.suffix(from: codeStart))
    }
    
    // code string from current instruction
    // ex. "001-42,22,23" => "42,22,23"
    //     "001-42,21,.1" => "42,21,.1"
    var currentInstructionCodeString: String {
        codeStringFromInstruction(currentInstruction)
    }

    // key-codes in current instruction
    // ex. "001-42,22,23" => [42, 22, 23]
    //     "001-42,21,.1" => [42, 21, 48, 1]
    var currentInstructionCodes: [Int] {
        codesFrom(codeString: currentInstructionCodeString)
    }
    
    // button titles for current instruction
    // ex.    [42, 22, 23] => ["f", "GTO", "SIN"]
    //     [42, 21, 48, 1] => ["f", "SST", ".", "1"]
    var currentInstructionTitles: [String] {
        return titlesFrom(keyCodes: currentInstructionCodes)
    }
    
    // when running a program, labels are non-executable
    var isCurrentInstructionALabel: Bool {
        isLabel(codes: currentInstructionCodes)
    }

    // a label is a single instruction with one of these code sets:
    // [42, 21, 11-15] = "f LBL A-E"
    // [42, 21, 1] = "f LBL 0-9"
    // [42, 21, 48, 1] = "f LBL . 0-9"
    func isLabel(codes: [Int]) -> Bool {
        guard !codes.isEmpty else { return false }
        return codes[0] == 42 && codes[1] == 21 && (
            (codes.count == 3 && (codes[2] >= 0 && codes[2] <= 9) || (codes[2] >= 11 && codes[2] <= 15)) ||
            (codes.count == 4 && (codes[3] >= 0 && codes[3] <= 9))
        )
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
    
    // ex. GTO A  = [22, 11]    => "√x" (A)
    //     GTO 1  = [22, 1]     => " 1"
    //     GTO .1 = [22, 48, 1] => ".1"  note: HP-15C codes for this are [22, .1], but this app codes the dot separately
    //     GTO I  = [22, 25]    => TBD  pws
    var labelIfCurrentInstructionIsGoto: String? {
        if isGoto(codes: currentInstructionCodes) {
            var labelString = ""
            if currentInstructionCodes[1] == 48 {
                labelString = ".\(currentInstructionCodes[2])"
            } else {
                labelString = Program.buttonTitles[String(format: "%2d", currentInstructionCodes[1])]!
            }
            return labelString
        } else {
            return nil
        }
    }
    
    func isGoto(codes: [Int]) -> Bool {
        codes[0] == 22
    }
    
    // ex. GSB A  = [32, 11]    => "√x" (A)
    //     GSB 1  = [32, 1]     => " 1"
    //     GSB .1 = [32, 48, 1] => ".1"  note: HP-15C codes for this are [32, .1], but this app codes the dot separately
    var labelIfCurrentInstructionIsGoSub: String? {
        if isGoSub(codes: currentInstructionCodes) {
            var labelString = ""
            if currentInstructionCodes[1] == 48 {
                labelString = ".\(currentInstructionCodes[2])"
            } else {
                labelString = Program.buttonTitles[String(format: "%2d", currentInstructionCodes[1])]!
            }
            return labelString
        } else {
            return nil
        }
    }
    
    func isGoSub(codes: [Int]) -> Bool {
        codes[0] == 32
    }
    
    // ex. f DSE 1  = [42, 5, 1]     => " 1"
    //     f DSE .1 = [42, 5, 48, 1] => ".1"  note: HP-15C codes for this are [42, 5, .1], but this app codes the dot separately
    var storageRegisterNameIfCurrentInstructionIsDSE: String? {
        if currentInstructionCodes[0] == 42 && currentInstructionCodes[1] == 5 {
            return storageRegisterNameFromCodes(currentInstructionCodes)
        } else {
            return nil
        }
    }
    
    // ex. f ISG 1  = [42, 6, 1]     => " 1"
    //     f ISG .1 = [42, 6, 48, 1] => ".1"  note: HP-15C codes for this are [42, 5, .1], but this app codes the dot separately
    var storageRegisterNameIfCurrentInstructionIsISG: String? {
        if currentInstructionCodes[0] == 42 && currentInstructionCodes[1] == 6 {
            return storageRegisterNameFromCodes(currentInstructionCodes)
        } else {
            return nil
        }
    }
    
    func storageRegisterNameFromCodes(_ codes: [Int]) -> String? {
        var registerName = ""
        if codes[2] == 48 {
            registerName = ".\(codes[3])"
        } else {
            registerName = Program.buttonTitles[String(format: "%2d", codes[2])]!
        }
        return registerName
    }

    // program goes to next line if test is true, and skips to next line if test is false
    var testNumberIfCurrentInstructionIsTest: Int? {
        testNumberIfCodesAreTest(codes: currentInstructionCodes)
    }
    
    // ex. g x≤y    = [43, 10]    => 10 (assign x≤y to test 10)
    //     g x=0    = [43, 20]    => 11 (assign x=0 to test 11)
    //     g TEST 9 = [43, 30, 9] => 9
    //     g TEST n = [43, 30, n] => n
    func testNumberIfCodesAreTest(codes: [Int]) -> Int? {
        guard !codes.isEmpty else { return nil }
        if codes[0] == 43 {
            if codes.count == 2 {
                if codes[1] == 10 {
                    return 10
                } else if codes[1] == 20 {
                    return 11
                } else {
                    return nil
                }
            } else if codes.count == 3 && codes[1] == 30 && codes[2] >= 0 && codes[2] <= 9 {
                return codes[2]
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    // program goes to next line if flag is true, and skips to next line if flag is false
    var flagNumberIfCurrentInstructionIsFQM: Int? {
        flagNumberIfCodesAreFQM(codes: currentInstructionCodes)
    }
    
    // ex. g F? n   = [43, 6, n]  => n, where n = 0-7
    func flagNumberIfCodesAreFQM(codes: [Int]) -> Int? {
        guard !codes.isEmpty else { return nil }
        if codes.count == 3 && codes[0] == 43 && codes[1] == 6 && codes[2] >= 0 && codes[2] <= 7 {
            return codes[2]
        } else {
            return nil
        }
    }

    var isCurrentInstructionAPause: Bool {
        isPause(codes: currentInstructionCodes)
    }
    
    func isPause(codes: [Int]) -> Bool {
        codes == [42, 31]
    }
    
    // convert from code string to array of codes
    // ex. "42,22,23" => [42, 22, 23]
    //     "42, 7, 4" => [42, 7, 4]
    //    "42,21, .1" => [42, 21, 48, 1]
    //       " 43 24" => [43, 24]
    //       "  44 1" => [44, 1]
    //      "  32 .1" => [32, 48, 1]
    //       "    12" => [12]
    func codesFrom(codeString: String) -> [Int] {
        guard !codeString.isEmpty else { return [] }
        let delimiter = codeString.contains(",") ? "," : " "
        let modifiedCodeString = codeString.replacingOccurrences(of: " .", with: " 48\(delimiter)")
        let codesArray = modifiedCodeString.trimmingCharacters(in: .whitespaces).components(separatedBy: delimiter)
        return codesArray.map { Int($0.trimmingCharacters(in: .whitespaces))! }
    }
    
    // convert from array of codes to array of button labels
    // ex. [42, 22, 23] => ["f", "GTO", "SIN"]
    //       [42, 7, 4] => ["f", "7", "4"]
    //  [42, 21, 48, 1] => ["f", "SST", ".", "1"]
    //         [43, 24] => ["g", "COS"]
    //          [44, 1] => ["STO", "1"]
    //      [32, 48, 1] => ["GSB", ".", "1"]
    //             [12] => ["ex"]
    func titlesFrom(keyCodes: [Int]) -> [String] {
        keyCodes.map { Program.buttonTitles[String(format: "%2d", $0)]! }
    }

    // convert from array of instruction codes to code string
    // ex.    ["42", "22", "23"] => "42,22,23"
    //        ["42", " 7", " 4"] => "42, 7, 4"
    //  ["42", "21", "48", " 1"] => "42,21, .1"
    //              ["43", "24"] => " 43 24"
    //              ["44", " 1"] => "  44 1"
    //        ["32", "48", " 1"] => "  32 .1"
    //                    ["12"] => "    12"
    var codeString: String {
        var codes = ""
        switch instructionCodes.count {
        case 1:
            codes = "    " + instructionCodes[0]
        case 2:
            if instructionCodes[1].first == " " {
                // single digit second code, ex. ["44"," 1"] => "  44 1"
                codes = "  " + instructionCodes[0] + instructionCodes[1]
            } else {
                // two-digit second code (ex. ["43","24"])
                codes = " " + instructionCodes[0] + " " + instructionCodes[1]
            }
        case 3:
            if instructionCodes[1] == "48" {
                // GSB to decimal label, ex. ["32", "48", " 1"] => "  32 .1"
                codes = "  " + instructionCodes[0] + " ." + String(instructionCodes[2].last!)
            } else {
                // all other three-code instructions, ex. ["42", "22", "23"] => "42,22,23"
                codes = instructionCodes[0] + "," + instructionCodes[1] + "," + instructionCodes[2]
            }
        case 4:
            // decimal label, ex. ["42", "21", "48", " 1"] => "42,21,.1"
            codes = instructionCodes[0] + "," + instructionCodes[1] + ", ." + String(instructionCodes[3].last!)
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
