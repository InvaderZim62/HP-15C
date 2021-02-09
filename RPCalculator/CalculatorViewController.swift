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

import UIKit
import AVFoundation  // needed for AVAudioPlayer

enum PrefixKey: String {
    case f  // function above button (orange)
    case g  // function below button (blue)
    case FIX
    case SCI
    case ENG
}

struct Constants {
    static let D2R = Double.pi / 180
}

class CalculatorViewController: UIViewController {
    
    var brain = CalculatorBrain()
    var player: AVAudioPlayer?
    var displayString = "" { didSet { displayView.displayString = displayString } }
    var userIsStillTypingDigits = false
    var decimalWasAlreadyEntered = false
    var prefixKey: PrefixKey?
    
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
        "+": ("Py,x", "Cy,x")
    ]

    @IBOutlet weak var displayView: DisplayView!
    @IBOutlet var buttons: [UIButton]!  // don't include ENTER button // pws: maybe use fixed alternateHeight in ButtonCoverView, and give remainder to primary
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        displayView.numberOfDigits = 11  // one digit for sign
        displayString = "0.0000"

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
    
    private func runAndUpdateInterface() {
        let numericalResult = CalculatorBrain.runProgram(brain.program)
        let potentialDisplayString = String(format: displayView.format.string, numericalResult)
        // determine length in display, knowing displayView will place decimal point in a digitView and add a space in front of positive numbers
        let lengthInDisplay = potentialDisplayString.replacingOccurrences(of: ".", with: "").count + (potentialDisplayString.first == "-" ? 0 : 1)
        if lengthInDisplay > displayView.numberOfDigits {
            // fixed format won't fix, temporarily switch to scientific notation
            displayString = String(format: DisplayFormat.scientific(6).string, numericalResult)
        } else {
            displayString = potentialDisplayString
        }
        print("numerical result: \(numericalResult), displayString: \(displayString)")
    }

    // numbers 0-9, period, EEX (pi)
    @IBAction func digitPressed(_ sender: UIButton) {
        playClickSound()
        var digit = sender.currentTitle!
        if digit == "·" { digit = "." } // replace "MIDDLE DOT" (used on button in interface builder) with period
        
        switch prefixKey {
        case .f:
            if digit == "7" {
                // FIX pressed
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                prefixKey = .FIX  // wait for next digit
            } else if digit == "8" {
                // SCI pressed
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                prefixKey = .SCI  // wait for next digit
            }
            return
        case .g:
            if digit == "EEX" {
                // pi pressed
                if userIsStillTypingDigits { enterPressed(UIButton()) }  // push current digits onto stack
                displayString = "3.141592654"
                enterPressed(UIButton())
                runAndUpdateInterface()
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
                    displayString += digit  // append entered digit to display
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

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterPressed(_ sender: UIButton) {
        playClickSound()
        if let number = Double(displayString) {
            brain.pushOperand(number)
            runAndUpdateInterface()
        }
        userIsStillTypingDigits = false
        decimalWasAlreadyEntered = false
        prefixKey = nil
    }
    
    // perform operation pressed (button title), and display results
    @IBAction func operationPressed(_ sender: UIButton) {
        playClickSound()
        // pws: For now, I assumed an operation is only preceded by no prefix key, or by f, or g
        // if this is not the case, prefixPlusOperation (below) and prefixKey (in CalculatorBrain.popOperationOffStack) must change
        precondition((prefixKey?.rawValue ?? "n").count == 1, "Operation selected with prefix key other than f or g")
        let prefixPlusOperation = prefixKey?.rawValue ?? "n" + sender.currentTitle!  // capture before clearing prefixKey in enterPressed
        if userIsStillTypingDigits { enterPressed(UIButton()) }  // push display onto stack, so user doesn't need to hit enter before each operation
        brain.pushOperation(prefixPlusOperation)
        runAndUpdateInterface()
        
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
                displayString = String(displayString.dropLast())
            }
        }
        prefixKey = nil
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
