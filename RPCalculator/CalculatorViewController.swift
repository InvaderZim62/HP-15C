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
//  Useful functions...
//     let lastDigit = displayString.removeLast()     // remove last digit and return it
//     displayString.removeLast(n)                    // removes last n digits without returning them
//     displayString = String(format: displayFormat.string, 0.0)  // write number to display in current format
//     displayString = displayString.padding(toLength: 9, withPad: " ", startingAt: 0) + "00"  // pad end of string with blanks
//
//  To do...
//  - implement RND key (round mantissa to displayed digits)
//  - some numbers don't allow entering exponent EEX (ex. 12345678 EEX doesn't, 1234567 EEX does, 1.2345678 EEX does)
//  - p59 rounding displayed scientific numbers not implemented
//  - p61 swapping "." and "," in displaying number is not implemented
//  - make display blink when +/-overflow (9.999999 99) ex. 1 EEX 99 Enter 10 x
//  - on real HP-15C, following overflow, entering <- key causes blinking to stop, but leaves 9.999999 99 in display (xRegister)
//  - p61 implement underflow (displays 0.0)
//  - backspace key doesn't restore display after ERROR
//  - HP-15C resets prefix (f, g) and program mode during power cycle
//  - stop program if any key pressed
//  - p90 implement program branching and control
//

import UIKit
import AVFoundation  // needed for AVAudioPlayer

struct Pause {
    static let time = 1.2
}

enum Prefix: String {
    case f  // function above button (orange)
    case g  // function below button (blue)
    case LBL  // ex. f LBL A (label in program)
    case GTO  // ex. GTO 5 (goto label 5)
    case GTO_CHS  // ex. GTO CHS nnn (go to line nnn) - needs three digits
    case SOLVE  // ex. f SOLVE A (solve for roots of equation starting at label A)
    case FIX  // ex. f FIX 4 (format numbers in fixed-point with 4 decimal places)
    case SCI
    case ENG
    case HYP = "H"  // ex. f HYP SIN (hyperbolic sine)
    case HYP1 = "h"  // ex. g HYP1 SIN (inverse hyperbolic sine)
    case SF  // ex. g SF 8 (set flag 8 - enable complex mode)
    case CF  // ex. g CF 8 (clear flag 8 - disable complex mode)
    case STO
    case STO_DOT  // ex. STO . 0 (.0 - .9 are valid storage registers)
    case STO_ADD  // ex. 4 STO + 1 (ADD 4 to register 1)
    case STO_SUB
    case STO_MUL
    case STO_DIV
    case RCL
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
        userIsEnteringDigits = defaults.bool(forKey: "userIsEnteringDigits")
        userIsEnteringExponent = defaults.bool(forKey: "userIsEnteringExponent")
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
    
    // Note: It's somewhat arbitrary which action each button is assigned to (digitKeyPressed, operationKeyPressed,
    // stackManipulationKeyPressed).  Obvious ones are enterKeyPressed, prefixKeyPressed, and onKeyPressed.  In some
    // cases, the prefix function of the key is not well suited to the same action as the primary function of the key
    // (ex. f-1, f-2, f-3, g-1, g-2, g-3).  In those cases, it is passed to another action using a temporary button.

    // update display with digit pressed
    // digit keys: 0-9, ·, EEX  (Note: EEX is considered a digit key for pi)
    @IBAction func digitKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        var keyName = sender.currentTitle!
        if keyName == "·" { keyName = "." } // replace "MIDDLE DOT" (used on button in interface builder) with period
        
        if isProgramMode {
            sendToProgram(keyName)
            prefix = nil
            return
        }

        switch prefix {
        case .none:
            // digit pressed (without prefix)
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
                        let exponent2 = String(displayString.removeLast())
                        displayString.removeLast(1)
                        displayString += exponent2 + keyName
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
        case .f:
            prefix = nil
            switch keyName {
            case "1":
                // →R pressed (convert to rectangular coordinates)
                let tempButton = UIButton()
                tempButton.setTitle("1", for: .normal)
                prefix = .f
                operationKeyPressed(tempButton)  // better handled as operation
            case "2":
                // →H.MS pressed (convert from decimal hours H.HHHH to hours-minutes-seconds-decimal seconds H.MMSSsssss)
                let tempButton = UIButton()
                tempButton.setTitle("2", for: .normal)
                prefix = .f
                operationKeyPressed(tempButton)  // better handled as operation
            case "3":
                // →RAD pressed
                let tempButton = UIButton()
                tempButton.setTitle("3", for: .normal)
                prefix = .f
                operationKeyPressed(tempButton)  // better handled as operation
            case "7":
                // FIX pressed
                prefix = .FIX  // wait for next digit
            case "8":
                // SCI pressed
                prefix = .SCI  // wait for next digit
            case "9":
                // ENG pressed
                prefix = .ENG  // wait for next digit
            default:
                break
            }
        case .g:
            prefix = nil
            switch keyName {
            case "1":
                // →P pressed (convert to polar coordinates)
                let tempButton = UIButton()
                tempButton.setTitle("1", for: .normal)
                prefix = .g
                operationKeyPressed(tempButton)  // better handled as operation
            case "2":
                // →H pressed (convert from hours-minutes-seconds-decimal seconds H.MMSSsssss to decimal hours H.HHHH)
                let tempButton = UIButton()
                tempButton.setTitle("2", for: .normal)
                prefix = .g
                operationKeyPressed(tempButton)  // better handled as operation
            case "3":
                // →DEG pressed
                let tempButton = UIButton()
                tempButton.setTitle("3", for: .normal)
                prefix = .g
                operationKeyPressed(tempButton)  // better handled as operation
            case "4":
                // SF pressed (set flag)
                prefix = .SF
            case "5":
                // CF pressed (clear flag)
                prefix = .CF
            case "7":
                trigMode = .DEG
            case "8":
                trigMode = .RAD
            case "9":
                trigMode = .GRAD
            case "EEX":
                // pi pressed
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayString = String(Double.pi)  // 3.141592653589793
                brain.pushOperand(Double.pi)
                updateDisplayString()
            default:
                break
            }
        case .GTO:
            switch keyName {
            case ".":
                print("GTO .")  // pws: goto label starting with "."?
            case "EEX":
                // EEX pressed - clear GTO and perform EEX
                prefix = nil
                let tempButton = UIButton()
                tempButton.setTitle("EEX", for: .normal)
                digitKeyPressed(tempButton)
            default:
                prepStackForOperation()
                setError(4)
            }
        case .GTO_CHS:
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                gotoLineNumberDigits.append(Int(keyName)!)
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
            default:
                // ".", "EXE" - resend without prefix
                prefix = nil
                gotoLineNumberDigits = []
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
        case .FIX:
            prefix = nil
            if let decimalPlaces = Int(keyName) {
                // number after FIX pressed
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayFormat = .fixed(decimalPlaces)
                updateDisplayString()
            } else {
                // if not a number, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
        case .SCI:
            prefix = nil
            if let decimalPlaces = Int(keyName) {
                // number after SCI pressed
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayFormat = .scientific(min(decimalPlaces, 6))  // 1 sign + 1 mantissa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
                updateDisplayString()
            } else {
                // if not a number, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
        case .ENG:
            prefix = nil
            if let additionalDigits = Int(keyName) {
                // number after ENG pressed
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayFormat = .engineering(min(additionalDigits, 6))  // 1 sign + 1 significant + 6 additional + 1 exponent sign + 2 exponents = 11 digits
                updateDisplayString()
            } else {
                // if not a number, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
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
        case .STO:
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // store displayed number in register
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.storeResultInRegister(keyName, result: brain.xRegister!)
                updateDisplayString()
                brain.printMemory()
            case "EEX":
                prepStackForOperation()
                setError(11)
            case ".":
                // STO .
                let tempButton = UIButton()
                tempButton.setTitle(".", for: .normal)
                prefix = .STO
                prefixKeyPressed(tempButton)  // better handled as prefix key
                return
            default:
                setError(99)
            }
            liftStack = true
        case .STO_DOT:
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // store displayed number in register
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.storeResultInRegister("DOT" + keyName, result: brain.xRegister!)
                updateDisplayString()
                brain.printMemory()
            case "EEX":
                // give up on STO . and re-enter EEX
                prepStackForOperation()
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            case ".":
                // give up on STO . and re-enter "."
                let tempButton = UIButton()
                tempButton.setTitle(".", for: .normal)
                digitKeyPressed(tempButton)
            default:
                setError(99)
            }
            liftStack = true
        case .RCL:
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // recall register, show in display
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayString = String(brain.recallNumberFromStorageRegister(keyName))
                brain.pushOperand(displayStringNumber)
                updateDisplayString()
                brain.printMemory()
            case "EEX":
                prepStackForOperation()
                setError(99)  // pws: actually RCL EEX displays "A      0  0" (not sure what this is)
            case ".":
                // RCL .
                let tempButton = UIButton()
                tempButton.setTitle(".", for: .normal)
                prefix = .RCL
                prefixKeyPressed(tempButton)  // better handled as prefix key
                return
            default:
                setError(99)
            }
            liftStack = true
        case .RCL_DOT:
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // recall register, show in display
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayString = String(brain.recallNumberFromStorageRegister("DOT" + keyName))
                brain.pushOperand(displayStringNumber)
                updateDisplayString()
                brain.printMemory()
            case "EEX":
                // give up on RCL . and re-enter EEX
                prepStackForOperation()
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            case ".":
                // give up on RCL . and re-enter "."
                let tempButton = UIButton()
                tempButton.setTitle(".", for: .normal)
                digitKeyPressed(tempButton)
            default:
                setError(99)
            }
            liftStack = true
        case .STO_ADD:
            // STO + register
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add displayed number to register
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.recallNumberFromStorageRegister(keyName) + brain.xRegister!
                brain.storeResultInRegister(keyName, result: result)
                updateDisplayString()
                brain.printMemory()
            default:
                // if not a valid register name, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
            liftStack = true
        case .STO_SUB:
            // STO - register
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // subtract displayed number from register
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.recallNumberFromStorageRegister(keyName) - brain.xRegister!
                brain.storeResultInRegister(keyName, result: result)
                updateDisplayString()
                brain.printMemory()
            default:
                // if not a valid register name, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
            liftStack = true
        case .STO_MUL:
            // STO × register
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // multiply register by displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.recallNumberFromStorageRegister(keyName) * brain.xRegister!
                brain.storeResultInRegister(keyName, result: result)
                updateDisplayString()
                brain.printMemory()
            default:
                // if not a valid register name, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
            liftStack = true
        case .STO_DIV:
            // STO ÷ register
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // divided register by displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.recallNumberFromStorageRegister(keyName) / brain.xRegister!
                if result.isNaN || result.isInfinite {  // pws: also need this check for .ADD, .SUB, .MUL (ex. 1E99 in Reg 1, 10 STO x 1 causes overflow)
                    displayString = "nan"  // triggers displayView to show "  Error  0"
                } else {
                    brain.storeResultInRegister(keyName, result: result)
                    updateDisplayString()
                }
                brain.printMemory()
            default:
                // if not a valid register name, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
            liftStack = true
        case .RCL_ADD:
            // RCL + register
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add register to displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                brain.xRegister! += brain.recallNumberFromStorageRegister(keyName)
                updateDisplayString()
                brain.printMemory()
            default:
                // if not a valid register name, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
            liftStack = true
        case .RCL_SUB:
            // RCL - register
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add register to displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                brain.xRegister! -= brain.recallNumberFromStorageRegister(keyName)
                updateDisplayString()
                brain.printMemory()
            default:
                // if not a valid register name, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
            liftStack = true
        case .RCL_MUL:
            // RCL × register
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add register to displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                brain.xRegister! *= brain.recallNumberFromStorageRegister(keyName)
                updateDisplayString()
                brain.printMemory()
            default:
                // if not a valid register name, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
            liftStack = true
        case .RCL_DIV:
            // RCL ÷ register
            prefix = nil
            switch keyName {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add register to displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.xRegister! / brain.recallNumberFromStorageRegister(keyName)
                if result.isNaN || result.isInfinite {  // pws: also need this check for .ADD, .SUB, .MUL (ex. 1E99 in Reg 1, 10 REC x 1 causes overflow)
                    displayString = "nan"  // triggers displayView to show "  Error  0"
                } else {
                    brain.xRegister = result
                    updateDisplayString()
                }
                brain.printMemory()
            default:
                // if not a valid register name, ignore prefix and resend digit (EEX or .)
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                digitKeyPressed(tempButton)
            }
            liftStack = true
        default:  // .HYP, .HYP1 (not allowed to precede stack manipulation key)
            invalidKeySequenceEntered()
        }
    }
    
    // perform selected operation, and display results
    // Note: most of the real operators are not handled in the large switch statement;
    // they fall through (using break statements) to be sent to brain.performOperation
    //
    // operation keys: √x, ex, 10x, yx, 1/x, CHS, SIN, COS, TAN, ÷, ×, -, +
    // operations sent from digitKeyPressed: f-1 (→R), f-2 (→H.MS), f-3 (→RAD), g-1 (→P), g-2 (→H), g-3 (→DEG)
    // operations sent from prefixKeyPressed: f-STO (FRAC), g-STO (INT)
    @IBAction func operationKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = sender.currentTitle!
        
        if isProgramMode {
            sendToProgram(keyName)
            prefix = nil
            return
        }

        if isUserMode {
            // swap the primary functions and f-shifted functions of keys A-E
            switch keyName {
            case "√x", "ex", "10x", "yx", "1/x":
                if prefix == nil {
                    prefix = .f
                } else if prefix == .f {
                    prefix = nil
                }
            default:
                break
            }
        }
        
        switch prefix {
        case .none:
            switch keyName {
            case "CHS":
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
            default:
                break
            }
        case .STO:
            // STO [+|–|×|÷]
            switch keyName {
            case "+":
                prefix = .STO_ADD  // ex. add display to number stored in register (next key)
            case "–":  // minus sign is an "EN DASH"
                prefix = .STO_SUB
            case "×":
                prefix = .STO_MUL
            case "÷":
                prefix = .STO_DIV
            default:
                prepStackForOperation()
                setError(3)
                return
            }
            return
        case .STO_DOT:
            // STO . operation (give up on STO . and re-issue operation)
            prefix = nil
            let tempButton = UIButton()
            tempButton.setTitle(keyName, for: .normal)
            operationKeyPressed(tempButton)
            return
        case .RCL:
            // RCL [+|–|×|÷]
            switch keyName {
            case "+":
                prefix = .RCL_ADD  // ex. add register (next key) to display
            case "–":  // minus sign is an "EN DASH"
                prefix = .RCL_SUB
            case "×":
                prefix = .RCL_MUL
            case "÷":
                prefix = .RCL_DIV
            default:
                prepStackForOperation()
                setError(3)
                return
            }
            return
        case .RCL_DOT:
            // RCL . operation (give up on RCL . and re-issue operation)
            prefix = nil
            let tempButton = UIButton()
            tempButton.setTitle(keyName, for: .normal)
            operationKeyPressed(tempButton)
            return
        case .f:
            switch keyName {
            case "COS":
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
            case "TAN":
                // "I" pressed (imaginary number entered)
                prefix = nil
                isComplexMode = true
                prepStackForOperation()
                //----------------------
                brain.moveRealXToImagX()
                //----------------------
                displayString = String(brain.xRegister!)  // show real part
                updateDisplayString()
                return
            case "–":  // minus sign is an "EN DASH"
                // "Re≷Im" pressed (swap real and imaginary parts of complex number)
                prefix = nil
                isComplexMode = true
                prepStackForOperation()
                //------------------
                brain.swapRealImag()
                //------------------
                updateDisplayString()
                return
            case "√x", "ex", "10x", "yx", "1/x":
                // label "A" - "E" pressed
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                programKeyPressed(tempButton)  // better handled as program key
                return
            case "÷":
                // SOLVE pressed
                let tempButton = UIButton()
                tempButton.setTitle("÷", for: .normal)
                prefixKeyPressed(tempButton)  // better handled as prefix key
                return
            default:
                break
            }
        case .SOLVE:
            switch keyName {
            case "√x", "ex", "10x", "yx", "1/x":
                // label "A" - "E" pressed
                let tempButton = UIButton()
                tempButton.setTitle(keyName, for: .normal)
                programKeyPressed(tempButton)  // better handled as program key
                return
            default:
                break
            }
        case .g, .HYP, .HYP1:  // allowed to precede operation key (ex. g-10x, f-HYP-SIN, f-HYP1-COS)
            break
        case .GTO:
            switch keyName {
            case "CHS":
                // goto line number
                let tempButton = UIButton()
                tempButton.setTitle("CHS", for: .normal)
                prefixKeyPressed(tempButton)  // better handled as prefix key
                return
            case "√x":
                // do nothing (just add to stack)
                prefix = nil
                prepStackForOperation()
                return
            case "SIN", "COS", "÷", "×", "-", "+", "→R", "→P", "→H.MS", "→H", "→RAD", "→DEG":
                // perform operation without prefix
                prefix = nil
            default:
                prepStackForOperation()
                setError(4)
                return
            }
        case .STO_ADD, .STO_SUB, .STO_MUL, .STO_DIV, .RCL_ADD, .RCL_SUB, .RCL_MUL, .RCL_DIV:  // not allowed to precede operation key
            prepStackForOperation()
            setError(3)
            return
        default:  // .FIX, .SCI, .ENG, .RCL (these ignore the prefix) ex. 2 Enter 3 f FIX x, just does 2 Enter 3 x (= 6)
            prefix = nil
        }
        
        prepStackForOperation()
        brain.lastXRegister = brain.xRegister!  // save xRegister before pushing operation onto stack
        
        let oneLetterPrefix = (prefix?.rawValue ?? "n")  // n, f, g, H, or h
        prefix = nil  // must come after previous line
        //-------------------------------------------------
        brain.performOperation(oneLetterPrefix + keyName)
        //-------------------------------------------------
        updateDisplayString()
    }

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterKeyPressed(_ sender: UIButton) {
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
    
    // manipulate stack or display
    // stack manipulation keys: R↓, x≷y, ←
    @IBAction func stackManipulationKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = sender.currentTitle!
        
        if isProgramMode {
            sendToProgram(keyName)
            prefix = nil
            return
        }

        var okToClearUserEnteringDigits = true

        switch prefix {
        case .none:
            switch keyName {
            case "R↓":
                // R↓ key pressed (roll stack down)
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.rollStack(directionDown: true)
            case "x≷y":
                // x≷y key pressed (swap x-y registers)
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.swapXyRegisters()
            case "←":
                // ← key pressed (remove single digit or whole number)
                if userIsEnteringExponent {
                    return
                } else {
                    if !userIsEnteringDigits {
                        // clear previously entered number (display 0.0)
                        brain.xRegister = 0.0
                        liftStack = false
                    } else if displayString.count > 1 {
                        // remove one digit
                        displayString = String(displayString.dropLast())
                        okToClearUserEnteringDigits = false  // ie. user is still entering digits
                    } else {
                        // push 0.0 onto stack
                        brain.pushOperand(0.0)
                        liftStack = false  // not sure if this is needed
                        brain.printMemory()
                    }
                }
            default:
                break
            }
        case .f:
            switch keyName {
            case "GSB":
                brain.clearAll()
            case "R↓":
                // CLEAR PRGM pressed (goto line 0 without delete program)
                program.currentLineNumber = 0
            case "x≷y":
                // CLEAR REG key pressed (clear storage registers, not stack)
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.clearStorageRegisters()
            case "←":
                // CLEAR PREFIX key pressed
                // display mantissa (all numeric digits with no punctuation), until 1.2 sec after button is released
                prefix = nil
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayView.showCommas = false
                displayString = brain.displayMantissa
                sender.addTarget(self, action: #selector(clearPrefixButtonReleased), for: .touchUpInside)
                return
            default:
                break
            }
        case .g:
            switch keyName {
            case "R↓":
                // R↑ key pressed (roll stack up)
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.rollStack(directionDown: false)
            case "←":
                // CLx key pressed
                displayString = String(format: displayFormat.string, 0.0)  // display 0.0
                if userIsEnteringDigits {
                    brain.pushOperand(0)
                } else {
                    brain.xRegister = 0
                }
                liftStack = false
                userIsEnteringDigits = false
                userIsEnteringExponent = false
                prefix = nil
                saveDefaults()
                brain.printMemory()
                return  // return, or prior number will be displayed
            default:
                break
            }
        default:  // .FIX, .SCI, .ENG, .STO, .RCL, .HYP, .HYP1 (not allowed to precede stack manipulation key)
            invalidKeySequenceEntered()
            return
        }
        if okToClearUserEnteringDigits {
            userIsEnteringDigits = false
            updateDisplayString()
        }
        userIsEnteringExponent = false
        prefix = nil
    }

    // set prefix to .f (for "f"), .g (for "g"), .GTO (for "GTO"), .HYP (for f-"GTO"), .HYP1 (for g-"GTO"),...
    // prefix keys: f, g, STO, RCL
    // prefix sent from programKeyPressed: GTO
    // prefix sent from operationKeyPressed: CHS (for GTO-CHS), or ÷ (for f-"÷")
    // prefix sent from digitKeyPressed: . (for STO-".", or RCL-".")
    @IBAction func prefixKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = sender.currentTitle!
        
        if isProgramMode {
            sendToProgram(keyName)
            // continue processing prefix for use in
        }

        switch prefix {
        case .none:
            switch keyName {
            case "f":
                prefix = .f
            case "g":
                prefix = .g
            case "STO":
                prefix = .STO
            case "RCL":
                prefix = .RCL
            case "GTO":
                prefix = .GTO  // build-up to GTO n (go to label n) or GTO CHS nnn (go to line nnn)
            default:
                break
            }
        case .f:
            switch keyName {
            case "g":
                prefix = .g
            case "STO":
                // "FRAC" pressed
                let tempButton = UIButton()
                tempButton.setTitle("STO", for: .normal)
                prefix = .f
                operationKeyPressed(tempButton)  // better handled as operation
            case "RCL":
                // "USER" pressed (swap the primary functions and f-shifted functions of keys A-E)
                prefix = nil
                isUserMode.toggle()
            case "GTO":
                if isProgramMode {
                    prefix = nil
                } else {
                    prefix = .HYP
                }
            case "÷":
                // "SOLVE" pressed
                prefix = .SOLVE
            default:
                break
            }
        case .g:
            switch keyName {
            case "f":
                prefix = .f
            case "STO":
                // "INT" pressed
                let tempButton = UIButton()
                tempButton.setTitle("STO", for: .normal)
                prefix = .g
                operationKeyPressed(tempButton)  // better handled as operation
            case "RCL":
                // "MEM" pressed
                print("MEM")  // pws: TBD
            case "GTO":
                if isProgramMode {
                    prefix = nil
                } else {
                    prefix = .HYP1
                }
            default:
                break
            }
        case .STO:
            switch keyName {
            case "f":
                prefix = .f  // pws: HP-15C shows f after STO f, so what is STO f ENTER?
            case "g":
                prefix = .g
            case ".":
                prefix = .STO_DOT
            case "RCL":
                prefix = .RCL
            case "GTO":
                print("STO GTO")  // pws: not sure what this is
            default:
                setError(99)  // shouldn't get here
            }
        case .RCL:
            switch keyName {
            case "f":
                prefix = .f
            case "g":
                prefix = .g
            case ".":
                prefix = .RCL_DOT
            case "STO":
                prefix = .STO
            default:
                invalidKeySequenceEntered()
            }
        case .GTO:
            switch keyName {
            case "f":
                prefix = .f
            case "g":
                prefix = .g
            case "STO":
                prefix = .STO
            case "RCL":
                prefix = .RCL
            case "CHS":
                prefix = .GTO_CHS
                gotoLineNumberDigits = []
            default:
                setError(99)  // shouldn't get here
            }
        case .GTO_CHS:
            gotoLineNumberDigits = []
            switch keyName {
            case "f":
                prefix = .f
            case "g":
                prefix = .g
            case "STO":
                prefix = .STO
            case "RCL":
                prefix = .RCL
            case "GTO":
                prefix = .GTO
            default:
                setError(99)  // shouldn't get here
            }
        default:  // .FIX, .SCI, .ENG, .HYP, .HYP1 (not allowed to precede prefix key)
            invalidKeySequenceEntered()
        }
    }

    // program manipulation keys: SST, GTO, R/S, GSB
    // sent from operationKeyPressed: √x, ex, 10x, yx, 1/x (ex. f-√x for label A, or f-SOLVE-√x for solve label A)
    @IBAction func programKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = sender.currentTitle!

        switch prefix {
        case .none:
            switch keyName {
            case "SST":  // non-programmable
                // single-step
                if isProgramMode {
                    // single-step program
                    displayString = program.forwardStep()
                } else {
                    // while holding down SST button, display current line of code;
                    // after releasing SST: 1) execute current line, 2) display results, 3) increment current line (don't show)
                    saveDisplayString = displayString
                    displayString = program.currentInstruction
                    sender.addTarget(self, action: #selector(sstButtonReleased), for: .touchUpInside)
                }
            case "GTO":
                // build-up to GTO CHS nnn (go to line nnn)
                let tempButton = UIButton()
                tempButton.setTitle("GTO", for: .normal)
                prefixKeyPressed(tempButton)  // better handled as prefix key
            case "R/S":
                // run/stop [program]
                if isProgramMode {
                    // add to program
                    sendToProgram(keyName)
                } else if !isRunMode {
                    // run program from current line
                    isRunMode = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
                        if program.currentLineNumber == 0 { program.incrementCurrentLine() }  // allows starting from line 0
                        program.runFromCurrentLine() { }
                    }
                }
            case "GSB":
                print("GSB")  // pws: TBD
            default:
                break
            }
        case .f:
            prefix = nil
            switch keyName {
            case "√x", "ex", "10x", "yx", "1/x":
                // A - E pressed - run program from label A - E
                isRunMode = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
                    program.runFrom(label: keyName) { }
                }
            case "SST":
                // LBL pressed
                prefix = .LBL
                if isProgramMode {
                    // add to program
                    sendToProgram(keyName)
                }  // else (no action in run mode)
            case "GTO":
                // HYP pressed
                let tempButton = UIButton()
                tempButton.setTitle("GTO", for: .normal)
                prefix = .f
                prefixKeyPressed(tempButton)  // better handled as prefix key
            case "R/S":
                // PSE pressed (pause program)
                if isProgramMode {
                    // add to program
                    sendToProgram(keyName)
                }  // else (no action in run mode)
            default:
                break
            }
        case .g:
            prefix = nil
            switch keyName {
            case "SST":  // non-programmable
                // BST pressed (back step program)
                displayString = program.backStep()
                if !isProgramMode {
                    // show previous line until button released (don't execute), then return to normal display
                    sender.addTarget(self, action: #selector(bstButtonReleased), for: .touchUpInside)
                }
            case "GTO":
                // HYP-1 pressed
                let tempButton = UIButton()
                tempButton.setTitle("GTO", for: .normal)
                prefix = .g
                prefixKeyPressed(tempButton)  // better handled as prefix key
            case "R/S":
                // P/R pressed
                isProgramMode.toggle()
            case "GSB":
                // RTN pressed
                if isProgramMode {
                    // add to program
                    sendToProgram(keyName)
                } else {
                    // set program to line 0
                    prepStackForOperation()
                    program.currentLineNumber = 0
                }
            default:
                break
            }
        case .SOLVE:
            prefix = nil
            switch keyName {
            case "√x", "ex", "10x", "yx", "1/x":
                // A - E pressed - solve equation at label A - E
                isRunMode = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Pause.time) { [unowned self] in  // delay to show "running"
                    solve.findRootOfEquationAt(label: keyName)
                }
            default:
                break
            }
        default:
            break
        }
    }
    
    // hide/unhide display (emulating ON key)
    @IBAction func onKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        _ = restoreFromError()  // ON is the only key that finishes performing its function, if restoring from error
        calculatorIsOn = !calculatorIsOn
        displayView.turnOnIf(calculatorIsOn)
        if calculatorIsOn {
            prepStackForOperation()  // HP-15C completes number entry, if power is cycled
            restoreDisplayLabels()
            prefix = nil  // prefix is lost after re-start
            isProgramMode = false  // don't re-start in program mode
        } else {
            hideDisplayLabels()
        }
        buttons.forEach { $0.isUserInteractionEnabled = calculatorIsOn }
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
