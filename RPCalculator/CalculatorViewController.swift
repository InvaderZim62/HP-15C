//
//  CalculatorViewController.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/4/21.
//
//  click.wav obtained from: https://fresound.org/people/kwahmah_02/sounds/256116
//  file is in the public domain (CC0 1.0 Universal)
//
//  I changed all button control events from Touch Up Inside to Touch Down, by doing the following...
//  First, control drag all buttons to their appropriate IBAction in the code (defaults to Touch
//  Up Inside).  Then Right-click (two-finger-touch) each button in Interface Builder to bring up
//  the connections menu.  Control-drag from the little circle to the right of Touch Down (under
//  Send Events) to the appropriate IBAction.  Cancel (click on x) the event for Touch Up Inside.
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
//
//  To do...
//  - save registers and stack to user defaults (restore at startup).
//

import UIKit
import AVFoundation  // needed for AVAudioPlayer

enum PrefixKey: String {
    case f  // function above button (orange)
    case g  // function below button (blue)
    case FIX
    case SCI
    case ENG
    case STO
    case RCL
}

enum TrigMode: String {
    case DEG = "D"  // default
    case RAD = "R"
    case GRAD = "G"  // 90 degrees = 100 gradians
}

class CalculatorViewController: UIViewController {
    
    var brain = CalculatorBrain()
    var player: AVAudioPlayer?
    var displayString = "" { didSet { displayView.displayString = displayString } }
    var displayLabels = [UILabel]()
    var displayLabelAlphas = [CGFloat]()
    var calculatorIsOn = true
    var userIsStillTypingDigits = false
    var userIsEnteringExponent = false
    var buttonCoverViews = [UIButton: ButtonCoverView]()
    var seed = 0  // HP-15C initial seed is zero
    var lastRandomNumberGenerated = 0.0
    
    var decimalWasAlreadyEntered: Bool {
        return displayString.contains(".")
    }
    
    var prefixKey: PrefixKey? { didSet {
        fLabel.alpha = 0
        gLabel.alpha = 0
        switch prefixKey {
        case .f:
            fLabel.alpha = 1
        case .g:
            gLabel.alpha = 1
        default:
            break
        }
    } }
    
    var trigMode = TrigMode.DEG { didSet {
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
    } }
    
    // dictionary of button labels going from left to right, top to bottom
    // dictionary key is the primary button label (must agree with storyboard)
    var buttonText = [  // [nText: (fText, gText)]
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
        "EEX": ("RESULT", "π"),  // pi is option p
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
        "E\nN\nT\nE\nR": ("RAN #", "LST x")  // ENTER
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
    @IBOutlet weak var logoCircleView: UIView!  // used to make view round in viewDidLoad
    @IBOutlet weak var calculatorView: CalculatorView!  // used to draw bracket around CLEAR label
    @IBOutlet weak var clearLabel: UILabel!  // used to anchor line drawing in calculatorView
    
    // MARK: - Start of code
    
    override func viewDidLoad() {
        super.viewDidLoad()
        displayLabels = [userLabel, fLabel, gLabel, beginLabel, gradLabel, dmyLabel, cLabel, prgmLabel]
        displayLabelAlphas.append(contentsOf: repeatElement(0, count: displayLabels.count))  // allocate the same sized array
        hideDisplayLabels()
        calculatorView.clearLabel = clearLabel
    }
    
    override func viewWillAppear(_ animated: Bool) {
        displayView.numberOfDigits = 11  // one digit for sign
        displayString = "0.0000"
        logoCircleView.layer.masksToBounds = true
        logoCircleView.layer.cornerRadius = logoCircleView.bounds.width / 2  // make it circular
        createButtonCovers()
    }
    
    // display labels: USER  f  g  BEGIN  GRAD  D.MY  C  PRGM
    private func hideDisplayLabels() {
        for (index, label) in displayLabels.enumerated() {
            displayLabelAlphas[index] = label.alpha  // save current setting for unhiding
            displayLabels[index].alpha = 0  // use alpha, instead of isHidden, to maintain stackView layout
        }
    }
    
    private func unhideDisplayLabels() {
        for (index, alpha) in displayLabelAlphas.enumerated() {
            displayLabels[index].alpha = alpha
        }
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
            // override font size 17 (set in ButtonCoverView)
            buttonCoverView.whiteLabel.font = buttonCoverView.whiteLabel.font.withSize(22)
        case "·":
            buttonCoverView.whiteLabel.font = buttonCoverView.whiteLabel.font.withSize(30)
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
    
    // run program and set display string (switch to scientific notation, if fixed format won't fit)
    private func runAndUpdateInterface() {
        let numericalResult = brain.runProgram()
        let potentialDisplayString = String(format: displayView.format.string, numericalResult)
        let displayConvertedBackToNumber = Double(potentialDisplayString)
        // determine length in display, knowing displayView will combine decimal point with digit and add a space in front of positive numbers
        let lengthInDisplay = potentialDisplayString.replacingOccurrences(of: ".", with: "").count + (potentialDisplayString.first == "-" ? 0 : 1)
        if lengthInDisplay > displayView.numberOfDigits {
            // fixed format won't fit, temporarily switch to scientific notation with 6 decimal places
            displayString = String(format: DisplayFormat.scientific(6).string, numericalResult)
        } else if displayConvertedBackToNumber == 0 && numericalResult != 0 {
            // fixed format rounded to zero, temporarily switch to scientific notation with 6 decimal places
            displayString = String(format: DisplayFormat.scientific(6).string, numericalResult)
        } else {
            displayString = potentialDisplayString + (potentialDisplayString.contains(".") ? "" : ".")  // make sure at least one decimal point
        }
//        print("numerical result: \(numericalResult), displayString: \(displayString)")
    }
    
    private func restoreFromError() -> Bool {
        if brain.errorPresent {
            brain.errorPresent = false
            runAndUpdateInterface()
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Button actions

    // digits: numbers 0-9, period, EEX key
    @IBAction func digitPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        var digit = sender.currentTitle!
        if digit == "·" { digit = "." } // replace "MIDDLE DOT" (used on button in interface builder) with period
        
        // handle digit after prefix key
        switch prefixKey {
        case .f:
            prefixKey = nil
            switch digit {
            case "3":
                // →RAD pressed
                let tempButton = UIButton()
                tempButton.setTitle("3", for: .normal)
                prefixKey = .f
                operationPressed(tempButton)  // better handled as operation
            case "7":
                // FIX pressed
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                prefixKey = .FIX  // wait for next digit
            case "8":
                // SCI pressed
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                prefixKey = .SCI  // wait for next digit
            default:
                break
            }
        case .g:
            prefixKey = nil
            switch digit {
            case "3":
                // →DEG pressed
                let tempButton = UIButton()
                tempButton.setTitle("3", for: .normal)
                prefixKey = .g
                operationPressed(tempButton)  // better handled as operation
            case "7":
                trigMode = .DEG
            case "8":
                trigMode = .RAD
            case "9":
                trigMode = .GRAD
            case "EEX":
                // pi pressed
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                displayString = "3.141592654"
                enterPressed(UIButton())
            default:
                break
            }
        case .FIX:
            prefixKey = nil
            if let decimalPlaces = Int(digit) {
                // number after FIX pressed
                displayView.format = .fixed(decimalPlaces)
                runAndUpdateInterface()
            }
        case .SCI:
            prefixKey = nil
            if let decimalPlaces = Int(digit) {
                // number after FIX pressed
                displayView.format = .scientific(min(decimalPlaces, 6))  // 1 sign + 1 mantisa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
                runAndUpdateInterface()
            }
        case .STO:
            prefixKey = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":  // did not include registers ".0" through ".9"
                // store displayed number in register
                if userIsStillTypingDigits { enterPressed(UIButton()) }
                brain.storeResultsInRegister(digit)
            default:
                break
            }
        case .RCL:
            prefixKey = nil
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // recall register, show in display
                displayString = String(brain.recallNumberFromStorageRegister(digit))
                enterPressed(UIButton())
            default:
                break
            }
        default:
            // no prefitKey section
            if digit == "EEX" {
                if userIsStillTypingDigits {
                    userIsEnteringExponent = true
                } else {
                    return
                }
            }
            
            // add digit to display
            if userIsStillTypingDigits {
                if displayString == "0" {
                    if digit == "." {
                        displayString += digit  // append decimal to leading zero
                    } else if digit != "0" {
                        displayString = digit  // replace leading zero with digit
                    }
                } else {
                    if !(digit == "." && decimalWasAlreadyEntered) {  // only allow one decimal point per number
                        if userIsEnteringExponent {
                            if digit == "EEX" {  // pws: doesn't guard against mantissa that overlaps exponent
                                let paddingLength = decimalWasAlreadyEntered ? 9 : 8  // decimal doesn't take up space (part of prior digit)
                                displayString = displayString.padding(toLength: paddingLength, withPad: " ", startingAt: 0) + "00"
                            } else {
                                // slide second digit of exponent left and put new digit in its place
                                let exponent2 = String(displayString.removeLast())
                                displayString.removeLast(1)
                                displayString += exponent2 + digit
                            }
                        } else {
                            displayString += digit  // append entered digit to display
                        }
                    }
                }
            } else {
                // start clean display with digit
                if digit == "." {
                    displayString = "0."  // precede leading decimal point with a zero
                } else {
                    displayString = digit
                }
                userIsStillTypingDigits = true
            }
        }
    }
    
    // perform operation pressed (button title), and display results
    @IBAction func operationPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // operation can only follow f, g, or no prefix
        var keyName = sender.currentTitle!
        if keyName == "CHS" && userIsEnteringExponent {  // if CHS and not entering exponent, pushOperation("nCHS"), below
            // change sign in front of exponent
            let exponent2 = String(displayString.removeLast())
            let exponent1 = String(displayString.removeLast())
            var sign = String(displayString.removeLast())
            sign = sign == " " ? "-" : " "  // toggle sign
            displayString += sign + exponent1 + exponent2
            return
        } else if keyName == "STO" {
            prefixKey = .STO
            return
        } else if keyName == "RCL" {
            prefixKey = .RCL
            return
        }
        if keyName == "SIN" || keyName == "COS" || keyName == "TAN" {
            keyName += trigMode.rawValue  // DEG adds D to trig name (ex. COSD), RAD adds nothing (ex. COS)
        }
        let saveXRegister = brain.xRegister
        let prefixPlusOperation = (prefixKey?.rawValue ?? "n") + keyName  // capture before clearing prefixKey in enterPressed
        if prefixPlusOperation == "gyx" { brain.pushOperand(saveXRegister!) }  // push extra base number on stack before %, to allow adding result to it
        prefixKey = nil  // must come after previous line and before enterPressed
        if userIsStillTypingDigits { enterPressed(UIButton()) }  // push display onto stack, so user doesn't need to hit enter before each operation
        brain.pushOperation(prefixPlusOperation)
        runAndUpdateInterface()
    }

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterPressed(_ sender: UIButton) {
        if sender.titleLabel?.text != nil {
            // only simulate button if user pressed ENTER - not if code called enterPressed(UIButton())
            simulatePressingButton(sender)
            if restoreFromError() { return }
        }
        guard prefixKey == .f || prefixKey == .g || prefixKey == .STO || prefixKey == .RCL || prefixKey == nil else { return }
        switch prefixKey {
        case .f:
            // RND# key pressed
            prefixKey = nil
            srand48(seed)  // re-seed each time, so a manually stored seed will generate the same sequence each time
            let number = drand48()
            seed = Int(number * Double(Int32.max))  // regenerate my own seed to use next time (Note: Int.max gives same numbers for different seeds)
            brain.pushOperand(number)
            lastRandomNumberGenerated = number
        case .g:
            prefixKey = nil
            // LSTx key pressed
            displayString = String(brain.lastXRegister)
        case .STO:
            prefixKey = nil
            // STO RAN# pressed (store new seed)
            if userIsStillTypingDigits { enterPressed(UIButton()) }
            if var number = brain.xRegister {
                number = min(max(number, 0.0), 0.9999999999)  // limit 0.0 <= number < 1.0
                seed = Int(number * Double(Int32.max))
            } else {
                return
            }
        case .RCL:
            prefixKey = nil
            // RCL RAN# pressed (recall last random number)
            brain.pushOperand(lastRandomNumberGenerated)
        default:
            // Enter key pressed
            if userIsEnteringExponent {
                // convert "1.2345    01" to "1.2345E+01", before trying to convert to number
                let exponent2 = String(displayString.removeLast())
                let exponent1 = String(displayString.removeLast())
                var sign = String(displayString.removeLast())
                if sign == " " { sign = "+" }
                displayString = displayString.replacingOccurrences(of: " ", with: "") + "E" + sign + exponent1 + exponent2
            }
            if let number = Double(displayString) {
                brain.pushOperand(number)
            }
        }
        runAndUpdateInterface()
        userIsStillTypingDigits = false
        userIsEnteringExponent = false
    }
    
    // manipulate stack or display
    @IBAction func stackManipulationPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // register keys can only follow f, g, or no prefix
        let keyName = sender.currentTitle!
        var okToClearStillTyping = true

        switch prefixKey {
        case .f:
            switch keyName {
            case "x≷y":
                // CLEAR REG key pressed (clear storage registers, not stack)
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                brain.clearStorageRegisters()
            case "←":
                // CLEAR PREFIX key pressed
                prefixKey = nil
            default:
                break
            }
        case .g:
            switch keyName {
            case "R↓":
                // R↑ key pressed (roll stack up)
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                brain.rollStack(directionDown: false)
            case "←":
                // CLx key pressed
                brain.clearStack()
            default:
                break
            }
        default:
            switch keyName {
            case "R↓":
                // R↓ key pressed (roll stack down)
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                brain.rollStack(directionDown: true)
            case "x≷y":
                // x≷y key pressed (swap x-y registers)
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                brain.swapXyRegisters()
            case "←":
                // ← key pressed (remove digit/number)
                if displayString.count == 1 {
                    // no digits left
                    brain.pushOperand(0.0)
                } else if userIsStillTypingDigits {
                    // still typing digits
                    displayString = String(displayString.dropLast())
                    okToClearStillTyping = false
                } else {
                    // clear previously entered number
                    brain.xRegister = 0.0
                }
            default:
                break
            }
        }
        if okToClearStillTyping {
            userIsStillTypingDigits = false
            runAndUpdateInterface()
        }
        userIsEnteringExponent = false
        prefixKey = nil
    }
    
    @IBAction func fPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // f can only follow f, g, or no prefix
        prefixKey = .f
    }
    
    @IBAction func gPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        if restoreFromError() { return }
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // g can only follow f, g, or no prefix
        prefixKey = .g
    }

    @IBAction func onPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        _ = restoreFromError()  // ON is the only key that finishes performing its function, if restoring from error
        calculatorIsOn = !calculatorIsOn
        displayView.turnOnIf(calculatorIsOn)
        if calculatorIsOn {
            unhideDisplayLabels()
        } else {
            hideDisplayLabels()
        }
        buttons.forEach { $0.isUserInteractionEnabled = calculatorIsOn }
    }
    
    // MARK: - Simulated button
    
    private func simulatePressingButton(_ button: UIButton) {
        playClickSound()
        buttonCoverViews[button]?.whiteLabel.textColor = .darkGray  // pws: consider creating a function in ButtonCoverView (this line only)
        button.addTarget(self, action: #selector(simulateReleasingButton(_:)), for: .touchUpInside)
    }

    @objc private func simulateReleasingButton(_ button: UIButton) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {  // delay before restoring color, otherwise it is unnoticeable
            self.buttonCoverViews[button]?.whiteLabel.textColor = CoverConst.whiteColor
            button.removeTarget(nil, action: nil, for: .touchUpInside)
        }
    }
    
    private func playClickSound() {
        guard let url = Bundle.main.url(forResource: "click", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            guard let player = player else { return }
            player.play()
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
}
