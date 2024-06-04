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
//  - implement programming
//  - some numbers don't allow entering exponent EEX (ex. 12345678 EEX doesn't, 1234567 EEX does, 1.2345678 EEX does)
//  - p59 rounding displayed scientific numbers not implemented
//  - p61 swapping "." and "," in displaying number is not implemented
//  - make display blink when +/-overflow (9.999999 99) ex. 1 EEX 99 Enter 10 x
//  - on real HP-15C, following overflow, entering <- key causes blinking to stop, but leaves 9.999999 99 in display (xRegister)
//  - p61 implement underflow (displays 0.0)
//  - backspace key doesn't restore display after ERROR
//

import UIKit
import AVFoundation  // needed for AVAudioPlayer

enum Prefix: String {
    case f  // function above button (orange)
    case g  // function below button (blue)
    case FIX
    case SCI
    case ENG
    case STO
    case RCL
    case HYP = "H"  // hyperbolic trig function
    case HYP1 = "h"  // inverse hyperbolic trig function
    case STO_ADD  // ex. 4 STO + 1 (ADD 4 to register 1)
    case STO_SUB
    case STO_MUL
    case STO_DIV
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

class CalculatorViewController: UIViewController {
    
    var brain = CalculatorBrain()
    var clickSoundPlayer: AVAudioPlayer?
    var displayString = "" { didSet { displayView.displayString = displayString } }
    var displayFormat = DisplayFormat.fixed(4)
    var displayLabels = [UILabel]()
    var savedDisplayLabelAlphas = [CGFloat]()  // save for turning calculator Off/On
    var calculatorIsOn = true
    var liftStack = true  // false between pressing enter and an operation (determines overwriting or pushing xRegister)
    var userIsEnteringDigits = false
    var userIsEnteringExponent = false  // userIsEnteringExponent and userIsEnteringDigits can be true at the same time
    var buttonCoverViews = [UIButton: ButtonCoverView]()  // overlays buttons to provide text above and inside buttons
    var seed = 0  // HP-15C initial random number seed is zero
    var lastRandomNumberGenerated = 0.0
    
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
    
    var trigMode = TrigMode.DEG { didSet {
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
    } }
    
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
        "–": ("Re≷Im", "TEST"),
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
        brain.printStack()
        logoCircleView.layer.masksToBounds = true
        logoCircleView.layer.cornerRadius = logoCircleView.bounds.width / 2  // make it circular
        createButtonCovers()
    }

    private func saveDefaults() {  // pws: should I save seed and lastRandomNumberGenerated?
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(displayFormat) {
            defaults.set(data, forKey: "displayFormat")
        }
        defaults.set(displayString, forKey: "displayString")
        defaults.set(gradLabel.text, forKey: "gradLabelText")
        defaults.setValue(displayLabelAlphas, forKey: "displayLabelAlphas")
        if let data = try? JSONEncoder().encode(brain) {
            defaults.set(data, forKey: "brain")
        }
    }
    
    private func getDefaults() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "displayFormat") {
            displayFormat = try! JSONDecoder().decode(DisplayFormat.self, from: data)
        }
        displayString = defaults.string(forKey: "displayString") ?? String(format: displayFormat.string, 0.0)
        gradLabel.text = defaults.string(forKey: "gradLabelText") ?? gradLabel.text
        savedDisplayLabelAlphas = defaults.array(forKey: "displayLabelAlphas") as? [CGFloat] ?? displayLabelAlphas
        restoreDisplayLabels()
        if let data = defaults.data(forKey: "brain") {
            brain = try! JSONDecoder().decode(CalculatorBrain.self, from: data)
        }
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
    
    private func endDisplayEntry() {
        brain.xRegister = displayStringNumber
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        brain.printStack()
    }
    
    // set display string to xRegister (switch to scientific notation, if fixed format won't fit)
    private func updateDisplayString() {
        //--------------------------------------
        let numericalResult = brain.xRegister!
        //--------------------------------------

        var potentialDisplayString = String(format: displayFormat.string, numericalResult)  // may be "inf", "-inf", or "nan"
        if !numericalResult.description.contains("inf") && abs(numericalResult) > 9.999999999e99 {
            potentialDisplayString = numericalResult > 0 ? "+overflow" : "-overflow"
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
        displayString = "  Error  0"  // not sure what the real HP-15C displays
        brain.error = .badKeySequence
        prefix = nil
        userIsEnteringDigits = false
        userIsEnteringExponent = false
    }
    
    private func restoreFromError() -> Bool {
        if brain.error == .none {
            return false
        } else {
            brain.error = .none
            updateDisplayString()
            return true
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
        var digit = sender.currentTitle!
        if digit == "·" { digit = "." } // replace "MIDDLE DOT" (used on button in interface builder) with period
        
        switch prefix {
        case .none:
            // digit pressed (without prefix)
            if digit == "EEX" {
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
                if !(digit == "." && (decimalWasAlreadyEntered || userIsEnteringExponent)) {
                    if userIsEnteringExponent {
                        // slide second digit of exponent left and put new digit in its place
                        let exponent2 = String(displayString.removeLast())
                        displayString.removeLast(1)
                        displayString += exponent2 + digit
                    } else {
                        //--------------------------------------------------------
                        displayString += digit  // append entered digit to display
                        //--------------------------------------------------------
                    }
                }
            } else {
                // start clean display with digit
                if digit == "." {
                    displayString = "0."  // precede leading decimal point with a zero
                } else {
                    displayString = digit
                }
                userIsEnteringDigits = true
            }
        case .f:
            prefix = nil
            switch digit {
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
            switch digit {
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
        case .FIX:
            prefix = nil
            if let decimalPlaces = Int(digit) {
                // number after FIX pressed
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayFormat = .fixed(decimalPlaces)
                updateDisplayString()
            } else {
                invalidKeySequenceEntered()
            }
        case .SCI:
            prefix = nil
            if let decimalPlaces = Int(digit) {
                // number after SCI pressed
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayFormat = .scientific(min(decimalPlaces, 6))  // 1 sign + 1 mantissa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
                updateDisplayString()
            } else {
                invalidKeySequenceEntered()
            }
        case .ENG:
            prefix = nil
            if let additionalDigits = Int(digit) {
                // number after ENG pressed
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayFormat = .engineering(min(additionalDigits, 6))  // 1 sign + 1 significant + 6 additional + 1 exponent sign + 2 exponents = 11 digits
                updateDisplayString()
            } else {
                invalidKeySequenceEntered()
            }
        case .STO:
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":  // did not implement registers ".0" through ".9"
                // store displayed number in register
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.storeResultInRegister(digit, result: brain.xRegister!)
                updateDisplayString()
                brain.printStack()
            default:
                invalidKeySequenceEntered()
            }
        case .RCL:
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // recall register, show in display
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayString = String(brain.recallNumberFromStorageRegister(digit))
                brain.pushOperand(displayStringNumber)
                updateDisplayString()
                brain.printStack()
            default:
                invalidKeySequenceEntered()
            }
        case .STO_ADD:
            // STO + register
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add displayed number to register
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.recallNumberFromStorageRegister(digit) + brain.xRegister!
                brain.storeResultInRegister(digit, result: result)
                updateDisplayString()
                brain.printStack()
            default:
                break
            }
        case .STO_SUB:
            // STO - register
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // subtract displayed number from register
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.recallNumberFromStorageRegister(digit) - brain.xRegister!
                brain.storeResultInRegister(digit, result: result)
                updateDisplayString()
                brain.printStack()
            default:
                break
            }
        case .STO_MUL:
            // STO × register
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // multiply register by displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.recallNumberFromStorageRegister(digit) * brain.xRegister!
                brain.storeResultInRegister(digit, result: result)
                updateDisplayString()
                brain.printStack()
            default:
                break
            }
        case .STO_DIV:
            // STO ÷ register
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // divided register by displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.recallNumberFromStorageRegister(digit) / brain.xRegister!
                if result.isNaN || result.isInfinite {  // pws: also need this check for .ADD, .SUB, .MUL (ex. 1E99 in Reg 1, 10 STO x 1 causes overflow)
                    displayString = "nan"  // triggers displayView to show "  Error  0"
                } else {
                    brain.storeResultInRegister(digit, result: result)
                    updateDisplayString()
                }
                brain.printStack()
            default:
                break
            }
        case .RCL_ADD:
            // RCL + register
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add register to displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                brain.xRegister! += brain.recallNumberFromStorageRegister(digit)
                updateDisplayString()
                brain.printStack()
            default:
                break
            }
        case .RCL_SUB:
            // RCL - register
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add register to displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                brain.xRegister! -= brain.recallNumberFromStorageRegister(digit)
                updateDisplayString()
                brain.printStack()
            default:
                break
            }
        case .RCL_MUL:
            // RCL × register
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add register to displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                brain.xRegister! *= brain.recallNumberFromStorageRegister(digit)
                updateDisplayString()
                brain.printStack()
            default:
                break
            }
        case .RCL_DIV:
            // RCL ÷ register
            prefix = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // add register to displayed number
                if userIsEnteringDigits {
                    brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                    userIsEnteringDigits = false
                    userIsEnteringExponent = false
                }
                let result = brain.xRegister! / brain.recallNumberFromStorageRegister(digit)
                if result.isNaN || result.isInfinite {  // pws: also need this check for .ADD, .SUB, .MUL (ex. 1E99 in Reg 1, 10 REC x 1 causes overflow)
                    displayString = "nan"  // triggers displayView to show "  Error  0"
                } else {
                    brain.xRegister = result
                    updateDisplayString()
                }
                brain.printStack()
            default:
                break
            }
        default:  // .HYP, .HYP1 (not allowed to precede stack manipulation key)
            invalidKeySequenceEntered()
        }
    }
    
    // perform operation pressed, and display results
    // operation keys: ÷, ×, -, +, √x, ex, 10x, yx, 1/x, CHS, SIN, COS, TAN, STO, RCL
    @IBAction func operationKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let operation = sender.currentTitle!
        
        switch prefix {
        case .none:
            switch operation {
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
            case "STO":
                prefix = .STO
                return
            case "RCL":
                prefix = .RCL
                return
            default:
                break
            }
        case .STO:
            // STO [+|–|×|÷]
            switch operation {
            case "+":
                prefix = .STO_ADD  // ex. add display to number stored in register (next key)
            case "–":  // not keyboard minus sign
                prefix = .STO_SUB
            case "×":
                prefix = .STO_MUL
            case "÷":
                prefix = .STO_DIV
            default:
                invalidKeySequenceEntered()
            }
            return
        case .RCL:
            // RCL [+|–|×|÷]
            switch operation {
            case "+":
                prefix = .RCL_ADD  // ex. add register (next key) to display
            case "–":  // not keyboard minus sign
                prefix = .RCL_SUB
            case "×":
                prefix = .RCL_MUL
            case "÷":
                prefix = .RCL_DIV
            default:
                invalidKeySequenceEntered()
            }
            return
        case .f, .g, .HYP, .HYP1:  // allowed to precede operation key (ex. f-SIN, f-HYP-COS, g-LOG)
            break
        case .STO_ADD, .STO_SUB, .STO_MUL, .STO_DIV, .RCL_ADD, .RCL_SUB, .RCL_MUL, .RCL_DIV:  // not allowed to precede operation key (just ignore)
            prefix = nil
            brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
            updateDisplayString()
            userIsEnteringDigits = false
            userIsEnteringExponent = false
            brain.printStack()
            return
        default:  // .FIX, .SCI, .ENG, .RCL (not allowed to precede operation key)
            invalidKeySequenceEntered()
            return
        }
        
        if userIsEnteringDigits {
            if liftStack {
                // operation doesn't follow enter; ex. pi 3 -, or 4 sqrt 3 x
                brain.pushOperand(displayStringNumber)  // push up xRegister before overwriting
                brain.printStack()
            } else {
                // operation follows enter; ex. 1 enter 2 +
                endDisplayEntry()  // overwrite xRegister with display
            }
        }  // else complete number already in xRegister; ex. pi pi +
        
        brain.lastXRegister = brain.xRegister!  // save xRegister before pushing operation onto stack
        
        // push operation onto stack (with prefix)
        let oneLetterPrefix = (prefix?.rawValue ?? "n")  // n, f, g, H, or h
        prefix = nil  // must come after previous line
        //-------------------------------------------------
        brain.performOperation(oneLetterPrefix + operation)
        //-------------------------------------------------
        if brain.error == .none {
            updateDisplayString()
        } else {
            displayString = "nan"  // triggers displayView to show "  Error  0"
        }
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        liftStack = true
    }

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        
        switch prefix {
        case .none:
            // Enter pressed
            //------------------------------------
            brain.pushOperand(displayStringNumber)
            brain.pushOperand(displayStringNumber)
            //------------------------------------
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
        brain.printStack()
        userIsEnteringDigits = false
        userIsEnteringExponent = false
        liftStack = false
    }
    
    // manipulate stack or display
    // stack manipulation keys: GSB, R↓, x≷y, ←
    @IBAction func stackManipulationKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = sender.currentTitle!
        var okToClearStillTypingFlag = true

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
                // ← key pressed (remove digit/number)
                if userIsEnteringExponent {
                    return
                } else {
                    if !userIsEnteringDigits {
                        // clear previously entered number (display 0.0)
                        brain.xRegister = 0.0
                    } else if displayString.count > 1 {
                        // remove one digit
                        displayString = String(displayString.dropLast())
                        okToClearStillTypingFlag = false
                    }  // else last digit removed (display prior number)
                }
            default:
                break
            }
        case .f:
            switch keyName {
            case "GSB":
                brain.clearAll()
            case "x≷y":
                // CLEAR REG key pressed (clear storage registers, not stack)
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                brain.clearStorageRegisters()
            case "←":
                // CLEAR PREFIX key pressed
                // display mantissa (all numeric digits with no punctuation), until button is released
                prefix = nil
                if userIsEnteringDigits { endDisplayEntry() }  // move display to X register
                displayView.showCommas = false
                displayString = brain.displayMantissa
                sender.addTarget(self, action: #selector(clearPrefixButtonReleased(_:)), for: .touchUpInside)
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
                if !userIsEnteringDigits { brain.popXRegister() }  // pop last number off stack, unless still typing digits
                userIsEnteringDigits = false
                userIsEnteringExponent = false
                prefix = nil
                return  // return, or prior number will be displayed
            default:
                break
            }
        default:  // .FIX, .SCI, .ENG, .STO, .RCL, .HYP, .HYP1 (not allowed to precede stack manipulation key)
            invalidKeySequenceEntered()
            return
        }
        if okToClearStillTypingFlag {
            userIsEnteringDigits = false
            updateDisplayString()
        }
        userIsEnteringExponent = false
        prefix = nil
    }

    @objc private func clearPrefixButtonReleased(_ button: UIButton) {
        button.removeTarget(nil, action: nil, for: .touchUpInside)
        displayView.showCommas = true
        updateDisplayString()
    }
    
    // set prefix to .f (for "f"), .g (for "g"), .HYP (for f-"GTO"), or .HYP1 (for g-"GTO")
    // prefix keys: f, g, GTO
    @IBAction func prefixKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        let keyName = sender.currentTitle!
        
        switch prefix {
        case .none:
            switch keyName {
            case "f":
                prefix = .f
            case "g":
                prefix = .g
            default:  // GTO (not implemented)
                break
            }
        case .f:
            switch keyName {
            case "g":
                prefix = .g
            case "GTO":
                prefix = .HYP
            default:
                break
            }
        case .g:
            switch keyName {
            case "f":
                prefix = .f
            case "GTO":
                prefix = .HYP1
            default:
                break
            }
        case .STO, .RCL:
            switch keyName {
            case "f":
                break  // leave prefix = .STO/.RCL, to allow Enter to store/recall random seed
            default:
                invalidKeySequenceEntered()
            }
        default:  // .FIX, .SCI, .ENG, .HYP, .HYP1 (not allowed to precede prefix key)
            invalidKeySequenceEntered()
        }
    }

    // hide/unhide display (emulating ON key)
    @IBAction func onKeyPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        _ = restoreFromError()  // ON is the only key that finishes performing its function, if restoring from error
        calculatorIsOn = !calculatorIsOn
        displayView.turnOnIf(calculatorIsOn)
        if calculatorIsOn {
            restoreDisplayLabels()
        } else {
            hideDisplayLabels()
        }
        buttons.forEach { $0.isUserInteractionEnabled = calculatorIsOn }
    }
    
    // MARK: - Simulated button
    
    // All button actions trigger on Touch Down (set up in Interface Builder).  SimulatePressingButton
    // plays a click sound and darkens the button text, then creates a temporary target for Touch Up
    // Inside, which gets called when the button is released (calling simulateReleasingButton).
    private func simulatePressingButton(_ button: UIButton) {
        clickSoundPlayer?.play()
        buttonCoverViews[button]?.whiteLabel.textColor = .darkGray
        button.addTarget(self, action: #selector(simulateReleasingButton(_:)), for: .touchUpInside)
    }
    
    // When the button is released, reset button text to normal color, and remove this target for Touch Up Inside.
    @objc private func simulateReleasingButton(_ button: UIButton) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {  // delay before restoring color, otherwise it is unnoticeable
            self.buttonCoverViews[button]?.whiteLabel.textColor = CoverConst.whiteColor
            button.removeTarget(nil, action: nil, for: .touchUpInside)
        }
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
