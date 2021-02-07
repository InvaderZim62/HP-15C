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
    static let displayColor = #colorLiteral(red: 135/255, green: 142/255, blue: 126/255, alpha: 1)
    static let D2R = Double.pi / 180
}

class CalculatorViewController: UIViewController {
    
    var brain = CalculatorBrain()
    var displayView = DisplayView()
    
    var userIsStillTypingDigits = false
    var decimalWasAlreadyEntered = false
    var alternateFunction = AlternateFunction.n
    
    // dictionary of button labels going from left to right, top to bottom
    // dictionary key is the primary button label (must agree with storyboard)
    var buttonText = [  // [nText: (fText, gText)]
        "√x": ("A", "x²"),
        "ex": ("B", "LN"),
        "10x": ("C", "LOG"),
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

    @IBOutlet weak var display: UILabel!
    @IBOutlet var buttons: [UIButton]!  // don't include ENTER button // pws: maybe use fixed alternateHeight in ButtonCoverView, and give remainder to primary
    
    override func viewDidLoad() {
        super.viewDidLoad()
        display.text = "0.0000"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        displayView.frame = display.frame  // pws: align with display for now
        displayView.backgroundColor = Constants.displayColor
        displayView.numberOfDigits = 11  // one digit for sign
        displayView.numberString = display.text!  // pws: see comment below
        display.superview?.addSubview(displayView)  // pws: temp
        
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
        case "÷", "×", "–", "+":
            buttonCoverView.whiteLabel.font = buttonCoverView.whiteLabel.font.withSize(22)
        case "·":
            buttonCoverView.whiteLabel.font = buttonCoverView.whiteLabel.font.withSize(30)
        default:
            break
        }
        button.superview?.addSubview(buttonCoverView)
    }
    
    private func runAndUpdateInterface() {
        let result = CalculatorBrain.runProgram(brain.program)
        display.text = String(format: "%g", result)
        displayView.numberString = display.text!  // pws: see comment below
    }

    @IBAction func digitPressed(_ sender: UIButton) {
        var digit = sender.currentTitle!
        
        if digit == "·" { digit = "." } // replace "MIDDLE DOT" with period
        
        if userIsStillTypingDigits {
            if display.text == "0" {
                if digit == "." {
                    display.text! += digit  // append decimal to leading zero
                } else if digit != "0" {
                    display.text = digit  // replace leading zero with digit
                }
            } else {
                if !(digit == "." && decimalWasAlreadyEntered) {  // only allow one decimal point per number
                    display.text! += digit  // append entered digit to display
                }
            }
        } else {
            // start clean display with digit
            if digit == "." {
                display.text = "0."  // precede leading decimal point with a zero
            } else {
                display.text = digit
            }
            userIsStillTypingDigits = true
        }
        // pws: after deleting the display UILabel, replace it with...
        // var display = "" { didSet { displayView.numberString = display } }
        // and delete the next line
        displayView.numberString = display.text!
        
        if digit == "." { decimalWasAlreadyEntered = true }

        alternateFunction = .n
    }

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterPressed(_ sender: UIButton) {
        if let number = Double(display.text!) {
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
            display.text = "0.0000"
            brain.clearStack()
            userIsStillTypingDigits = false
            decimalWasAlreadyEntered = false
        } else {
            if display.text?.count == 1 {
                display.text = "0.0000"
                userIsStillTypingDigits = false
                decimalWasAlreadyEntered = false
            } else {
                if display.text!.hasSuffix(".") {
                    decimalWasAlreadyEntered = false
                }
                display.text = String(display.text!.dropLast())
            }
        }
        displayView.numberString = display.text!  // pws: see comment above
        alternateFunction = .n
    }
}

