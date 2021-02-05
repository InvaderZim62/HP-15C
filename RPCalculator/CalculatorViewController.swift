//
//  CalculatorViewController.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/4/21.
//

import UIKit

class CalculatorViewController: UIViewController {
    
    var brain = CalculatorBrain()
    
    var userIsStillTypingDigits = false
    var decimalWasAlreadyEntered = false
    var fIsPending = false
    var gIsPending = false

    @IBOutlet weak var display: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        display.text = "0.00000"
    }
    
    private func runAndUpdateInterface() {
        let result = CalculatorBrain.runProgram(brain.program)
        display.text = String(format: "%g", result)
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
        
        if digit == "." { decimalWasAlreadyEntered = true }

        fIsPending = false
        gIsPending = false
    }

    // push digits from display onto stack when enter key is pressed
    @IBAction func enterPressed(_ sender: UIButton) {
        if let number = Double(display.text!) {
            brain.pushOperand(number)
        }
        userIsStillTypingDigits = false
        decimalWasAlreadyEntered = false
        fIsPending = false
        gIsPending = false
    }
    
    // perform operation pressed (button title), and display results
    @IBAction func operationPressed(_ sender: UIButton) {
        if userIsStillTypingDigits { enterPressed(UIButton()) }  // push display onto stack, so user doesn't need to hit enter before each operation
        brain.pushOperation(sender.currentTitle!)
        runAndUpdateInterface()
        
        fIsPending = false
        gIsPending = false
    }
    
    @IBAction func fPressed(_ sender: UIButton) {
        fIsPending = true
        gIsPending = false
    }
    
    @IBAction func gPressed(_ sender: UIButton) {
        fIsPending = false
        gIsPending = true
    }
    
    @IBAction func backArrowPressed(_ sender: UIButton) {
        if gIsPending {  // clear all
            display.text = "0.00000"
            brain.clearStack()
            userIsStillTypingDigits = false
            decimalWasAlreadyEntered = false
        } else if userIsStillTypingDigits {
            if display.text?.count == 1 {
                display.text = "0.00000"
                userIsStillTypingDigits = false
                decimalWasAlreadyEntered = false
            } else {
                if display.text!.hasSuffix(".") {
                    decimalWasAlreadyEntered = false
                }
                display.text = String(display.text!.dropLast())
            }
        }
        fIsPending = false
        gIsPending = false
    }
}

