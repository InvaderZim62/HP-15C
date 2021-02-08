//
//  CalculatorViewController.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/4/21.
//

import UIKit

enum AlternateFunction: String {  // must all be one character
    case n  // none (primary button function)
    case f  // function above button (orange)
    case g  // function below button (blue)
}

struct Constants {
    static let D2R = Double.pi / 180
}

class CalculatorViewController: UIViewController {
    
    var brain = CalculatorBrain()
    var displayString = "" { didSet { displayView.numberString = displayString } }
    var userIsStillTypingDigits = false
    var decimalWasAlreadyEntered = false
    var alternateFunction = AlternateFunction.n
    
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
        // increase font size for special cases
        switch nText {
        case "ex", "10x", "yx":
            buttonCoverView.whiteLabel.attributedText = superscriptLastNCharactersOf(nText, n: 1, font: buttonCoverView.whiteLabel.font)
        case "GTO", "SIN", "COS", "TAN":  // gText: HYP-1, SIN-1, COS-1, TAN-1
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
        let fontSize = font.pointSize
        let regularFont = font.withSize(fontSize)
        let superscriptFont = font.withSize(fontSize - 2)
        let attributedString = NSMutableAttributedString(string: string, attributes: [.font: regularFont])
        attributedString.setAttributes([.font: superscriptFont, .baselineOffset: 4], range: NSRange(location: string.count - n, length: n))
        return attributedString
    }
    
    private func runAndUpdateInterface() {
        let result = CalculatorBrain.runProgram(brain.program)
        displayString = String(format: "%g", result)
    }

    @IBAction func digitPressed(_ sender: UIButton) {
        var digit = sender.currentTitle!
        
        if digit == "·" { digit = "." } // replace "MIDDLE DOT" with period
        if digit == "EEX" {
            if alternateFunction == .g {
                displayString = ""  // lose any un-entered digits // pws: or should this save the digits (call enterPressed) first?
                digit = "3.141592654"
            } else {
                return  // pws: implement EEX
            }
        }
        
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

        alternateFunction = .n
    }

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterPressed(_ sender: UIButton) {
        if let number = Double(displayString) {
            brain.pushOperand(number)
        }
        userIsStillTypingDigits = false
        decimalWasAlreadyEntered = false
        alternateFunction = .n
    }
    
    // perform operation pressed (button title), and display results
    @IBAction func operationPressed(_ sender: UIButton) {
        let alternatePlusOperation = alternateFunction.rawValue + sender.currentTitle!  // capture before clearing alternateFunction in enterPressed
        if userIsStillTypingDigits { enterPressed(UIButton()) }  // push display onto stack, so user doesn't need to hit enter before each operation
        brain.pushOperation(alternatePlusOperation)
        runAndUpdateInterface()
        
        alternateFunction = .n
    }
    
    @IBAction func fPressed(_ sender: UIButton) {
        alternateFunction = .f
    }
    
    @IBAction func gPressed(_ sender: UIButton) {
        alternateFunction = .g
    }
    
    @IBAction func backArrowPressed(_ sender: UIButton) {
        if alternateFunction == .g || !userIsStillTypingDigits {  // clear all
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
        alternateFunction = .n
    }
}

