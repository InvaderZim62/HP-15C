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
    var decimalWasAlreadyEntered = false
    var buttonCoverViews = [UIButton: ButtonCoverView]()
    
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
        let numericalResult = CalculatorBrain.runProgram(brain.program)
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
        print("numerical result: \(numericalResult), displayString: \(displayString)")
    }
    
    // MARK: - Button actions

    // digits: numbers 0-9, period, EEX key
    @IBAction func digitPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        var digit = sender.currentTitle!
        if digit == "·" { digit = "." } // replace "MIDDLE DOT" (used on button in interface builder) with period
        
        // handle digit after prefix key (return before handling lone digits)
        switch prefixKey {
        case .f:
            switch digit {
            case "3":
                // →RAD pressed
                let tempButton = UIButton()
                tempButton.setTitle("3", for: .normal)
                operationPressed(tempButton)  // better handled as operation (retain the prefixKey here)
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
            return
        case .g:
            switch digit {
            case "3":
                // →DEG pressed
                let tempButton = UIButton()
                tempButton.setTitle("3", for: .normal)
                operationPressed(tempButton)  // better handled as operation (retain the prefixKey here)
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
            prefixKey = nil
            return
        case .FIX:
            if let decimalPlaces = Int(digit) {
                prefixKey = nil
                // number after FIX pressed
                displayView.format = .fixed(decimalPlaces)
                runAndUpdateInterface()
            }
            return
        case .SCI:
            if let decimalPlaces = Int(digit) {
                prefixKey = nil
                // number after FIX pressed
                displayView.format = .scientific(min(decimalPlaces, 6))  // 1 sign + 1 mantisa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
                runAndUpdateInterface()
            }
            return
        case .STO:
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":  // did not include registers ".0" through ".9"
                prefixKey = nil
                // store displayed number in register
                enterPressed(UIButton())
                brain.storeResultsInRegister(digit)
            default:
                break
            }
            return
        case .RCL:
            switch digit {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                prefixKey = nil
                // recall register, show in display
                displayString = String(brain.recallNumberFromRegister(digit))
                enterPressed(UIButton())
            default:
                break
            }
            return
        default:
            break
        }
        
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
        
        if digit == "." { decimalWasAlreadyEntered = true }

        prefixKey = nil
    }
    
    // perform operation pressed (button title), and display results
    @IBAction func operationPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // operation can only follow f, g, or no prefix
        var keyName = sender.currentTitle!
        if keyName == "CHS" && userIsEnteringExponent {
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
        let prefixPlusOperation = (prefixKey?.rawValue ?? "n") + keyName  // capture before clearing prefixKey in enterPressed
        if userIsStillTypingDigits { enterPressed(UIButton()) }  // push display onto stack, so user doesn't need to hit enter before each operation
        brain.pushOperation(prefixPlusOperation)
        runAndUpdateInterface()
        prefixKey = nil
    }

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterPressed(_ sender: UIButton) {
        if sender.titleLabel?.text != nil {
            simulatePressingButton(sender)  // only simulate if user pressed ENTER - not if code calling enterPressed(UIButton())
        }
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // enter can only follow f, g, or no prefix
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
            runAndUpdateInterface()
        }
        userIsStillTypingDigits = false
        userIsEnteringExponent = false
        decimalWasAlreadyEntered = false
        prefixKey = nil
    }
    
    @IBAction func backArrowPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // back-arrow can only follow f, g, or no prefix
        if prefixKey == .f {
            // clear prefix
            prefixKey = nil
        } else if prefixKey == .g || !userIsStillTypingDigits {
            // clear all
            displayString = "0.0000"
            brain.clearStack()
            userIsStillTypingDigits = false
            decimalWasAlreadyEntered = false
        } else {
            // remove last pressed digit
            if displayString.count == 1 {
                displayString = "0.0000"
                userIsStillTypingDigits = false
                decimalWasAlreadyEntered = false
            } else {
                if displayString.hasSuffix(".") {
                    decimalWasAlreadyEntered = false
                }
                displayString = String(displayString.dropLast())  // remove last display digit
            }
        }
        prefixKey = nil
    }

    @IBAction func fPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // f can only follow f, g, or no prefix
        prefixKey = .f
    }
    
    @IBAction func gPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
        guard prefixKey == .f || prefixKey == .g || prefixKey == nil else { return }  // g can only follow f, g, or no prefix
        prefixKey = .g
    }

    @IBAction func onPressed(_ sender: UIButton) {
        simulatePressingButton(sender)
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
