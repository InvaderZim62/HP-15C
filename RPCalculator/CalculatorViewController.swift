//
//  CalculatorViewController.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/4/21.
//
//  HP-15C Owner's Handbook: https://www.hp.com/ctg/Manual/c03030589.pdf
//
//  click.wav obtained from: https://freesound.org/people/kwahmah_02/sounds/256116
//  file is in the public domain (CC0 1.0 Universal)
//
//  I used Action "Touch Down" for all buttons, by doing the following...
//  - create an IBAction by control-dragging the first button into the code, selecting
//    Touch Down (below the Type drop-down field), rather then the default Touch Up Inside
//  - right-click (two-finger-touch) the remaining buttons in Interface Builder to bring
//    up the connections menu
//  - control-drag from the little circle to the right of Touch Down (under Send Events)
//    to the existing IBAction
//
//  I made the "hp" and "15C" labels scale with the HP Logo Container View in Interface Builder
//  by using the following settings...
//     Font size: (largest desired scalable size)
//     Lines: 0
//     Alignment: Center
//     Baseline: Align Centers
//     Autoshrink: Minimum Font Size
//         number: (smallest desired scalable size)
//
//  HP-15C tips...
//  - labels A-E, 0-9, .0-.9
//    - in program mode, enter labels using f-LBL A-E, f-LBL 0-9, or f-LBL .0-.9
//    - run a program from labels  A-E  by entering f A-E or GSB A-E
//    - run a program from labels  0-9  by entering GSB 0-9 (f-LBL 0-9 doesn't work)
//    - run a program from labels .0-.9 by entering GSB .0-.9 (f-LBL .0-.9 doesn't work)
//  - goto line number
//    - in run mode or program mode, change the current line number using GTO CHS nnn (three-digit line number)
//    - in run mode, f-CLEAR-PRGM or g-RTN goes to line 0
//    - in program mode, f-CLEAR-PRGM deletes the program
//  - single-step through a program
//    - in run mode, holding down SST displays current instruction; releasing executes instruction,
//      and increments line number; if instruction is RTN, program cycles back to line 1
//    - in run mode, holding down g-BST displays previous instruction; releasing does not execute instruction
//    - in program mode, SST and g-BST increments or decrements the current line number (without executing)
//  - complex mode
//    - to enter a complex number, enter <real part>-ENTER, <imaginary part>-f-I ("C" annunciator will show)
//    - to see the imaginary part of a complex number, press and hold f-(i)
//    - to exit complex mode, select g-CF-8
//  - matrices
//    - matrices are reference using 1-based indices
//    - dimension matrix A to be 2 rows x 3 cols (filled with zeros): 2 ENTER 3 f DIM A
//    - show dimensions of matrix A: RCL MATRIX A (displays: "A     2  3")
//    - store an 8 in matrix A, row 3, col 4: 3 STO 0 (row), 4 STO 1 (col), 8 STO A
//    - recall value in matrix A, row 3, col 4: 3 STO 0 (row), 4 STO 1 (col), RCL A
//    - store all values in matrix A, while auto-sequencing columns and rows:
//      - f MATRIX 1    start with 1 in storage register 0 and 1
//      - f USER        enable auto-sequence
//      - 1 STO A       store 1 in row 1, col 1, then increment value in register 1 (col)
//      - 2 STO A       store 1 in row 1, col 2, then increment value in register 1 (col)
//      - ...           when col = last col, go to next row; return to start after last element
//    - recall all values in matrix A, while auto-sequencing columns and rows:
//      - f MATRIX 1    start with 1 in storage register 0 and 1
//      - f USER        enable auto-sequence
//      - RCL A         recall row 1, col 1, then increment value in register 1 (col)
//      - RCL A         recall row 1, col 2, then increment value in register 1 (col)
//      - ...           when col = last col, go to next row; return to start after last element
//
//  Useful memory functions:
//    - overwrite xRegister with display:     if userIsEnteringDigits { endDisplayEntry() }
//    - display xRegister formatted           updateDisplayString()
//    - push display onto stack:              if userIsEnteringDigits { brain.pushOperand(displayStringNumber) }
//    - move display to memory stack before
//      performing an operations:             prepStackForOperation()
//
//  Not implemented:
//  - statistics function
//  - numerical integration
//  - matrix inversion greater than 4x4
//  - matrix LU decomposition
//  - complex number matrices
//
//  To do...
//  - implement RND key (round mantissa to displayed digits)
//  - some numbers don't allow entering exponent EEX (ex. 12345678 EEX doesn't, 1234567 EEX does, 1.2345678 EEX does)
//  - p.59 rounding displayed scientific numbers not implemented
//  - p.61 swapping "." and "," in displaying number is not implemented
//  - make display blink when +/-overflow (9.999999 99) ex. 1 EEX 99 Enter 10 x
//  - following overflow on real HP-15C, pressing "←" key causes blinking to stop, but leaves 9.999999 99 in display (xRegister)
//  - p61 implement underflow (displays 0.0)
//  - HP-15C displays Error 5, if there are more than 7 nested subroutine calls (GSB) in a program
//  - p.108 indirect branching
//  - p.109 to label
//  - p.109 to line number
//  - need to handle these cases:
//    - RCL f I     => RCL I (ie. remember RCL after entering f)
//    - RCL I       => RCL I
//    - RCL f FIX 5 => FIX 5 (ie. forget RCL after entering f)
//    maybe create prefix = RCL_f; if next button isn't (i), I, MATRIX, or DIM, drop the pre-f part;
//    also have var prefix's didSet set fLabel.alpha = 1, if prefix.last = "f" (small letter f)
//  - show matrix row,col when storing and recalling matrix elements

import UIKit
import AVFoundation  // needed for AVAudioPlayer

struct Pause {
    static let time = 1.2
}

enum Prefix: String {
    case f  // function above button (orange)
    case g  // function below button (blue)
    case LBL  // ex. f LBL A (add label to program), or LBL A (run program from label A)
    case LBL_DOT  // ex. f LBL . 2 (0 - 9, .0 - .9 are valid labels)
    case GSB  // ex. GSB B (goto label B and run until RTN)
    case GSB_DOT  // ex. GSB . 0 (0 - 9, .0 - .9 are valid labels)
    case GTO  // ex. GTO 5 (goto label 5)
    case GTO_DOT  // ex. GTO . 5 (goto label .5)
    case GTO_CHS  // ex. GTO CHS nnn (go to line nnn) - needs three digits
    case MATRIX = "M"  // ex. f MATRIX 1 (store beginning row and column numbers in registers 0 and 1, respectively)
    case STO_MATRIX  // ex. STO MATRIX B (copy displayed matrix to matrix B)
    case RCL_MATRIX  // ex. RCL MATRIX A (display dimensions of matrix A)
    case XSWAP  // ex. XSWAP 4 (swap X register with register 4)
    case XSWAP_DOT  // ex. XSWAP . 4 (swap X register with register .4)
    case SOLVE  // ex. f SOLVE A (solve for roots of equation starting at label A)
    case SOLVE_DOT  // ex. f SOLVE . 2 (solve for roots of equation starting at label .2)
    case DSE  // ex. DSE 6 (see p.109 User's Handbook - decrement register 6 and skip next line, if <= test value)
    case DSE_DOT  // ex. DSE . 6 (decrement register .6 and skip next line, if <= test value)
    case ISG  // ex. DSE 7 (see p.109 User's Handbook - increment register 7 and skip next line, if > test value)
    case ISG_DOT  // ex. ISG . 7 (increment register .7 and skip next line, if > test value)
    case FIX  // ex. f FIX 4 (format numbers in fixed-point with 4 decimal places)
    case SCI
    case ENG
    case HYP = "H"  // ex. f HYP SIN (hyperbolic sine)
    case HYP1 = "h"  // ex. g HYP1 SIN (inverse hyperbolic sine)
    case DIM  // ex. f DIM A (dimension matrix A to y rows and x cols)
    case RCL_DIM  // ex. RCL DIM A (place number of rows of matrix A in Y register and number of columns in X register)
    case RESULT  // ex. f RESULT B (store results of matrix operation in matrix B)
    case SF  // ex. g SF 8 (set flag 8 - enable complex mode)
    case CF  // ex. g CF 8 (clear flag 8 - disable complex mode)
    case FQM  // ex. g F? 2 (test if flag 2 is set)
    case TEST  // ex. g TEST 5 (execute next program instruction if xRegister = yRegister)
    case STO  // ex. STO 0 (store display to register 0)
    case STO_DOT  // ex. STO . 0 (.0 - .9 are valid storage registers)
    case STO_ADD  // ex. 4 STO + 1 (ADD 4 to register 1)
    case STO_ADD_DOT  // ex. 4 STO + . 1 (ADD 4 to register .1)
    case STO_SUB
    case STO_SUB_DOT
    case STO_MUL
    case STO_MUL_DOT
    case STO_DIV
    case STO_DIV_DOT
    case RCL  // ex. RCL 0 (recall register 0 to display)
    case RCL_DOT  // ex. RCL . 0 (.0 - .9 are valid storage registers)
    case RCL_ADD  // ex. RCL + 1 (ADD register 1 to display)
    case RCL_ADD_DOT  // ex. RCL + . 1 (ADD register .1 to display)
    case RCL_SUB
    case RCL_SUB_DOT
    case RCL_MUL
    case RCL_MUL_DOT
    case RCL_DIV
    case RCL_DIV_DOT
}

enum TrigUnits: String, Codable {
    case DEG = "D"  // default
    case RAD = "R"
    case GRAD = "G"  // 100 gradians = 90 degrees
}

class CalculatorViewController: UIViewController, ProgramDelegate, SolveDelegate {
    
    var brain = Brain()
    var program = Program()
    var solve = Solve()
    var clickSoundPlayer: AVAudioPlayer?
    var displayString = "" {
        didSet {
            if !isProgramRunning {
                displayLabel.text = displayString  // used in UI tests
                displayView.displayString = displayString
            }
        }
    }
    var displayFormat = DisplayFormat.fixed(4)
    var displayLabels = [UILabel]()
    var savedDisplayLabelAlphas = [CGFloat]()  // save for turning calculator Off/On
    var saveDisplayString = ""
    var saveMatrix: Matrix?  // used for displaying imaginary part of matrix (ie. 0)
    var calculatorIsOn = true
    var liftStack = true  // false between pressing enter and an operation (determines overwriting or pushing xRegister)
    var userIsEnteringDigits = false
    var userIsEnteringExponent = false  // userIsEnteringExponent and userIsEnteringDigits can be true at the same time
    var buttonCoverViews = [UIButton: ButtonCoverView]()  // overlays buttons to provide text above and inside buttons
    var seed = 0  // HP-15C initial random number seed is zero
    var lastRandomNumberGenerated = 0.0
    var showMatrixElementTimer = Timer()
    var isGettingDefaults = false
    var useSimButton = true  // true: call simulatePressingButton to play click sound; set false in program before issuing button action
    var gotoLineNumberDigits = [Int]()
    var flags = [Bool](repeating: false, count: 8)
    
    // displayString is scientific, if 11 digits and ends in "-nn" or " nn"
    var isDisplayStringScientific: Bool {
        let digits = displayString.map { $0 }
        let length = (digits[0] == "-" || digits[0] == " ") ? 12 : 11
        if displayString.count == length {
            let thirdToLastDigit = digits[length - 3]
            return (thirdToLastDigit == " " || thirdToLastDigit == "-") && digits[length - 2] != " "
        } else {
            return false
        }
    }

    var displayStringNumber: Double {
        if isDisplayStringScientific {
            // convert "1.2345    01" to "1.2345e+01", before trying to convert to number
            var tempDisplayString = displayString
            let exponent2 = String(tempDisplayString.removeLast())
            let exponent1 = String(tempDisplayString.removeLast())
            var sign = String(tempDisplayString.removeLast())
            if sign == " " { sign = "+" }
            return Double(tempDisplayString.replacingOccurrences(of: " ", with: "") + "e" + sign + exponent1 + exponent2)!
        } else {
            return Double(displayString)!
        }
    }
    
    var displayStringExponent: String {
        if isDisplayStringScientific {
            return String(displayString.suffix(3))
        } else {
            return " 00"
        }
    }

    var decimalWasAlreadyEntered: Bool {
        return displayString.contains(".")
    }
    
    var displayLabelAlphas: [CGFloat] {
        return displayLabels.map { $0.alpha }
    }
    
    var prefix: Prefix? {
        didSet {
            fLabel.alpha = 0  // use alpha, instead of isHidden, to maintain stackView layout
            gLabel.alpha = 0
            switch prefix {
            case .f:
                fLabel.alpha = 1  // show "f" on display
            case .g:
                gLabel.alpha = 1  // show "g" on display
            default:
                break  // don't show "f" or "g" on display
            }
        }
    }
    
    var trigUnits = TrigUnits.DEG {
        didSet {
            brain.trigUnits = trigUnits
            switch trigUnits {
            case .DEG:
                gradLabel.alpha = 0  // no display label for DEG
            case .RAD:
                gradLabel.alpha = 1
                gradLabel.text = "RAD"
            case .GRAD:
                gradLabel.alpha = 1
                gradLabel.text = "GRAD"
            }
            saveDefaults()
        }
    }
    
    var isComplexMode = false {  // note: use g-4 (SF) 8 to enable complex mode and g-5 (CF) 8 to disable complex mode
        didSet {
            brain.isComplexMode = isComplexMode
            cLabel.alpha = isComplexMode ? 1 : 0
            saveDefaults()
            brain.printMemory()
        }
    }
    
    var isProgramMode = false {
        didSet {
            prgmLabel.alpha = isProgramMode ? 1 : 0
            if !oldValue && isProgramMode {
                // toggled on
                program.enterProgramMode()
                saveDisplayString = displayString
                displayString = program.currentInstruction
            } else if oldValue && !isProgramMode {
                // toggled off
                displayString = saveDisplayString
            }
        }
    }
    
    var isProgramRunning = false {
        didSet {
            if isProgramRunning {
                displayView.displayString = " Running"  // send directly to displayView, else displayStringNumber fails
            } else {
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                updateDisplayString()
            }
        }
    }

    var isUserMode = false {
        didSet{
            userLabel.alpha = isUserMode ? 1 : 0
        }
    }
    
    // dictionary of button labels going from left to right, top to bottom
    // dictionary key is the primary button label (must agree with storyboard)
    var buttonText = [  // [nText: (fText, gText)]  ie. normal text, f-prefix text, g-prefix text
        "√x": ("A", "x²"),  // enter √ using option v
        "ex": ("B", "LN"),
        "10x": ("C", "LOG"),  // superscripting 10^x occurs in superscriptLastNCharactersOf, below
        "yx": ("D", "%"),
        "1/x": ("E", "𝝙%"),
        "CHS": ("MATRIX", "ABS"),
        "7": ("FIX", "DEG"),
        "8": ("SCI", "RAD"),
        "9": ("ENG", "GRD"),
        "÷": ("SOLVE", "x≤y"),  // enter ÷ using option /, enter ≤ using option ,
        "SST": ("LBL", "BST"),
        "GTO": ("HYP", "HYP-1"),
        "SIN": ("DIM", "SIN-1"),
        "COS": ("(i)", "COS-1"),
        "TAN": ("I", "TAN-1"),
        "EEX": ("RESULT", "π"),  // enter pi using option p
        "4": ("x≷", "SF"),
        "5": ("DSE", "CF"),
        "6": ("ISG", "F?"),
        "×": ("∫xy", "x=0"),  // enter ∫ using option b
        "R/S": ("PSE", "P/R"),
        "GSB": ("∑", "RTN"),  // enter ∑ using option w
        "R↓": ("PRGM", "R↑"),
        "x≷y": ("REG", "RND"),
        "←": ("PREFIX", "CL x"),
        "1": ("→R", "→P"),
        "2": ("→H.MS", "→H"),
        "3": ("→RAD", "→DEG"),
        "–": ("Re≷Im", "TEST"),  // minus sign is an "EN DASH" (U+2013)
        "STO": ("FRAC", "INT"),
        "RCL": ("USER", "MEM"),
        "0": ("x!", "x\u{0305}"),  // \u{0305} puts - above x
        "·": ("y\u{0302},r", "s"),  // \u{0302} puts ^ above y
        "Σ+": ("L.R.", "Σ-"),
        "+": ("Py,x", "Cy,x"),
        "E\nN\nT\nE\nR": ("RAN #", "LST x")  // ENTER (written vertically)
    ]

    @IBOutlet weak var displayView: DisplayView!
    @IBOutlet var buttons: [UIButton]!  // all buttons, except ON
    @IBOutlet weak var userLabel: UILabel!  // next 8 labels are in displayView
    @IBOutlet weak var fLabel: UILabel!
    @IBOutlet weak var gLabel: UILabel!
    @IBOutlet weak var beginLabel: UILabel!
    @IBOutlet weak var gradLabel: UILabel!
    @IBOutlet weak var dmyLabel: UILabel!
    @IBOutlet weak var cLabel: UILabel!
    @IBOutlet weak var prgmLabel: UILabel!
    @IBOutlet weak var logoCircleView: UIView!  // used to make view round in viewWillAppear
    @IBOutlet weak var calculatorView: CalculatorView!  // used to draw bracket around CLEAR label
    @IBOutlet weak var clearLabel: UILabel!  // used to anchor line drawing in calculatorView
    @IBOutlet weak var displayLabel: UILabel!  // for RPCalculatorUITests
    
    // MARK: - Start of code
    
    override func viewDidLoad() {
        super.viewDidLoad()
        displayLabels = [userLabel, fLabel, gLabel, beginLabel, gradLabel, dmyLabel, cLabel, prgmLabel]
        hideDisplayLabels()
        calculatorView.clearLabel = clearLabel
        setupClickSoundPlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        displayView.numberOfDigits = 11  // one digit for sign
        getDefaults()  // call in viewWillAppear, so displayString can set displayView.displayString after bounds are set
        program.delegate = self  // must be called after getting defaults (overwrites program)
        program.brain = brain
        solve.delegate = self
        solve.program = program
        solve.brain = brain
        prepStackForOperation()  // HP-15C completes number entry, if power is cycled
        brain.printMemory()
        logoCircleView.layer.masksToBounds = true
        logoCircleView.layer.cornerRadius = logoCircleView.bounds.width / 2  // make it circular
        createButtonCovers()  // pws: this will create duplicate buttonCoverViews, if this app ever returns from a segue
    }

    private func saveDefaults() {
        if !isGettingDefaults && !isProgramRunning {  // several variables save defaults in their didSet handlers; don't save everything else, while getting defaults
            let defaults = UserDefaults.standard
            if let data = try? JSONEncoder().encode(displayFormat) {
                defaults.set(data, forKey: "displayFormat")
            }
            defaults.set(displayString, forKey: "displayString")
            defaults.set(gradLabel.text, forKey: "gradLabelText")
            defaults.setValue(displayLabelAlphas, forKey: "displayLabelAlphas")
            if let data = try? JSONEncoder().encode(brain) {
                defaults.set(data, forKey: "brain")  // note: variables added to brain must also be added to Brain.init and .encode
            }
            defaults.set(isComplexMode, forKey: "isComplexMode")
            defaults.set(isUserMode, forKey: "isUserMode")
            defaults.set(liftStack, forKey: "liftStack")
            defaults.set(seed, forKey: "seed")
            defaults.set(lastRandomNumberGenerated, forKey: "lastRandomNumberGenerated")
            defaults.set(flags, forKey: "flags")
            saveProgram()
        }
    }

    // save program by itself when displayString is a program instruction, else displayStringNumber fails
    private func saveProgram() {
        if !isGettingDefaults {
            let defaults = UserDefaults.standard
            if let data = try? JSONEncoder().encode(program) {
                defaults.set(data, forKey: "program")  // note: variables added to program must also be added to Program.init and .encode
            }
        }
    }
    
    private func getDefaults() {
        isGettingDefaults = true
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "displayFormat") {
            displayFormat = try! JSONDecoder().decode(DisplayFormat.self, from: data)
        }
        displayString = defaults.string(forKey: "displayString") ?? String(format: displayFormat.string, 0.0)
        gradLabel.text = defaults.string(forKey: "gradLabelText") ?? gradLabel.text
        savedDisplayLabelAlphas = defaults.array(forKey: "displayLabelAlphas") as? [CGFloat] ?? displayLabelAlphas
        restoreDisplayLabels()
        prefix = nil  // prefix is lost after re-start
        isProgramMode = false  // don't re-start in program mode
        if let data = defaults.data(forKey: "brain") {
            brain = try! JSONDecoder().decode(Brain.self, from: data)
        }
        isComplexMode = defaults.bool(forKey: "isComplexMode")  // must get after brain, so isComplexMode.oldValue is correct
        isUserMode = defaults.bool(forKey: "isUserMode")
        liftStack = defaults.bool(forKey: "liftStack")
        seed = defaults.integer(forKey: "seed")
        lastRandomNumberGenerated = defaults.double(forKey: "lastRandomNumberGenerated")
        flags = defaults.array(forKey: "flags") as? [Bool] ?? [Bool](repeating: false, count: 8)
        if let data = defaults.data(forKey: "program") {
            program = try! JSONDecoder().decode(Program.self, from: data)
        }
        isGettingDefaults = false
    }
    
    // display labels: USER  f  g  BEGIN  GRAD  D.MY  C  PRGM
    private func hideDisplayLabels() {
        savedDisplayLabelAlphas = displayLabelAlphas  // save current setting for unhiding
        displayLabels.forEach { $0.alpha = 0 }  // use alpha, instead of isHidden, to maintain stackView layout
    }
    
    private func restoreDisplayLabels() {
        displayLabels.enumerated().forEach { displayLabels[$0.offset].alpha = savedDisplayLabelAlphas[$0.offset] }
    }

    // create all text for the buttons using ButtonCoverViews, placed over button locations from Autolayout
    private func createButtonCovers() {
        for button in buttons {
            if let nText = button.currentTitle, let (fText, gText) = buttonText[nText] {
                createCoverForButton(button, fText: fText, nText: nText, gText: gText)
            }
        }
    }
    
    private func createCoverForButton(_ button: UIButton, fText: String, nText: String, gText: String) {
        button.setTitleColor(.clear, for: .normal)
        let buttonCoverView = ButtonCoverView(buttonFrame: button.frame)
        buttonCoverView.orangeLabel.text = fText
        buttonCoverView.whiteLabel.text = nText
        buttonCoverView.blueLabel.text = gText
        
        // handle special button labels
        switch nText {
        case "E\nN\nT\nE\nR":
            // vertical text
            buttonCoverView.whiteLabel.numberOfLines = 0
            buttonCoverView.whiteLabel.font = buttonCoverView.whiteLabel.font.withSize(14)
        case "ex", "10x", "yx":
            // superscript x
            buttonCoverView.whiteLabel.attributedText = superscriptLastNCharactersOf(nText, n: 1, font: buttonCoverView.whiteLabel.font)
        case "GTO", "SIN", "COS", "TAN":  // gText: HYP-1, SIN-1, COS-1, TAN-1
            // superscript -1
            buttonCoverView.blueLabel.attributedText = superscriptLastNCharactersOf(gText, n: 2, font: buttonCoverView.blueLabel.font)
        case "÷", "×", "–", "+":
            buttonCoverView.whiteLabel.font = buttonCoverView.whiteLabel.font.withSize(22)  // default size 17 (set in ButtonCoverView)
        case "·":
            buttonCoverView.whiteLabel.font = buttonCoverView.whiteLabel.font.withSize(30)  // default size 17
        case "√x", "EEX":  // gText: x², π
            buttonCoverView.blueLabel.font = buttonCoverView.blueLabel.font.withSize(15)  // default size 12
        default:
            break
        }
        button.superview?.addSubview(buttonCoverView)
        buttonCoverViews[button] = buttonCoverView
    }
    
    private func superscriptLastNCharactersOf(_ string: String, n: Int, font: UIFont) -> NSMutableAttributedString {
        let regularFontSize = font.pointSize
        let regularFont = font.withSize(regularFontSize)
        let superscriptFont = font.withSize(regularFontSize - 2)
        let attributedString = NSMutableAttributedString(string: string, attributes: [.font: regularFont])
        attributedString.setAttributes([.font: superscriptFont, .baselineOffset: 4], range: NSRange(location: string.count - n, length: n))
        return attributedString
    }
    
    // used for RCL MATRIX n and pi
    func prepStackForRecalledValue(_ value: Stackable) {
        if userIsEnteringDigits {
            if liftStack {
                brain.pushOperand(displayStringNumber)
            } else {
                endDisplayEntry()
            }
            brain.pushOperand(value)
        } else {
            if liftStack {
                brain.pushOperand(value)
            } else {
                brain.xRegister = value
            }
        }
        updateDisplayString()
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        liftStack = true
    }

    // move display to memory stack before performing an operations (ex. +, -, x,
    // ÷, sin, cos,...); if user entering digits, behavior depends on liftStack
    func prepStackForOperation() {
        if userIsEnteringDigits {
            if liftStack {
                // operation doesn't follow enter; ex. pi 3 -, or 4 sqrt 3 x
                brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                brain.printMemory()
            } else {
                // operation follows enter or "←"; ex. 1 enter 2 +
                endDisplayEntry()  // overwrite xRegister with display
            }
        }  // else complete number is already in xRegister; ex. pi pi +
        updateDisplayString()
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        liftStack = true
    }
    
    // overwrite xRegister with display
    private func endDisplayEntry() {
        brain.xRegister = displayStringNumber
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        brain.printMemory()
    }
    
    // set display string to xRegister using current format (switch to scientific notation, if fixed format won't fit)
    func updateDisplayString() {
        switch brain.error {
        case .code(let number):
            displayString = number < 10 ? "  Error  \(number)" :  "  Error \(number)"
            return
        case .overflow:
            displayString = "9.999999 99"
            return
        case .underflow:
            displayString = "-9.999999 99"
            return
        default:  // .invalidKeySequence, .none
            break
        }
        //--------------------------------------
        let xRegister = brain.xRegister!
        //--------------------------------------
        if let numericResult = xRegister as? Double {
            var potentialDisplayString = String(format: displayFormat.string, numericResult)
            if displayFormat.decimals == 0 {
                // HP-15C includes decimal point for FIX 0 and SCI 0
                // format specifiers %.0f and %.0e remove decimal (ie. returns 123 instead of 123., and 1e+02 instead of 1.e+02)
                if case .fixed = displayFormat {
                    potentialDisplayString += "."
                } else if let eIndex = potentialDisplayString.range(of: "e")?.lowerBound {
                    potentialDisplayString.insert(".", at: eIndex)  // add decimal to left of "e"
                }
            }
            
            // for engineering notation, adjust mantissa so that exponent is a factor of 3
            if case .engineering(let additionalDigits) = displayFormat {
                let components = potentialDisplayString.components(separatedBy: "e")
                var mantissa = Double(components[0])!
                var exponent = Int(components[1])!
                while abs(exponent) % 3 > 0 {
                    mantissa *= 10
                    exponent -= 1
                }
                let digitsLeftOfDecimal = String(Int(mantissa)).count
                let mantissaLength = max(additionalDigits + (potentialDisplayString.first == "-" ? 1 : 0) + 2, digitsLeftOfDecimal + 1)
                let mantissaString = String(mantissa).padding(toLength: mantissaLength, withPad: "0", startingAt: 0)
                potentialDisplayString = mantissaString + String(format: "e%+03d", exponent)  // 2-digit exponent, including sign
            }
            var digitsLeftOfDecimal = potentialDisplayString.components(separatedBy: ".")[0].count
            if potentialDisplayString.first != "-" {
                digitsLeftOfDecimal += 1  // leave space in front of positive numbers
            }
            let displayConvertedBackToNumber = Double(potentialDisplayString)
            if case .fixed(let decimalPlaces) = displayFormat {
                // fixed format
                if digitsLeftOfDecimal > displayView.numberOfDigits {
                    // doesn't fit, temporarily switch to scientific notation
                    displayString = String(format: DisplayFormat.scientific(decimalPlaces).string, numericResult)
                } else if displayConvertedBackToNumber == 0 && numericResult != 0 {
                    // rounds to zero, temporarily switch to scientific notation
                    displayString = String(format: DisplayFormat.scientific(decimalPlaces).string, numericResult)
                } else {
                    // all good
                    displayString = potentialDisplayString
                }
            } else {
                // scientific or engineering format
                displayString = potentialDisplayString
            }
        } else if let matrixResult = xRegister as? Matrix {
            displayString = matrixResult.descriptor
        }
        saveDefaults()
    }
    
    private func invalidKeySequenceEntered() {
        brain.error = .badKeySequence
        prefix = nil
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        displayString = "  Error  0"  // real HP-15C seems to just ignore most invalid sequences
    }
    
    func setError(_ number: Int) {
        brain.error = .code(number)
        prefix = nil
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        updateDisplayString()
    }
    
    private func restoreFromError() -> Bool {
        if brain.error == .none {
            return false
        } else {
            brain.error = .none
            if isProgramMode {
                displayString = program.currentInstruction
            } else {
                updateDisplayString()
            }
            return true
        }
    }
    
    private func sendToProgram(_ buttonName: String) {
        if let instruction = program.buildInstructionWith(buttonName) {
            displayString = instruction
            saveProgram()
        }
    }
    
    // MARK: - Button actions
    
    @IBAction func aToEButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        handleUserMode()
        
        switch prefix {
        case .none, .g:
            performOperationFor(buttonName)
        case .f, .GSB:
            prefix = nil  // clear f-annunciator before running program
            runProgramFrom(label: buttonName)
        case .LBL:
            // LBL A-E - ignore in run mode
            break
        case .SOLVE:
            solveFrom(label: buttonName)
        case .GTO:
            if !program.gotoLabel(buttonName) {
                setError(4)
            }
        case .DIM:
            // DIM A-E - create matrix with dimensions in X and Y registers (Y rows, X cols)
            if userIsEnteringDigits { endDisplayEntry() }
            updateDisplayString()
            let matrix = brain.matrices[Matrix.names[buttonName]!]!
            if let rows = brain.yRegister as? Double, let cols = brain.xRegister! as? Double {
                matrix.setDimensions(rows: Int(rows), cols: Int(cols))
                print(matrix)
            } else {
                setError(1)  // can't use matrix as a dimension
            }
        case .RCL_DIM:
            // RCL DIM A-E - store number of rows in Y register and columns in X register, for matrix A-E
            if userIsEnteringDigits { endDisplayEntry() }
            let matrix = brain.matrices[Matrix.names[buttonName]!]!
            brain.pushOperand(Double(matrix.rows))
            brain.pushOperand(Double(matrix.rows))  // push rows into X and Y registers
            displayString = String(matrix.cols)
            endDisplayEntry()  // overwrite X register with cols
            updateDisplayString()
        case .STO_MATRIX:
            // STO MATRIX A-E - copy displayed matrix to matrix A-E, or store displayed number to all elements of matrix A-E
            if let matrix = brain.xRegister as? Matrix {
                let name = Matrix.names[buttonName]!
                let matrixCopy = matrix.copy()
                matrixCopy.name = name
                brain.matrices[name]! = matrixCopy
            } else if let number = brain.xRegister as? Double {
                if userIsEnteringDigits { endDisplayEntry() }
                updateDisplayString()
                let name = Matrix.names[buttonName]!
                brain.matrices[name]?.storeValue(number)  // store number to all elements of matrix
            }
        case .RCL_MATRIX:
            // RCL MATRIX A-E - display dimensions of matrix A-E
            let matrix = brain.matrices[Matrix.names[buttonName]!]!
            prepStackForRecalledValue(matrix)
            brain.printMemory()
            print(matrix)
        case .RESULT:
            // RESULT A-E - designate matrix for storing results
            if userIsEnteringDigits { endDisplayEntry() }
            brain.resultMatrixName = Matrix.names[buttonName]!
            updateDisplayString()
            userIsEnteringDigits = false
            userIsEnteringExponent = false
        case .STO:
            // STO A-E - store displayed value to matrix A-E, at row = register 0, col = register 1
            if userIsEnteringDigits { brain.pushOperand(displayStringNumber) }  // pws: may need to check liftStack, here
            storeDisplayToMatrix(sender)
            userIsEnteringDigits = false
            userIsEnteringExponent = false
        case .RCL:
            // RCL A-E - recall element of matrix A-E, at row = register 0, col = register 1
            if userIsEnteringDigits { brain.pushOperand(displayStringNumber) }  // pws: may need to check liftStack, here
            recallValueFromMatrix(sender)
            userIsEnteringDigits = false
            userIsEnteringExponent = false
        default:
            break
        }
        prefix = nil
        saveDefaults()
    }
    
    @IBAction func chsButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .none:
            if userIsEnteringExponent {
                // change sign of exponent, during entry
                let exponent2 = String(displayString.removeLast())
                let exponent1 = String(displayString.removeLast())
                var sign = String(displayString.removeLast())
                sign = sign == " " ? "-" : " "  // toggle sign
                displayString += sign + exponent1 + exponent2
                return
            } else if userIsEnteringDigits {
                // change sign of mantissa, during entry
                if displayString.first == "-" {
                    displayString.removeFirst()
                } else {
                    displayString = "-" + displayString
                }
                return
            }  // else CHS pressed with existing number on display
            performOperationFor(buttonName)
        case .f:
            prefix = .MATRIX
        case .GTO:
            // GTO-CHS - build-up to goto line number
            prefix = .GTO_CHS
            gotoLineNumberDigits = []
        case .STO:
            // STO-MATRIX
            prefix = .STO_MATRIX
        case .RCL:
            prefix = .RCL_MATRIX
        default:
            // GSB-CHS - perform operation (CHS) without prefix
            prefix = nil
            performOperationFor(buttonName)
        }
    }
    
    @IBAction func sevenButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .FIX
        }
        let gAction = {
            self.prefix = nil
            self.trigUnits = .DEG
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func eightButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .SCI
        }
        let gAction = {
            self.prefix = nil
            self.trigUnits = .RAD
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func nineButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .ENG
        }
        let gAction = {
            self.prefix = nil
            self.trigUnits = .GRAD
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func divideButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .f:
            prefix = .SOLVE
        case .g:
            // "x≤y" doesn't do anything in run mode (handled by program)
            prefix = nil
            endDisplayEntry()
            updateDisplayString()
        case .STO:
            prefix = .STO_DIV
        case .RCL:
            prefix = .RCL_DIV
        default:
            // perform operation without prefix
            prefix = nil
            performOperationFor(buttonName)
        }
    }
    
    @IBAction func sstButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        switch prefix {
        case .none:
            // single-step
            // while holding down SST button, display current line of code;
            // after releasing SST: 1) execute current line, 2) display results, 3) increment current line (don't show)
            if program.currentLineNumber == 0 { _ = program.forwardStep() }
            saveDisplayString = displayString
            displayString = program.currentInstruction
            sender.addTarget(self, action: #selector(sstButtonReleased), for: .touchUpInside)
        case .f:
            // "LBL" pressed
            prefix = nil  // LBL key ignored in run mode
        case .g:
            // BST pressed (back step program)
            prefix = nil
            // show previous line until button released (don't execute), then return to normal display
            displayString = program.backStep()
            sender.addTarget(self, action: #selector(bstButtonReleased), for: .touchUpInside)
        default:
            // clear prefix and re-run
            prefix = nil
            sstButtonPressed(sender)
        }
    }
    
    @IBAction func gtoButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        switch prefix {
        case .none:
            prefix = .GTO  // build-up to GTO n (go to label n) or GTO CHS nnn (go to line nnn)
        case .f:
            // "HYP" pressed
            prefix = .HYP
        case .g:
            // "HYP1" pressed
            prefix = .HYP1
        default:
            break
        }
    }
    
    @IBAction func sinButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .none, .g, .HYP, .HYP1:
            performOperationFor(buttonName)
        case .f:
            // DIM pressed
            prefix = .DIM
        case .RCL:
            // RCL-DIM pressed
            prefix = .RCL_DIM
        default:
            // clear prefix and re-run
            prefix = nil
            sinButtonPressed(sender)
        }
    }
    
    @IBAction func cosButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .none, .g, .HYP, .HYP1:
            performOperationFor(buttonName)
        case .f:
            // "(i)" pressed (show imaginary part of number if complex, else Error 3)
            if isComplexMode {
                // show imaginary part of number, until 1.2 sec after button is released
                prefix = nil
                if userIsEnteringDigits {
                    if liftStack {
                        brain.pushOperand(displayStringNumber)
                    } else {
                        endDisplayEntry()
                    }
                }
                if brain.xRegister is Double {
                    brain.swapRealImag()
                } else {
                    // if display is matrix, save it and show 0.0, until button released
                    saveMatrix = brain.xRegister as? Matrix
                    brain.xRegister = 0
                }
                updateDisplayString()
                userIsEnteringDigits = false
                userIsEnteringExponent = false
                liftStack = true
                sender.addTarget(self, action: #selector(iButtonReleased), for: .touchUpInside)
                return
            } else {
                prepStackForOperation()
                setError(3)
            }
        case .XSWAP:
            prefix = nil
            swapDisplayWithRegister(brain.iRegisterName)
        case .DSE, .ISG:  // DSE I, ISG I... don't do anything in run mode (handled by program)
            prefix = nil
            endDisplayEntry()
            updateDisplayString()
        case .STO, .RCL, .STO_ADD, .STO_SUB, .STO_MUL, .STO_DIV, .RCL_ADD, .RCL_SUB, .RCL_MUL, .RCL_DIV:
            operateOnStorageRegister(brain.iRegisterName)
            prefix = nil
            liftStack = true
        default:
            // clear prefix and re-run
            prefix = nil
            cosButtonPressed(sender)
        }
    }
    
    @IBAction func tanButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .none, .g, .HYP, .HYP1:
            performOperationFor(buttonName)
        case .f:
            // "I" pressed (imaginary number entered)
            prefix = nil
            isComplexMode = true
            prepStackForOperation()
            if brain.xRegister! is Double {
                //----------------------
                brain.moveRealXToImagX()
                //----------------------
//                displayString = String(brain.xRegister!)  // show real part  // pws: not necessary?
                updateDisplayString()
            } else { 
                setError(1)
            }
        case .FIX:
            // f-FIX-I (use value in register I to set display format)
            prefix = nil
            if let number = brain.valueFromStorageRegister("I") as? Double {
                let decimalPlaces = Int(abs(number))
                setDisplayFormatTo(.fixed(decimalPlaces))
            } else {
                setError(1)
            }
        case .SCI:
            // f-SCI-I (use value in register I to set display format)
            prefix = nil
            if let number = brain.valueFromStorageRegister("I") as? Double {
                let decimalPlaces = Int(abs(number))
                setDisplayFormatTo(.scientific(min(decimalPlaces, 6)))  // 1 sign + 1 mantissa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
            } else {
                setError(1)
            }
        case .ENG:
            // f-ENG-I (use value in register I to set display format)
            prefix = nil
            if let number = brain.valueFromStorageRegister("I") as? Double {
                let additionalDigits = Int(abs(number))
                setDisplayFormatTo(.engineering(min(additionalDigits, 6)))  // 1 sign + 1 mantissa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
            } else {
                setError(1)
            }
        case .XSWAP:
            prefix = nil
            swapDisplayWithRegister("I")
        case .DSE, .ISG:  // DSE I, ISG I... don't do anything in run mode (handled by program)
            prefix = nil
            endDisplayEntry()
            updateDisplayString()
        case .STO, .RCL, .STO_ADD, .STO_SUB, .STO_MUL, .STO_DIV, .RCL_ADD, .RCL_SUB, .RCL_MUL, .RCL_DIV:
            operateOnStorageRegister("I")
            prefix = nil
            liftStack = true
        default:
            // clear prefix and re-run
            prefix = nil
            tanButtonPressed(sender)
        }
    }
    
    @IBAction func eexButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .none:
            handleDigitEntry(buttonName: buttonName)
        case .f:
            // "RESULT" pressed
            prefix = .RESULT
        case .g:
            // pi pressed
            prefix = nil
            prepStackForRecalledValue(Double.pi)  // 3.141592653589793
            brain.printMemory()
        case .STO:
            prefix = nil
            prepStackForOperation()
            setError(11)
        case .STO_DOT, .RCL_DOT:
            // give up on STO/RCL . and re-enter EEX
            prefix = nil
            prepStackForOperation()
            eexButtonPressed(sender)
        case .RCL:
            // RCL RESULT - display results matrix
            prefix = nil
            let matrix = brain.matrices[brain.resultMatrixName]!
            prepStackForRecalledValue(matrix)
            brain.printMemory()
            print(matrix)
        default:
            // clear prefix and re-run
            prefix = nil
            eexButtonPressed(sender)
        }
    }
    
    @IBAction func fourButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .XSWAP
        }
        let gAction = {
            self.prefix = .SF
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func fiveButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .DSE
        }
        let gAction = {
            self.prefix = .CF
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func sixButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .ISG
        }
        let gAction = {
            self.prefix = .FQM  // ex. F? 0-9
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func multiplyButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .f:
            prefix = nil
            print("TBD: integral")
        case .g:
            // "x=0" doesn't do anything in run mode (handled by program)
            prefix = nil
            endDisplayEntry()
            updateDisplayString()
        case .STO:
            prefix = .STO_MUL
        case .RCL:
            prefix = .RCL_MUL
        default:
            // perform operation without prefix
            prefix = nil
            performOperationFor(buttonName)
        }
    }
    
    @IBAction func rsButtonPressed(_ sender: UIButton) {
        if prefix == .g {
            // P/R pressed - toggle program mode (don't send to program)
            simulatePressingButton(sender)
            prefix = nil
            isProgramMode.toggle()
            return
        }
        guard handleButton(sender) != nil else { return }

        switch prefix {
        case .none:
            // run/stop [program]
            if !isProgramRunning {
                // run program from current line, to end (vs. running from a label, to end)
                isProgramRunning = true
                program.isAnyButtonPressed = false
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
                    if program.currentLineNumber == 0 { program.incrementCurrentLine() }  // allows starting from line 0
                    program.runFromCurrentLine() {
                        DispatchQueue.main.async {
                            self.isProgramRunning = false
                        }
                    }
                }
            }
        case .f:
            // PSE pressed (pause program)
            prefix = nil  // ignore in run mode
        case .g:
            break  // handled above
        default:
            // clear prefix and re-run
            prefix = nil
            rsButtonPressed(sender)
        }
    }
    
    @IBAction func gsbButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        switch prefix {
        case .none:
            // GSB pressed
            prefix = .GSB  // build-up to GSB n (run from label n)
        case .f:
            // Σ pressed
            // clear statistics storage registers, memory stack, and display
            prefix = nil
            // TBD: clear statistics storage registers
            brain.clearRealStack()
            brain.clearImaginaryStack()
            clearDisplayAndXRegister()
        case .g:
            // RTN pressed
            prefix = nil
            // set program to line 0
            prepStackForOperation()
            program.currentLineNumber = 0
        default:
            // clear prefix and re-run
            prefix = nil
            gsbButtonPressed(sender)
        }
    }
    
    @IBAction func rDownArrowButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        switch prefix {
        case .none:
            // R↓ key pressed (roll stack down)
            if userIsEnteringDigits { brain.pushOperand(displayStringNumber) }  // push display onto stack
            brain.rollStack(directionDown: true)
        case .f:
            // CLEAR PRGM pressed (goto line 0 without delete program)
            prefix = nil
            endDisplayEntry()  // overwrite xRegister
            program.currentLineNumber = 0
        case .g:
            // R↑ key pressed (roll stack up)
            prefix = nil
            if userIsEnteringDigits { brain.pushOperand(displayStringNumber) }  // push display onto stack
            brain.rollStack(directionDown: false)
        default:
            // clear prefix and re-run
            prefix = nil
            rDownArrowButtonPressed(sender)
        }
        
        userIsEnteringDigits = false
        updateDisplayString()
        userIsEnteringExponent = false
        saveDefaults()
    }
    
    @IBAction func xyButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        switch prefix {
        case .none:
            // x≷y key pressed (swap x-y registers)
            if userIsEnteringDigits { brain.pushOperand(displayStringNumber) }  // push display onto stack
            brain.swapXyRegisters()
        case .f:
            // CLEAR REG key pressed (clear storage registers, not stack)
            prefix = nil
            if userIsEnteringDigits { brain.pushOperand(displayStringNumber) }  // push display onto stack
            brain.clearStorageRegisters()
        case .g:
            prefix = nil
            print("TBD: RND")
        default:
            // clear prefix and re-run
            prefix = nil
            xyButtonPressed(sender)
        }
        
        userIsEnteringDigits = false
        updateDisplayString()
        userIsEnteringExponent = false
        saveDefaults()
    }
    
    @IBAction func leftArrowButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        var okToClearUserEnteringDigits = true
        var okToClearUserEnteringExponent = true

        switch prefix {
        case .none:
            // ← key pressed (remove single digit or whole number)
            if userIsEnteringExponent {
                if displayStringExponent == "-00" {
                    // exponent = "-00" - remove minus sign
                    displayString = displayString.replacingOccurrences(of: "-00", with: " 00")
                    okToClearUserEnteringExponent = false  // ie. user is still removing exponent digits
                } else if displayStringExponent == " 00" {
                    // exponent = " 00" - remove it
                    displayString = displayString.components(separatedBy: " ")[0]
                    userIsEnteringExponent = false
                    okToClearUserEnteringDigits = false  // ie. user is still entering digits
                } else {
                    // exponent has non-zero digits - slide first digit of exponent right and back-fill with 0
                    displayString.removeLast()
                    let firstExponentDigit = String(displayString.removeLast())
                    displayString += "0" + firstExponentDigit
                    okToClearUserEnteringExponent = false  // ie. user is still removing exponent digits
                }
            } else {
                if !userIsEnteringDigits {
                    // display contains complete number - replace with 0.0
                    brain.xRegister = 0.0
                    liftStack = false
                } else if displayString.count > (displayString.first! == "-" ? 2 : 1) {
                    // display contains partially entered number - remove last digit
                    displayString = String(displayString.dropLast())
                    okToClearUserEnteringDigits = false  // ie. user is still entering digits
                } else {
                    // display has one digit left - push 0.0 onto stack (note: -n is considered 1 digit)
                    brain.pushOperand(0.0)
                    liftStack = false  // not sure if this is needed
                    brain.printMemory()
                }
            }
        case .f:
            // CLEAR PREFIX key pressed
            // display mantissa (all numeric digits with no punctuation), until 1.2 sec after button is released
            prefix = nil
            if userIsEnteringDigits { brain.pushOperand(displayStringNumber) }  // push display onto stack
            displayView.showCommas = false
            displayString = brain.displayMantissa
            sender.addTarget(self, action: #selector(clearPrefixButtonReleased), for: .touchUpInside)
        case .g:
            // CLx key pressed - clear display and x register
            prefix = nil
            clearDisplayAndXRegister()
            return  // return, or prior number will be displayed
        default:
            prefix = nil
            leftArrowButtonPressed(sender)
        }
        
        if okToClearUserEnteringExponent {
            userIsEnteringExponent = false
        }
        if okToClearUserEnteringDigits && okToClearUserEnteringExponent {
            userIsEnteringDigits = false
            updateDisplayString()
        }
    }
    
    @IBAction func enterButtonPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        if (isProgramRunning || program.isProgramPaused) && sender.tag != 1 {
            // user pressed button while program running or paused
            program.isAnyButtonPressed = true  // causes program to stop
            return
        }

        if isProgramMode {
            sendToProgram("E\nN\nT\nE\nR")  // ENTER (vertical)
            return
        }

        switch prefix {
        case .none:
            // Enter pressed
            if liftStack {
                //------------------------------------
                brain.pushOperand(displayStringNumber)
                brain.pushOperand(displayStringNumber)
                //------------------------------------
            } else {
                endDisplayEntry()  // overwrite xRegister
                brain.pushXRegister()
            }
            liftStack = false
        case .f:
            // RND# pressed
            prefix = nil
            srand48(seed)  // re-seed each time, so a manually stored seed will generate the same sequence each time
            let number = drand48()
            seed = Int(number * Double(Int32.max))  // number becomes next seed (note: Int.max gives same numbers for different seeds - bad)
            if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
            displayString = String(number)
            brain.pushOperand(number)
            lastRandomNumberGenerated = number
            liftStack = true
        case .g:
            // LSTx pressed
            prefix = nil
            brain.pushOperand(brain.lastXRegister)
            liftStack = true
        case .STO:
            // STO RAN# pressed (store display as new seed)
            prefix = nil
            liftStack = true
            if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
            if var number = brain.xRegister as? Double {
                number = min(max(number, 0.0), 0.9999999999)  // limit 0.0 <= number < 1.0
                seed = Int(number * Double(Int32.max))
                lastRandomNumberGenerated = number
            } else {
                setError(1)
            }
        case .RCL:
            // RCL RAN# pressed (recall current seed, which is based on last random number)
            prefix = nil
            brain.pushOperand(lastRandomNumberGenerated)
            liftStack = true
        default:
            liftStack = true
            return
        }
        updateDisplayString()
        brain.printMemory()
        userIsEnteringDigits = false
        userIsEnteringExponent = false
    }
    
    @IBAction func oneButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            // f-1: →R pressed (convert to rectangular coordinates)
            self.performOperationFor(buttonName)
        }
        let gAction = {
            // g-1: →P pressed (convert to polar coordinates)
            self.performOperationFor(buttonName)
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func twoButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            // f-2: →H.MS pressed (convert from decimal hours H.HHHH to hours-minutes-seconds-decimal seconds H.MMSSsssss)
            self.performOperationFor(buttonName)
        }
        let gAction = {
            // g-2: →H pressed (convert from hours-minutes-seconds-decimal seconds H.MMSSsssss to decimal hours H.HHHH)
            self.performOperationFor(buttonName)
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func threeButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            // f-3: →RAD pressed
            self.performOperationFor(buttonName)
        }
        let gAction = {
            // g-3: →DEG pressed
            self.performOperationFor(buttonName)
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func minusButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .f:
            // "Re≷Im" pressed (swap real and imaginary parts of complex number)
            prefix = nil
            isComplexMode = true
            prepStackForOperation()
            //------------------
            brain.swapRealImag()
            //------------------
            updateDisplayString()
        case .g:
            prefix = .TEST
        case .STO:
            prefix = .STO_SUB
        case .RCL:
            prefix = .RCL_SUB
        default:
            // perform operation without prefix
            prefix = nil
            performOperationFor(buttonName)
        }
    }
    
    @IBAction func onButtonPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        _ = restoreFromError()  // ON is the only key that finishes performing its function, if restoring from error
        if (isProgramRunning || program.isProgramPaused) && sender.tag != 1 {
            // user pressed button while program running or paused
            program.isAnyButtonPressed = true  // causes program to stop
        }

        calculatorIsOn.toggle()
        displayView.turnOnIf(calculatorIsOn)
        if calculatorIsOn {
            prepStackForOperation()  // HP-15C completes number entry, if power is cycled
            restoreDisplayLabels()
            prefix = nil  // prefix is lost after re-start
            userIsEnteringDigits = false
            userIsEnteringExponent = false
            isProgramMode = false  // don't re-start in program mode
        } else {
            hideDisplayLabels()
        }
        buttons.forEach { $0.isUserInteractionEnabled = calculatorIsOn }
    }
    
    @IBAction func fButtonPressed(_ sender: UIButton) {
        // if nil and !isProgramMode, user must have pressed a button while program running - return
        guard handleButton(sender) != nil || isProgramMode else { return }
        
        prefix = .f
    }
    
    @IBAction func gButtonPressed(_ sender: UIButton) {
        // if nil and !isProgramMode, user must have pressed a button while program running - return
        guard handleButton(sender) != nil || isProgramMode else { return }
        
        prefix = .g
    }
    
    @IBAction func stoButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .f:
            // "FRAC" pressed
            performOperationFor(buttonName)
        case .g:
            // "INT" pressed
            performOperationFor(buttonName)
        default:
            prefix = .STO
        }
    }
    
    @IBAction func rclButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        switch prefix {
        case .f:
            // "USER" pressed (swap the primary functions and f-shifted functions of keys A-E)
            prefix = nil
            isUserMode.toggle()
        case .g:
            // "MEM" pressed
            prefix = nil
            print("TBD: MEM")
        default:
            prefix = .RCL
        }
    }
    
    @IBAction func zeroButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        let fAction = {
            // x!
            self.performOperationFor(buttonName)
        }
        let gAction = {
            self.prefix = nil
            print("TBD: xbar")
        }
        handleNumberedButton(buttonName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func decimalPointButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .none:
            handleDigitEntry(buttonName: buttonName)
        case .f:
            prefix = nil
            print("TBD: yhat,r")
        case .g:
            prefix = nil
            print("TBD: S")
        case .STO:
            prefix = .STO_DOT
        case .RCL:
            prefix = .RCL_DOT
        case .STO_ADD:
            prefix = .STO_ADD_DOT
        case .STO_SUB:
            prefix = .STO_SUB_DOT
        case .STO_MUL:
            prefix = .STO_MUL_DOT
        case .STO_DIV:
            prefix = .STO_DIV_DOT
        case .RCL_ADD:
            prefix = .RCL_ADD_DOT
        case .RCL_SUB:
            prefix = .RCL_SUB_DOT
        case .RCL_MUL:
            prefix = .RCL_MUL_DOT
        case .RCL_DIV:
            prefix = .RCL_DIV_DOT
        case .GSB:
            prefix = .GSB_DOT
        case .GTO:
            prefix = .GTO_DOT
        case .SOLVE:
            prefix = .SOLVE_DOT
        case .DSE:
            prefix = .DSE_DOT
        case .ISG:
            prefix = .ISG_DOT
        case .XSWAP:
            prefix = .XSWAP_DOT
        default:
            // clear prefix and re-run
            prefix = nil
            decimalPointButtonPressed(sender)
        }
    }
    
    @IBAction func summationPlusButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        switch prefix {
        case .none:
            print("TBD: Σ+")
        case .f:
            prefix = nil
            print("TBD: L.R.")
        case .g:
            prefix = nil
            print("TBD: Σ-")
        default:
            break  // TBD
        }
    }
    
    @IBAction func plusButtonPressed(_ sender: UIButton) {
        guard let buttonName = handleButton(sender) else { return }

        switch prefix {
        case .f:
            // "Py,x" pressed (permutation)
            performOperationFor(buttonName)
        case .g:
            // "Cy,x" pressed (combinations)
            performOperationFor(buttonName)
        case .STO:
            prefix = .STO_ADD
        case .RCL:
            prefix = .RCL_ADD
        default:
            // perform operation without prefix
            prefix = nil
            performOperationFor(buttonName)
        }
    }

    // MARK: - Button action utilities
    
    private func buttonNameFromButton(_ button: UIButton) -> String {
        var buttonName = button.currentTitle!
        if buttonName == "·" { buttonName = "." } // replace "MIDDLE DOT" (used on button in interface builder) with period
        return buttonName
    }
    
    private func handleButton(_ button: UIButton) -> String? {
        simulatePressingButton(button)
        if restoreFromError() { return nil }
        if (isProgramRunning || program.isProgramPaused) && button.tag != 1 {
            // user pressed button while program running or paused
            program.isAnyButtonPressed = true  // causes program to stop
            return nil
        }
        let buttonName = buttonNameFromButton(button)
        
        if isProgramMode {
            sendToProgram(buttonName)
            prefix = nil
            return nil
        }
        return buttonName
    }

    private func handleUserMode() {  // only call for keys A-E
        if isUserMode {
            // swap the primary functions and f-shifted functions of keys A-E
            if prefix == nil {
                prefix = .f
            } else if prefix == .f {
                prefix = nil
            }
        }
    }
    
    private func performOperationFor(_ buttonName: String) {
        prepStackForOperation()
        brain.lastXRegister = brain.xRegister!  // save xRegister before pushing operation onto stack
        
        let oneLetterPrefix = (prefix?.rawValue ?? "n")  // n, f, g, H, h, or M
        prefix = nil  // must come after previous line
        //-------------------------------------------------
        brain.performOperation(oneLetterPrefix + buttonName)
        //-------------------------------------------------
        updateDisplayString()
        brain.printMemory()
    }
    
    private func runProgramFrom(label: String) {
        isProgramRunning = true
        program.isAnyButtonPressed = false
        // run in background, so any button press is detected
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
            program.runFrom(label: label) {
                DispatchQueue.main.async {
                    self.isProgramRunning = false
                }
            }
        }
    }
    
    private func solveFrom(label: String) {
        isProgramRunning = true
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
            solve.findRootOfEquationAt(label: label) {
                DispatchQueue.main.async {
                    self.isProgramRunning = false
                }
            }
        }
    }
    
    private func setDisplayFormatTo(_ format: DisplayFormat) {
        if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
        displayFormat = format
        updateDisplayString()
    }
    
    private func handleNumberedButton(_ buttonName: String, fAction: () -> Void, gAction: () -> Void) {
        switch prefix {
        case .none:
            handleDigitEntry(buttonName: buttonName)
        case .f:
            fAction()
        case .g:
            gAction()
        case .FIX:
            prefix = nil
            setDisplayFormatTo(.fixed(Int(buttonName)!))
        case .SCI:
            prefix = nil
            setDisplayFormatTo(.scientific(min(Int(buttonName)!, 6)))  // 1 sign + 1 mantissa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
        case .ENG:
            prefix = nil
            setDisplayFormatTo(.engineering(min(Int(buttonName)!, 6)))  // 1 sign + 1 mantissa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
        case .MATRIX:
            switch buttonName {
            case "0":
                // f MATRIX 0 - clear all matrices
                brain.clearMatrices()
            case "1":
                // f MATRIX 1 - store beginning row and column numbers in registers 0 and 1, respectively
                _ = brain.storeValueInRegister("0", value: 1)
                _ = brain.storeValueInRegister("1", value: 1)
            case "4", "5", "6", "7", "8", "9":
                // f MATRIX n (4: transpose, 5: Y_transpose * X, 6: residual, 7: row norm, 8: Frobenius norm, 9: determinant)
                performOperationFor(buttonName)
            default:
                setError(11)
            }
            prefix = nil
        case .SOLVE:
            prefix = nil
            solveFrom(label: buttonName)
        case .SOLVE_DOT:
            prefix = nil
            solveFrom(label: "." + buttonName)
        case .SF:
            prefix = nil
            let number = Int(buttonName)!
            switch number {
            case 0...7:
                flags[number] = true
            case 8:
                isComplexMode = true
            case 9:
                print("TBD: set blinking display")
            default:
                break
            }
        case .CF:
            prefix = nil
            let number = Int(buttonName)!
            switch number {
            case 0...7:
                flags[number] = false
            case 8:
                isComplexMode = false
            case 9:
                print("TBD: clear blinking display")
            default:
                break
            }
        case .FQM, .TEST, .DSE, .DSE_DOT, .ISG, .ISG_DOT:  // F? n, TEST n, DSE n,... don't do anything in run mode (handled by program)
            prefix = nil
            endDisplayEntry()
            updateDisplayString()
        case .GTO:
            prefix = nil
            if !program.gotoLabel(buttonName) {  // would only be here in non-program mode
                setError(4)
            }
        case .GTO_DOT:
            prefix = nil
            if !program.gotoLabel("." + buttonName) {  // would only be here in non-program mode
                setError(4)
            }
        case .GTO_CHS:
            handleGotoLineNumberDigit(digit: Int(buttonName)!)
        case .GSB:
            prefix = nil
            runProgramFrom(label: buttonName)
        case .GSB_DOT:
            prefix = nil
            runProgramFrom(label: "." + buttonName)
        case .XSWAP:
            prefix = nil
            swapDisplayWithRegister(buttonName)
        case .XSWAP_DOT:
            prefix = nil
            swapDisplayWithRegister("." + buttonName)
        case .STO, .RCL, .STO_ADD, .STO_SUB, .STO_MUL, .STO_DIV, .RCL_ADD, .RCL_SUB, .RCL_MUL, .RCL_DIV:
            operateOnStorageRegister(buttonName)
            prefix = nil
            liftStack = true
        case .STO_DOT, .RCL_DOT, .STO_ADD_DOT, .STO_SUB_DOT, .STO_MUL_DOT, .STO_DIV_DOT, .RCL_ADD_DOT, .RCL_SUB_DOT, .RCL_MUL_DOT, .RCL_DIV_DOT:
            operateOnStorageRegister("." + buttonName)
            prefix = nil
            liftStack = true
        default:
            break
        }
    }
    
    // use for buttons 0-9, ., EEX (without prefix)
    private func handleDigitEntry(buttonName: String) {
        if buttonName == "EEX" {
            if !userIsEnteringExponent {
                userIsEnteringExponent = true
                if !userIsEnteringDigits {
                    // EEX pressed by itself, set mantissa to 1 (exponent will be 00)
                    userIsEnteringDigits = true
                    displayString = "1"
                }
                var paddingLength = decimalWasAlreadyEntered ? 9 : 8  // decimal doesn't take up space (part of prior digit)
                if displayString.prefix(1) == "-" { paddingLength += 1 }  // negative sign pushes numbers to right
                displayString = displayString.prefix(paddingLength - 1).padding(toLength: paddingLength, withPad: " ", startingAt: 0) + "00"
            }
        } else if userIsEnteringDigits {
            // add digit to display (only one decimal per number, and none in exponent)
            if !(buttonName == "." && (decimalWasAlreadyEntered || userIsEnteringExponent)) {
                if userIsEnteringExponent {
                    // slide second digit of exponent left and put new digit in its place
                    let secondExponentDigit = String(displayString.removeLast())
                    displayString.removeLast()
                    displayString += secondExponentDigit + buttonName
                } else {
                    //--------------------------------------------------------
                    displayString += buttonName  // append entered digit to display
                    //--------------------------------------------------------
                }
            }
        } else {
            // start clean display with digit
            if buttonName == "." {
                displayString = "0."  // precede leading decimal point with a zero
            } else {
                displayString = buttonName
            }
            userIsEnteringDigits = true
        }
        saveDefaults()
    }
    
    private func handleGotoLineNumberDigit(digit: Int) {
        gotoLineNumberDigits.append(digit)
        if gotoLineNumberDigits.count == 3 {
            prefix = nil
            let gotoLineNumber = 100 * gotoLineNumberDigits[0] + 10 * gotoLineNumberDigits[1] + gotoLineNumberDigits[2]
            if gotoLineNumber >= program.instructions.count {
                // line number past end of program
                prepStackForOperation()
                setError(4)
            } else {
                program.currentLineNumber = gotoLineNumber
            }
        }
    }
    
    private func operateOnStorageRegister(_ register: String) {
        switch prefix {
        case .STO, .STO_DOT:
            storeDisplayToRegister(register)
        case .RCL, .RCL_DOT:
            recallRegister(register)
        case .STO_ADD, .STO_ADD_DOT:
            applyDisplayToRegister(register, using: { $0 + $1 })
        case .STO_SUB, .STO_SUB_DOT:
            applyDisplayToRegister(register, using: { $0 - $1 })
        case .STO_MUL, .STO_MUL_DOT:
            applyDisplayToRegister(register, using: { $0 * $1 })
        case .STO_DIV, .STO_DIV_DOT:
            applyDisplayToRegister(register, using: { $0 / $1 })
        case .RCL_ADD, .RCL_ADD_DOT:
            applyRegisterToDisplay(register, using: { $0 + $1 })
        case .RCL_SUB, .RCL_SUB_DOT:
            applyRegisterToDisplay(register, using: { $0 - $1 })
        case .RCL_MUL, .RCL_MUL_DOT:
            applyRegisterToDisplay(register, using: { $0 * $1 })
        case .RCL_DIV, .RCL_DIV_DOT:
            applyRegisterToDisplay(register, using: { $0 / $1 })
        default:
            break
        }
    }

    // call with register name "0" - "9", ".0" - ".9"
    private func storeDisplayToRegister(_ registerName: String) {
        if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
        if brain.storeValueInRegister(registerName, value: brain.xRegister!) {
            updateDisplayString()
            brain.printMemory()
        } else {
            setError(3)
        }
    }
    
    // call with register name "0" - "9", ".0" - ".9"
    private func recallRegister(_ registerName: String) {
        if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
        if let value = brain.valueFromStorageRegister(registerName) {
            if let number = value as? Double {
                displayString = String(number)
                brain.pushOperand(displayStringNumber)
                updateDisplayString()
                brain.printMemory()
            } else {
                setError(1)  // register contains matrix
            }
        } else {
            setError(3)  // invalid registerName
        }
    }
    
    // apply operation on value in storage register and display; store results back in storage register
    private func applyDisplayToRegister(_ registerName: String, using operation: ((Double, Double) -> Double)) {
        if userIsEnteringDigits {
            brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
            userIsEnteringDigits = false
            userIsEnteringExponent = false
        }
        if let value = brain.valueFromStorageRegister(registerName) {
            if let storageNumber = value as? Double, let xRegisterNumber = brain.xRegister! as? Double {
                let result = operation(storageNumber, xRegisterNumber)
                if result.isNaN || result.isInfinite {
                    displayString = "nan"  // triggers displayView to show "  Error  0"
                } else {
                    _ = brain.storeValueInRegister(registerName, value: result)
                    updateDisplayString()
                }
                brain.printMemory()
            } else {
                setError(1)  // register contains matrix
            }
        } else {
            setError(3)  // invalid registerName
        }
    }
    
    // apply operation on value in storage register and display; show results in display
    private func applyRegisterToDisplay(_ registerName: String, using operation: ((Double, Double) -> Double)) {
        if userIsEnteringDigits {
            brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
            userIsEnteringDigits = false
            userIsEnteringExponent = false
        }
        if let value = brain.valueFromStorageRegister(registerName) {
            if let storageNumber = value as? Double, let xRegisterNumber = brain.xRegister! as? Double {
                let result = operation(xRegisterNumber, storageNumber)
                if result.isNaN || result.isInfinite {
                    displayString = "nan"  // triggers displayView to show "  Error  0"
                } else {
                    brain.xRegister = result
                    updateDisplayString()
                }
                brain.printMemory()
            } else {
                setError(1)  // register contains matrix
            }
        } else {
            setError(3)  // invalid registerName
        }
    }
    
    private func clearDisplayAndXRegister() {
        displayString = String(format: displayFormat.string, 0.0)  // display 0.0
        if userIsEnteringDigits {
            brain.pushOperand(0)
        } else {
            brain.xRegister = 0
        }
        liftStack = false
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        saveDefaults()
        brain.printMemory()
    }
    
    private func swapDisplayWithRegister(_ registerName: String) {
        if userIsEnteringDigits {
            brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
            userIsEnteringDigits = false
            userIsEnteringExponent = false
        }
        brain.swapXWithRegister(registerName)
        updateDisplayString()
        brain.printMemory()
    }
    
    // store displayed value to matrix A-E, at row = register 0, col = register 1
    private func storeDisplayToMatrix(_ button: UIButton) {
        if let (row, col) = currentMatrixRowCol() {
            let buttonName = buttonNameFromButton(button)
            let matrix = brain.matrices[Matrix.names[buttonName]!]!
            if matrix.isInBounds(row: row, col: col) {
                let space = row > 9 ? " " : "  "
                displayString = "\(matrix.name)\(space)\(row),\(col)"
                button.addTarget(self, action: #selector(storeMatrixButtonReleased), for: .touchUpInside)
                // if user holds button down for more than 3 sec, display "null"
                showMatrixElementTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] timer in
                    self?.displayView.showCommas = false
                    self?.displayString = "NULL"  // appears as small letters
                }
            } else {
                setError(3)  // trying to set value outside matrix dimensions
            }
        } else {
            setError(1)  // registers 0 or 1 contain matrix
        }
    }
    
    // recall element of matrix A-E, at row = register 0, col = register 1
    // show matrix name, row, and col (ex. "A  2,1") while button pressed
    // show matrix element when button released (in matrixButtonReleased), and increment registers
    // if button pressed for more than 3 seconds, show "null" and don't increment registers
    private func recallValueFromMatrix(_ button: UIButton) {
        if let (row, col) = currentMatrixRowCol() {
            let buttonName = buttonNameFromButton(button)
            let matrix = brain.matrices[Matrix.names[buttonName]!]!
            if matrix.isInBounds(row: row, col: col) {
                let space = row > 9 ? " " : "  "
                displayString = "\(matrix.name)\(space)\(row),\(col)"
                button.addTarget(self, action: #selector(recallMatrixButtonReleased), for: .touchUpInside)
                // if user holds button down for more than 3 sec, display "null"
                showMatrixElementTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] timer in
                    self?.displayView.showCommas = false
                    self?.displayString = "NULL"  // appears as small letters
                }
            } else {
                setError(3)  // trying to recall value outside matrix dimensions
            }
        } else {
            setError(1)  // registers 0 or 1 contain matrix
        }
    }
    
    // return current matrix row and column from storage registers 0 and 1, respectively
    // return nil, if either register contains a matrix, rather than a double
    private func currentMatrixRowCol() -> (Int, Int)? {
        if let storage0 = brain.valueFromStorageRegister("0")! as? Double,
           let storage1 = brain.valueFromStorageRegister("1")! as? Double {
            let row = Int(storage0)
            let col = Int(storage1)
            return (row, col)
        } else {
            return nil
        }
    }

    // MARK: - Simulated button
    
    // All button actions trigger on Touch Down (see header notes).  SimulatePressingButton plays
    // a click sound and darkens the button text, then creates a temporary target for Touch Up
    // Inside, which gets called when the button is released (calling simulateReleasingButton).
    private func simulatePressingButton(_ button: UIButton) {
        guard useSimButton else { return }  // return, if program "pressed" the button
        clickSoundPlayer?.play()
        buttonCoverViews[button]?.whiteLabel.textColor = .darkGray
        button.addTarget(self, action: #selector(simulateReleasingButton), for: .touchUpInside)
    }
    
    // When the button is released, reset button text to normal color, and remove this target for Touch Up Inside.
    @objc private func simulateReleasingButton(_ button: UIButton) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {  // delay before restoring color, otherwise it is unnoticeable
            self.buttonCoverViews[button]?.whiteLabel.textColor = CoverConst.whiteColor
            button.removeTarget(nil, action: nil, for: .touchUpInside)
        }
    }
    
    @objc private func iButtonReleased(_ button: UIButton) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) {
            button.removeTarget(nil, action: nil, for: .touchUpInside)
            if let matrix = self.saveMatrix {
                // undoing showing imaginary with matrix in display
                self.brain.xRegister = matrix
                self.saveMatrix = nil
            } else {
                self.brain.swapRealImag()
            }
            self.updateDisplayString()
        }
    }
    
    @objc private func storeMatrixButtonReleased(_ button: UIButton) {
        showMatrixElementTimer.invalidate()  // stop timer for displaying "null"
        let buttonName = buttonNameFromButton(button)
        let matrix = brain.matrices[Matrix.names[buttonName]!]!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            if displayString == "NULL" {
                // user done holding button > 3 seconds, show prior display
                displayView.showCommas = true
                updateDisplayString()
            } else {
                button.removeTarget(nil, action: nil, for: .touchUpInside)
                let (row, col) = currentMatrixRowCol()!
                _ = matrix.storeValue(brain.xRegister as! Double, atRow: row, col: col)
                updateDisplayString()
                if isUserMode {
                    // auto-increment row/col registers
                    let (newRow, newCol) = matrix.incrementRowCol(row: row, col: col)
                    _ = brain.storeValueInRegister("0", value: Double(newRow))
                    _ = brain.storeValueInRegister("1", value: Double(newCol))
                }
            }
            brain.printMemory()
            print(matrix)
        }
    }
    
    @objc private func recallMatrixButtonReleased(_ button: UIButton) {
        showMatrixElementTimer.invalidate()  // stop timer for displaying "null"
        let buttonName = buttonNameFromButton(button)
        let matrix = brain.matrices[Matrix.names[buttonName]!]!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [unowned self] in
            if displayString == "NULL" {
                // user done holding button > 3 seconds, show prior display
                displayView.showCommas = true
                updateDisplayString()
            } else {
                button.removeTarget(nil, action: nil, for: .touchUpInside)
                let (row, col) = currentMatrixRowCol()!
                let value = matrix.recallValue(atRow: row, col: col)!
                brain.pushOperand(value)
                updateDisplayString()
                if isUserMode {
                    // auto-increment row/col registers
                    let (newRow, newCol) = matrix.incrementRowCol(row: row, col: col)
                    _ = brain.storeValueInRegister("0", value: Double(newRow))
                    _ = brain.storeValueInRegister("1", value: Double(newCol))
                }
            }
            brain.printMemory()
            print(matrix)
        }
    }

    @objc private func clearPrefixButtonReleased(_ button: UIButton) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) {
            button.removeTarget(nil, action: nil, for: .touchUpInside)
            self.displayView.showCommas = true
            self.updateDisplayString()
            self.brain.printMemory()
        }
    }
    
    // while holding down SST button, display current line of code;
    // after releasing SST button: 1) execute current line, 2) display results, 3) increment current line (don't show)
    // note: if user entering digits and program line is not executable, the display is sent to the stack
    @objc private func sstButtonReleased(_ button: UIButton) {
        button.removeTarget(nil, action: nil, for: .touchUpInside)
        displayString = saveDisplayString
        DispatchQueue.global(qos: .userInitiated).async {  // put on queue, or runCurrentInstruction DispatchQueue.main.sync causes an exception
            self.program.runCurrentInstruction()
            _ = self.program.forwardStep()
        }
    }
    
    @objc private func bstButtonReleased(_ button: UIButton) {
        button.removeTarget(nil, action: nil, for: .touchUpInside)
        updateDisplayString()
    }

    private func setupClickSoundPlayer() {
        guard let url = Bundle.main.url(forResource: "click", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            clickSoundPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
//            clickSoundPlayer?.delegate = self  // to receive call to audioPlayerDidFinishPlaying
        } catch let error {
            print(error.localizedDescription)
        }
    }
}
