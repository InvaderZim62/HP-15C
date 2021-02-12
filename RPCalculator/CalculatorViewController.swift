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
    var userIsStillTypingDigits = false
    var userIsEnteringExponent = false
    var decimalWasAlreadyEntered = false
    
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
        "←": ("PREFIX", "CLx"),
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
        "E\nN\nT\nE\nR": ("RAN#", "LSTx")  // ENTER
    ]

    @IBOutlet weak var displayView: DisplayView!
    @IBOutlet var buttons: [UIButton]!
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var fLabel: UILabel!
    @IBOutlet weak var gLabel: UILabel!
    @IBOutlet weak var beginLabel: UILabel!
    @IBOutlet weak var gradLabel: UILabel!
    @IBOutlet weak var dmyLabel: UILabel!
    @IBOutlet weak var cLabel: UILabel!
    @IBOutlet weak var prgmLabel: UILabel!
    @IBOutlet weak var logoCircleView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        displayView.numberOfDigits = 11  // one digit for sign
        displayString = "0.0000"
        userLabel.alpha = 0  // don't hide, or stackView layout changes
        fLabel.alpha = 0
        gLabel.alpha = 0
        beginLabel.alpha = 0
        gradLabel.alpha = 0
        dmyLabel.alpha = 0
        cLabel.alpha = 0
        prgmLabel.alpha = 0
        logoCircleView.layer.masksToBounds = true
        logoCircleView.layer.cornerRadius = logoCircleView.bounds.width / 2  // make it circular
        
        // create all text for the buttons using ButtonCoverViews
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
        // determine length in display, knowing displayView will place decimal point in a digitView and add a space in front of positive numbers
        let lengthInDisplay = potentialDisplayString.replacingOccurrences(of: ".", with: "").count + (potentialDisplayString.first == "-" ? 0 : 1)
        if lengthInDisplay > displayView.numberOfDigits {
            // fixed format won't fit, temporarily switch to scientific notation
            displayString = String(format: DisplayFormat.scientific(6).string, numericalResult)
        } else {
            displayString = potentialDisplayString
        }
        print("numerical result: \(numericalResult), displayString: \(displayString)")
    }

    // digits: numbers 0-9, period, EEX key
    @IBAction func digitPressed(_ sender: UIButton) {
        playClickSound()
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
            return
        case .g:
            switch digit {
            case "3":
                // →DEG pressed
                let tempButton = UIButton()
                tempButton.setTitle("3", for: .normal)
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
                runAndUpdateInterface()
            default:
                break
            }
            prefixKey = nil
            return
        case .FIX:
            if let decimalPlaces = Int(digit) {
                // number after FIX pressed
                displayView.format = .fixed(decimalPlaces)
                runAndUpdateInterface()
            }
            prefixKey = nil
            return
        case .SCI:
            if let decimalPlaces = Int(digit) {
                // number after FIX pressed
                displayView.format = .scientific(min(decimalPlaces, 6))  // 1 sign + 1 mantisa + 6 decimals + 1 exponent sign + 2 exponents = 11 digits
                runAndUpdateInterface()
            }
            prefixKey = nil
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
        playClickSound()
        var keyName = sender.currentTitle!
        if keyName == "CHS" && userIsEnteringExponent {
            let exponent2 = String(displayString.removeLast())
            let exponent1 = String(displayString.removeLast())
            var sign = String(displayString.removeLast())
            sign = sign == " " ? "-" : " "  // toggle sign
            displayString += sign + exponent1 + exponent2
            return
        }
        if keyName == "SIN" || keyName == "COS" || keyName == "TAN" {
            keyName += trigMode.rawValue  // DEG adds D (ex. COSD), RAD adds nothing (ex. COS)
        }
        // pws: For now, I assumed an operation is only preceded by no prefix key, or by f, or g
        // if this is not the case, prefixPlusOperation (below) and prefixKey (in CalculatorBrain.popOperationOffStack) must change
        precondition((prefixKey?.rawValue ?? "n").count == 1, "Operation selected with prefix key other than f or g")
        let prefixPlusOperation = (prefixKey?.rawValue ?? "n") + keyName  // capture before clearing prefixKey in enterPressed
        if userIsStillTypingDigits { enterPressed(UIButton()) }  // push display onto stack, so user doesn't need to hit enter before each operation
        brain.pushOperation(prefixPlusOperation)
        runAndUpdateInterface()
        
        prefixKey = nil
    }

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterPressed(_ sender: UIButton) {
        playClickSound()
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
        playClickSound()
        if prefixKey == .g || !userIsStillTypingDigits {  // clear all
            displayString = "0.0000"
            brain.clearStack()
            userIsStillTypingDigits = false
            decimalWasAlreadyEntered = false
        } else {
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
        playClickSound()
        prefixKey = .f
    }
    
    @IBAction func gPressed(_ sender: UIButton) {
        playClickSound()
        prefixKey = .g
    }

    func playClickSound() {
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
