//
//  CalculatorViewController.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/4/21.
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
//
//  To do...
//  - implement RND key (round mantissa to displayed digits)
//  - some numbers don't allow entering exponent EEX (ex. 12345678 EEX doesn't, 1234567 EEX does, 1.2345678 EEX does)
//  - p59 rounding displayed scientific numbers not implemented
//  - p61 swapping "." and "," in displaying number is not implemented
//  - make display blink when +/-overflow (9.999999 99) ex. 1 EEX 99 Enter 10 x
//  - on real HP-15C, following overflow, entering <- key causes blinking to stop, but leaves 9.999999 99 in display (xRegister)
//  - p61 implement underflow (displays 0.0)
//  - stop program if any key pressed
//  - p90 implement program branching and control
//  - if the user enters f-A in program mode, the HP-15C enters the instruction for GSB-A
//  - HP-15C displays Error 5, if there are more than 7 nested subroutine calls (GSB) in a program
//

import UIKit
import AVFoundation  // needed for AVAudioPlayer

struct Pause {
    static let time = 1.2
}

enum Prefix: String {
    case f  // function above button (orange)
    case g  // function below button (blue)
    case LBL  // ex. f LBL A (label in program), or LBL A (run program from label A)
    case LBL_DOT  // ex. f LBL . 2 (0 - 9, .0 - .9 are valid labels)
    case GSB  // ex. GSB B (goto label B and run until RTN)
    case GSB_DOT  // ex. GSB . 0 (0 - 9, .0 - .9 are valid labels)
    case GTO  // ex. GTO 5 (goto label 5)
    case GTO_DOT  // ex. GTO . 5 (goto label .5)
    case GTO_CHS  // ex. GTO CHS nnn (go to line nnn) - needs three digits
    case SOLVE  // ex. f SOLVE A (solve for roots of equation starting at label A)
    case FIX  // ex. f FIX 4 (format numbers in fixed-point with 4 decimal places)
    case SCI
    case ENG
    case HYP = "H"  // ex. f HYP SIN (hyperbolic sine)
    case HYP1 = "h"  // ex. g HYP1 SIN (inverse hyperbolic sine)
    case SF  // ex. g SF 8 (set flag 8 - enable complex mode)
    case CF  // ex. g CF 8 (clear flag 8 - disable complex mode)
    case STO  // ex. STO 0 (store display to register 0)
    case STO_DOT  // ex. STO . 0 (.0 - .9 are valid storage registers)
    case STO_ADD  // ex. 4 STO + 1 (ADD 4 to register 1)
    case STO_SUB
    case STO_MUL
    case STO_DIV
    case RCL  // ex. RCL 0 (recall register 0 to display)
    case RCL_DOT  // ex. RCL . 0 (.0 - .9 are valid storage registers)
    case RCL_ADD  // ex. RCL + 1 (ADD register 1 to display)
    case RCL_SUB
    case RCL_MUL
    case RCL_DIV
}

enum TrigMode: String, Codable {
    case DEG = "D"  // default
    case RAD = "R"
    case GRAD = "G"  // 100 gradians = 90 degrees
}

class CalculatorViewController: UIViewController, ProgramDelegate, SolveDelegate {
    
    var brain = CalculatorBrain()
    var program = Program()
    var solve = Solve()
    var clickSoundPlayer: AVAudioPlayer?
    var displayString = "" { didSet { displayView.displayString = displayString } }
    var displayFormat = DisplayFormat.fixed(4)
    var displayLabels = [UILabel]()
    var savedDisplayLabelAlphas = [CGFloat]()  // save for turning calculator Off/On
    var saveDisplayString = ""
    var calculatorIsOn = true
    var liftStack = true  // false between pressing enter and an operation (determines overwriting or pushing xRegister)
    var userIsEnteringDigits = false
    var userIsEnteringExponent = false  // userIsEnteringExponent and userIsEnteringDigits can be true at the same time
    var buttonCoverViews = [UIButton: ButtonCoverView]()  // overlays buttons to provide text above and inside buttons
    var seed = 0  // HP-15C initial random number seed is zero
    var lastRandomNumberGenerated = 0.0
    var isGettingDefaults = false
    var useSimButton = true  // true: call simulatePressingButton to play click sound, use false while running program instructions
    var gotoLineNumberDigits = [Int]()

    var displayStringNumber: Double {
        if userIsEnteringExponent {
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
        if userIsEnteringExponent {
            return String(displayString.suffix(2))
        } else {
            return "00"
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
    
    var trigMode = TrigMode.DEG {
        didSet {
            brain.trigMode = trigMode
            switch trigMode {
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
    
    var isComplexMode = false {  // use g-4 (SF) 8 to enable complex mode and g-5 (CF) 8 to disable complex mode
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
    
    var isRunMode = false {
        didSet {
            if isRunMode { displayView.displayString = " Running" }  // send directly to displayView, else displayStringNumber fails
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
        "√x": ("A", "x²"),
        "ex": ("B", "LN"),
        "10x": ("C", "LOG"),  // superscripting 10^x occurs in superscriptLastNCharactersOf, below
        "yx": ("D", "%"),
        "1/x": ("E", "𝝙%"),
        "CHS": ("MATRIX", "ABS"),
        "7": ("FIX", "DEG"),
        "8": ("SCI", "RAD"),
        "9": ("ENG", "GRD"),
        "÷": ("SOLVE", "x≤y"),
        "SST": ("LBL", "BST"),
        "GTO": ("HYP", "HYP-1"),
        "SIN": ("DIM", "SIN-1"),
        "COS": ("(i)", "COS-1"),
        "TAN": ("I", "TAN-1"),
        "EEX": ("RESULT", "π"),  // enter pi using option p
        "4": ("x≷", "SF"),
        "5": ("DSE", "CF"),
        "6": ("ISG", "F?"),
        "×": ("∫xy", "x=0"),
        "R/S": ("PSE", "P/R"),
        "GSB": ("∑", "RTN"),
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

    private func saveDefaults() {  // pws: should I save seed and lastRandomNumberGenerated?
        if !isGettingDefaults {  // several variables save defaults in their didSet handlers; don't save everything else, while getting defaults
            let defaults = UserDefaults.standard
            if let data = try? JSONEncoder().encode(displayFormat) {
                defaults.set(data, forKey: "displayFormat")
            }
            defaults.set(displayString, forKey: "displayString")
            defaults.set(gradLabel.text, forKey: "gradLabelText")
            defaults.setValue(displayLabelAlphas, forKey: "displayLabelAlphas")
            if let data = try? JSONEncoder().encode(brain) {
                defaults.set(data, forKey: "brain")  // note: variables added to brain must also be added to CalculatorBrain.init and .encode
            }
            defaults.set(isComplexMode, forKey: "isComplexMode")
            defaults.set(isUserMode, forKey: "isUserMode")
            defaults.set(userIsEnteringDigits, forKey: "userIsEnteringDigits")
            defaults.set(userIsEnteringExponent, forKey: "userIsEnteringExponent")
            defaults.set(liftStack, forKey: "liftStack")
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
            brain = try! JSONDecoder().decode(CalculatorBrain.self, from: data)
        }
        isComplexMode = defaults.bool(forKey: "isComplexMode")  // must get after brain, so isComplexMode.oldValue is correct
        isUserMode = defaults.bool(forKey: "isUserMode")
        liftStack = defaults.bool(forKey: "liftStack")
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
        }  // else complete number already in xRegister; ex. pi pi +
        updateDisplayString()
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        liftStack = true
    }
    
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
            displayString = " 9.999999 99"
            return
        case .underflow:
            displayString = "-9.999999 99"
            return
        default:  // .invalidKeySequence, .none
            break
        }
        //--------------------------------------
        let numericalResult = brain.xRegister!
        //--------------------------------------
        var potentialDisplayString = String(format: displayFormat.string, numericalResult)
        
        // for engineering notation, adjust mantissa so that exponent is a factor of 3
        if case .engineering(let additionalDigits) = displayFormat {
            let components = potentialDisplayString.components(separatedBy: "e")
            var mantissa = Double(components[0])!
            var exponent = Int(components[1])!
            while abs(exponent) % 3 > 0 {
                mantissa *= 10
                exponent -= 1
            }
            let mantissaLength = additionalDigits + (potentialDisplayString.first == "-" ? 1 : 0) + 2
            let mantissaString = String(mantissa).padding(toLength: mantissaLength, withPad: "0", startingAt: 0)
            potentialDisplayString = mantissaString.prefix(mantissaLength) + String(format: "e%+03d", exponent)  // 2-digit exponent, including sign
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
                displayString = String(format: DisplayFormat.scientific(decimalPlaces).string, numericalResult)
            } else if displayConvertedBackToNumber == 0 && numericalResult != 0 {
                // rounds to zero, temporarily switch to scientific notation
                displayString = String(format: DisplayFormat.scientific(decimalPlaces).string, numericalResult)
            } else {
                // all good
                displayString = potentialDisplayString
            }
        } else {
            // scientific or engineering format
            displayString = potentialDisplayString
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
    
    private func sendToProgram(_ keyName: String) {
        if let instruction = program.buildInstructionWith(keyName) {
            displayString = instruction
            saveProgram()
        }
    }
    
    // MARK: - Button actions
    
    @IBAction func aToEButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        handleUserMode()
        
        switch prefix {
        case .none, .g:
            performOperationFor(keyName)
        case .f, .GSB:
            runProgramFrom(label: keyName)
        case .LBL:
            if isProgramMode {
                sendToProgram(keyName)
            }  // else ignore
        case .SOLVE:
            isRunMode = true
            DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
                solve.findRootOfEquationAt(label: keyName)
            }
        case .GTO:
            if !program.gotoLabel(keyName) {
                setError(4)
            }
        default:
            break
        }
        prefix = nil
    }
    
    @IBAction func chsButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

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
            }  // else CHS pressed with existing number on display (push "nCHS" onto stack, below)
            performOperationFor(keyName)
        case .GTO:
            // GTO-CHS - build-up to goto line number
            prefix = .GTO_CHS
            gotoLineNumberDigits = []
        case .STO, .RCL:
            // ignore
            prefix = nil
        default:
            // GSB-CHS - perform operation (CHS) without prefix
            prefix = nil
            performOperationFor(keyName)
        }
    }
    
    @IBAction func sevenButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .FIX
        }
        let gAction = {
            self.prefix = nil
            self.trigMode = .DEG
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func eightButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .SCI
        }
        let gAction = {
            self.prefix = nil
            self.trigMode = .RAD
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func nineButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = .ENG
        }
        let gAction = {
            self.prefix = nil
            self.trigMode = .GRAD
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func divideButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        switch prefix {
        case .f:
            prefix = .SOLVE
        case .g:
            prefix = nil
            print("TBD: x<=y")
        case .STO:
            prefix = .STO_DIV
        case .RCL:
            prefix = .RCL_DIV
        default:
            // perform operation without prefix
            prefix = nil
            performOperationFor(keyName)
        }
    }
    
    @IBAction func sstButtonPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = keyNameFromButton(sender)

        switch prefix {
        case .none:
            // single-step
            if isProgramMode {
                // show next instruction; don't run
                sendToProgram(keyName)
            } else {
                // while holding down SST button, display current line of code;
                // after releasing SST: 1) execute current line, 2) display results, 3) increment current line (don't show)
                if program.currentLineNumber == 0 { _ = program.forwardStep() }
                saveDisplayString = displayString
                displayString = program.currentInstruction
                sender.addTarget(self, action: #selector(sstButtonReleased), for: .touchUpInside)
            }
        case .f:
            // "LBL" pressed
            prefix = nil
            if isProgramMode {
                // add to program
                sendToProgram(keyName)
            } // LBL key ignored in run mode
        case .g:
            // BST pressed (back step program)
            prefix = nil
            if isProgramMode {
                // show previous instruction; don't run
                sendToProgram(keyName)
            } else {
                // show previous line until button released (don't execute), then return to normal display
                displayString = program.backStep()
                sender.addTarget(self, action: #selector(bstButtonReleased), for: .touchUpInside)
            }
        default:
            // clear prefix and re-run
            prefix = nil
            sstButtonPressed(sender)
        }
    }
    
    @IBAction func gtoButtonPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }

        switch prefix {
        case .none:
            prefix = .GTO  // build-up to GTO n (go to label n) or GTO CHS nnn (go to line nnn)
        case .f:
            // "HYP" pressed
            if isProgramMode {
                prefix = nil  // program keeps its own prefix
            } else {
                prefix = .HYP
            }
        case .g:
            // "HYP1" pressed
            if isProgramMode {
                prefix = nil
            } else {
                prefix = .HYP1
            }
        default:
            break
        }
    }
    
    @IBAction func sinButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        switch prefix {
        case .none, .g, .HYP, .HYP1:
            performOperationFor(keyName)
        case .f:
            // "DIM" pressed
            prefix = nil
            print("TBD: DIM")
        default:
            // clear prefix and re-run
            prefix = nil
            sinButtonPressed(sender)
        }
    }
    
    @IBAction func cosButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        switch prefix {
        case .none, .g, .HYP, .HYP1:
            performOperationFor(keyName)
        case .f:
            // "(i)" pressed (show imaginary part of number if complex, else Error 3)
            if isComplexMode {
                // show imaginary part of number, until 1.2 sec after button is released
                prefix = nil
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.swapRealImag()
                updateDisplayString()
                sender.addTarget(self, action: #selector(iButtonReleased), for: .touchUpInside)
                return
            } else {
                prepStackForOperation()
                setError(3)
            }
        case .STO:
            // STO to register number stored in I (integer portion of absolute value of number stored in I)
            prefix = nil
            print("TBD: STO (i)")
        case .RCL:
            // RCL from register number stored in I (integer portion of absolute value of number stored in I)
            prefix = nil
            print("TBD: RCL (i)")
        default:
            // clear prefix and re-run
            prefix = nil
            cosButtonPressed(sender)
        }
    }
    
    @IBAction func tanButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        switch prefix {
        case .none, .g, .HYP, .HYP1:
            performOperationFor(keyName)
        case .f:
            // "I" pressed (imaginary number entered)
            prefix = nil
            isComplexMode = true
            prepStackForOperation()
            //----------------------
            brain.moveRealXToImagX()
            //----------------------
            displayString = String(brain.xRegister!)  // show real part
            updateDisplayString()
        case .STO:
            // STO to register I
            prefix = nil
            print("TBD: STO I")
        case .RCL:
            // RCL from register I
            prefix = nil
            print("TBD: RCL I")
        default:
            // clear prefix and re-run
            prefix = nil
            tanButtonPressed(sender)
        }
    }
    
    @IBAction func eexButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        switch prefix {
        case .none:
            handleDigitEntry(keyName: keyName)
        case .f:
            // "I" pressed (imaginary number entered)
            prefix = nil
            isComplexMode = true
            prepStackForOperation()
            //----------------------
            brain.moveRealXToImagX()
            //----------------------
            displayString = String(brain.xRegister!)  // show real part
            updateDisplayString()
        case .g:
            // pi pressed
            prefix = nil
            if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
            displayString = String(Double.pi)  // 3.141592653589793
            brain.pushOperand(Double.pi)
            updateDisplayString()
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
            prefix = nil
            prepStackForOperation()
            setError(99)  // pws: actually RCL EEX displays "A      0  0" (not sure what this is)
        default:
            // clear prefix and re-run
            prefix = nil
            eexButtonPressed(sender)
        }
    }
    
    @IBAction func fourButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = nil
            print("TBD: x<>")  // see oneButtonPressed()
        }
        let gAction = {
            self.prefix = .SF
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func fiveButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = nil
            print("TBD: DSE")
        }
        let gAction = {
            self.prefix = .CF
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func sixButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = nil
            print("TBD: ISG")
        }
        let gAction = {
            self.prefix = nil
            print("TBD: F?")
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func multiplyButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        switch prefix {
        case .f:
            prefix = nil
            print("TBD: integral")
        case .g:
            prefix = nil
            print("TBD: x=0")
        case .STO:
            prefix = .STO_MUL
        case .RCL:
            prefix = .RCL_MUL
        default:
            // perform operation without prefix
            prefix = nil
            performOperationFor(keyName)
        }
    }
    
    @IBAction func rsButtonPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = keyNameFromButton(sender)

        switch prefix {
        case .none:
            // run/stop [program]
            if isProgramMode {
                // add to program
                sendToProgram(keyName)
            } else if !isRunMode {
                // run program from current line, to end (vs. running from a label, to end)
                isRunMode = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
                    if program.currentLineNumber == 0 { program.incrementCurrentLine() }  // allows starting from line 0
                    program.runFromCurrentLine()
                    isRunMode = false
                }
            }
        case .f:
            // PSE pressed (pause program)
            prefix = nil
            if isProgramMode {
                // add to program
                sendToProgram(keyName)
            }  // else (no action in run mode)
        case .g:
            // P/R pressed
            prefix = nil
            isProgramMode.toggle()
        default:
            // clear prefix and re-run
            prefix = nil
            rsButtonPressed(sender)
        }
    }
    
    @IBAction func gsbButtonPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = keyNameFromButton(sender)

        switch prefix {
        case .none:
            // GSB pressed
            if isProgramMode {
                // add to program
                sendToProgram(keyName)
            } else {
                // build-up to GSB n (run from label n)
                prefix = .GSB
            }
        case .f:
            // Σ pressed
            // from Handbook p.20: "Clears statistics storage registers, display, and
            // the memory stack (described in section 3)."
            prefix = nil
            if isProgramMode {
                // add to program
                sendToProgram(keyName)
            } else {
                brain.clearAll()  // pws: this clears too much
            }
        case .g:
            // RTN pressed
            prefix = nil
            if isProgramMode {
                // add to program
                sendToProgram(keyName)
            } else {
                // set program to line 0
                prepStackForOperation()
                program.currentLineNumber = 0
            }
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
    }
    
    @IBAction func leftArrowButtonPressed(_ sender: UIButton) {
        guard handleButton(sender) != nil else { return }

        var okToClearUserEnteringDigits = true
        var okToClearUserEnteringExponent = true

        switch prefix {
        case .none:
            // ← key pressed (remove single digit or whole number)
            if userIsEnteringExponent {
                if displayStringExponent == "00" {
                    // exponent = "00" - remove it
                    displayString = displayString.components(separatedBy: " ")[0]
                    userIsEnteringExponent = false
                    okToClearUserEnteringDigits = false  // ie. user is still entering digits
                } else {
                    // exponent != "00" - slide first digit of exponent right and back-fill with 0
                    displayString.removeLast()
                    let firstExponentDigit = String(displayString.removeLast())
                    displayString += "0" + firstExponentDigit
                    okToClearUserEnteringExponent = false  // ie. user is still removing digits
                }
            } else {
                if !userIsEnteringDigits {
                    // display contains complete number - replace with 0.0
                    brain.xRegister = 0.0
                    liftStack = false
                } else if displayString.count > 1 {
                    // display contains partially entered number - remove last digit
                    displayString = String(displayString.dropLast())
                    okToClearUserEnteringDigits = false  // ie. user is still entering digits
                } else {
                    // display has one digit left - push 0.0 onto stack
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
            // CLx key pressed
            prefix = nil
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
                endDisplayEntry()
                brain.pushXRegister()
            }
        case .f:
            // RND# pressed
            prefix = nil
            srand48(seed)  // re-seed each time, so a manually stored seed will generate the same sequence each time
            let number = drand48()
            seed = Int(number * Double(Int32.max))  // regenerate my own seed to use next time (Note: Int.max gives same numbers for different seeds)
            if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
            displayString = String(number)
            brain.pushOperand(number)
            lastRandomNumberGenerated = number
        case .g:
            // LSTx pressed
            prefix = nil
            brain.pushOperand(brain.lastXRegister)
        case .STO:
            // STO RAN# pressed (store new seed)
            prefix = nil
            if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
            if var number = brain.xRegister {
                number = min(max(number, 0.0), 0.9999999999)  // limit 0.0 <= number < 1.0
                seed = Int(number * Double(Int32.max))
            } else {
                return
            }
        case .RCL:
            // RCL RAN# pressed (recall last random number)
            prefix = nil
            brain.pushOperand(lastRandomNumberGenerated)
        default:
            return
        }
        updateDisplayString()
        brain.printMemory()
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        liftStack = false
    }
    
    @IBAction func oneButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            // 1: →R pressed (convert to rectangular coordinates)
            self.performOperationFor(keyName)
        }
        let gAction = {
            // 1: →P pressed (convert to polar coordinates)
            self.performOperationFor(keyName)
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func twoButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            // 2: →H.MS pressed (convert from decimal hours H.HHHH to hours-minutes-seconds-decimal seconds H.MMSSsssss)
            self.performOperationFor(keyName)
        }
        let gAction = {
            // 2: →H pressed (convert from hours-minutes-seconds-decimal seconds H.MMSSsssss to decimal hours H.HHHH)
            self.performOperationFor(keyName)
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func threeButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            // 3: →RAD pressed
            self.performOperationFor(keyName)
        }
        let gAction = {
            // 3: →DEG pressed
            self.performOperationFor(keyName)
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func subtractButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

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
            prefix = nil
            print("TBD: TEST")
        case .STO:
            prefix = .STO_SUB
        case .RCL:
            prefix = .RCL_SUB
        default:
            // perform operation without prefix
            prefix = nil
            performOperationFor(keyName)
        }
    }
    
    @IBAction func onButtonPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        _ = restoreFromError()  // ON is the only key that finishes performing its function, if restoring from error
        
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
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = keyNameFromButton(sender)

        if isProgramMode {
            sendToProgram(keyName)
            // continue processing prefix for use with program keys, ex. f-R/S (PSE)
        }

        prefix = .f
    }
    
    @IBAction func gButtonPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = keyNameFromButton(sender)

        if isProgramMode {
            sendToProgram(keyName)
            // continue processing prefix for use with program keys, ex. g-SST (BST)
        }

        prefix = .g
    }
    
    @IBAction func stoButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        switch prefix {
        case .f:
            // "FRAC" pressed
            performOperationFor(keyName)
        case .g:
            // "INT" pressed
            performOperationFor(keyName)
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
        guard let keyName = handleButton(sender) else { return }

        let fAction = {
            self.prefix = nil
            print("TBD: x!")
        }
        let gAction = {
            self.prefix = nil
            print("TBD: xbar")
        }
        handleNumberedButton(keyName, fAction: fAction, gAction: gAction)
    }
    
    @IBAction func decimalPointButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

        switch prefix {
        case .none:
            handleDigitEntry(keyName: keyName)
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
        case .GSB:
            prefix = .GSB_DOT
        case .GTO:
            prefix = .GTO_DOT
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
    
    @IBAction func addButtonPressed(_ sender: UIButton) {
        guard let keyName = handleButton(sender) else { return }

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
            prefix = nil
            print("TBD: Py,x")
        case .STO:
            prefix = .STO_ADD
        case .RCL:
            prefix = .RCL_ADD
        default:
            // perform operation without prefix
            prefix = nil
            performOperationFor(keyName)
        }
    }

    // MARK: - Button action utilities
    
    private func keyNameFromButton(_ button: UIButton) -> String {
        var keyName = button.currentTitle!
        if keyName == "·" { keyName = "." } // replace "MIDDLE DOT" (used on button in interface builder) with period
        return keyName
    }
    
    private func handleButton(_ button: UIButton) -> String? {
        simulatePressingButton(button)
        if restoreFromError() { return nil }
        let keyName = keyNameFromButton(button)
        
        if isProgramMode {
            sendToProgram(keyName)
            prefix = nil
            return nil
        }
        return keyName
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
    
    private func performOperationFor(_ keyName: String) {
        prepStackForOperation()
        brain.lastXRegister = brain.xRegister!  // save xRegister before pushing operation onto stack
        
        let oneLetterPrefix = (prefix?.rawValue ?? "n")  // n, f, g, H, or h
        prefix = nil  // must come after previous line
        //-------------------------------------------------
        brain.performOperation(oneLetterPrefix + keyName)
        //-------------------------------------------------
        updateDisplayString()
    }
    
    private func runProgramFrom(label: String) {
        isRunMode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
            program.runFrom(label: label) {
                self.isRunMode = false
            }
        }
    }
    
    private func setDisplayFormatTo(_ format: DisplayFormat) {
        if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
        displayFormat = format
        updateDisplayString()
    }
    
    private func handleNumberedButton(_ keyName: String, fAction: () -> Void, gAction: () -> Void) {
        switch prefix {
        case .none:
            handleDigitEntry(keyName: keyName)
        case .f:
            fAction()
        case .g:
            gAction()
        case .FIX:
            prefix = nil
            setDisplayFormatTo(.fixed(Int(keyName)!))
        case .SCI:
            prefix = nil
            setDisplayFormatTo(.scientific(min(Int(keyName)!, 6)))  // 1 sign + 1 mantissa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
        case .ENG:
            prefix = nil
            setDisplayFormatTo(.engineering(min(Int(keyName)!, 6)))  // 1 sign + 1 mantissa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
        case .SF:
            prefix = nil
            if keyName == "8" {  // flag 8 is complex mode
                isComplexMode = true
            }
        case .CF:
            prefix = nil
            if keyName == "8" {  // flag 8 is complex mode
                isComplexMode = false
            }
        case .GTO:
            prefix = nil
            if !program.gotoLabel(keyName) {  // would only be here in non-program mode
                setError(4)
            }
        case .GTO_DOT:
            prefix = nil
            if !program.gotoLabel("." + keyName) {  // would only be here in non-program mode
                setError(4)
            }
        case .GTO_CHS:
            handleGotoLineNumberDigit(digit: Int(keyName)!)
        case .GSB:
            prefix = nil
            runProgramFrom(label: keyName)
        case .GSB_DOT:
            prefix = nil
            runProgramFrom(label: "." + keyName)
        case .STO:
            prefix = nil
            storeDisplayToRegister(keyName)
            liftStack = true
        case .STO_DOT:
            prefix = nil
            storeDisplayToRegister("DOT" + keyName)
            liftStack = true
        case .RCL:
            prefix = nil
            recallRegister(keyName)
            liftStack = true
        case .RCL_DOT:
            prefix = nil
            recallRegister("DOT" + keyName)
            liftStack = true
        case .STO_ADD:
            prefix = nil
            applyDisplayToRegister(keyName, using: { $0 + $1 })
            liftStack = true
        case .STO_SUB:
            prefix = nil
            applyDisplayToRegister(keyName, using: { $0 - $1 })
            liftStack = true
        case .STO_MUL:
            prefix = nil
            applyDisplayToRegister(keyName, using: { $0 * $1 })
            liftStack = true
        case .STO_DIV:
            prefix = nil
            applyDisplayToRegister(keyName, using: { $0 / $1 })
            liftStack = true
        case .RCL_ADD:
            prefix = nil
            applyRegisterToDisplay(keyName, using: { $0 + $1 })
            liftStack = true
        case .RCL_SUB:
            prefix = nil
            applyRegisterToDisplay(keyName, using: { $0 - $1 })
            liftStack = true
        case .RCL_MUL:
            prefix = nil
            applyRegisterToDisplay(keyName, using: { $0 * $1 })
            liftStack = true
        case .RCL_DIV:
            prefix = nil
            applyRegisterToDisplay(keyName, using: { $0 / $1 })
            liftStack = true
        default:
            break
        }
    }
    
    // use for buttons 0-9, ., EEX (without prefix)
    private func handleDigitEntry(keyName: String) {
        if keyName == "EEX" {
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
            if !(keyName == "." && (decimalWasAlreadyEntered || userIsEnteringExponent)) {
                if userIsEnteringExponent {
                    // slide second digit of exponent left and put new digit in its place
                    let secondExponentDigit = String(displayString.removeLast())
                    displayString.removeLast()
                    displayString += secondExponentDigit + keyName
                } else {
                    //--------------------------------------------------------
                    displayString += keyName  // append entered digit to display
                    //--------------------------------------------------------
                }
            }
        } else {
            // start clean display with digit
            if keyName == "." {
                displayString = "0."  // precede leading decimal point with a zero
            } else {
                displayString = keyName
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
    
    // call with register name "0" - "9", ".0" - ".9"
    private func storeDisplayToRegister(_ registerName: String) {
        if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
        brain.storeResultInRegister(registerName, result: brain.xRegister!)
        updateDisplayString()
        brain.printMemory()
    }
    
    // call with register name "0" - "9", ".0" - ".9"
    private func recallRegister(_ registerName: String) {
        if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
        displayString = String(brain.recallNumberFromStorageRegister(registerName))
        brain.pushOperand(displayStringNumber)
        updateDisplayString()
        brain.printMemory()
    }
    
    private func applyDisplayToRegister(_ registerName: String, using operation: ((Double, Double) -> Double)) {
        if userIsEnteringDigits {
            brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
            userIsEnteringDigits = false
            userIsEnteringExponent = false
        }
        let result = operation(brain.recallNumberFromStorageRegister(registerName), brain.xRegister!)
        if result.isNaN || result.isInfinite {
            displayString = "nan"  // triggers displayView to show "  Error  0"
        } else {
            brain.storeResultInRegister(registerName, result: result)
            updateDisplayString()
        }
        brain.printMemory()
    }
    
    private func applyRegisterToDisplay(_ register: String, using operation: ((Double, Double) -> Double)) {
        if userIsEnteringDigits {
            brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
            userIsEnteringDigits = false
            userIsEnteringExponent = false
        }
        let result = operation(brain.xRegister!, brain.recallNumberFromStorageRegister(register))
        if result.isNaN || result.isInfinite {
            displayString = "nan"  // triggers displayView to show "  Error  0"
        } else {
            brain.xRegister = result
            updateDisplayString()
        }
        brain.printMemory()
    }

    // MARK: - Simulated button
    
    // All button actions trigger on Touch Down (see header notes).  SimulatePressingButton plays
    // a click sound and darkens the button text, then creates a temporary target for Touch Up
    // Inside, which gets called when the button is released (calling simulateReleasingButton).
    private func simulatePressingButton(_ button: UIButton) {
        guard useSimButton else { return }
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
            self.brain.swapRealImag()
            self.updateDisplayString()
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
        program.runCurrentInstruction()
        _ = program.forwardStep()
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
