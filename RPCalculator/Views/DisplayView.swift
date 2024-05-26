//
//  DisplayView.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/6/21.
//
//  Select display segments can be drawn to create any digit, sign, or decimal point, and limited letters.
//
//      --    --    --
//     |  |  |  |  |  |
//      --    --    --    ...11 digits (first is sign)
//     |  |  |  |  |  |
//      -- .  -- .  -- .
//
//  Decimal point is drawn with digit to its left.
//

import UIKit

class DisplayView: UIView {
    
    var numberOfDigits = 0 { didSet { createDigitViews() } }
    var displayString = "" { didSet { updateDisplay() } }

    private var digitViews = [DigitView]()
    private var exponentWasFound = false
    
    func turnOnIf(_ isOn: Bool) {
        digitViews.forEach { $0.alpha = isOn ? 1 : 0 }
    }
    
    // create equally sized digitViews and add them to this DisplayView, leaving the specified
    // boarder (inset) around the digitViews
    private func createDigitViews() {
        digitViews.forEach { $0.removeFromSuperview() }  // remove any past views and start over
        digitViews.removeAll()
        let leftInset: CGFloat = 6
        let rightInset: CGFloat = 6
        let topInset: CGFloat = 10
        let bottomInset: CGFloat = 0.24 * bounds.height
        let digitViewWidth = (bounds.width - leftInset - rightInset) / CGFloat(numberOfDigits)
        for index in 0..<numberOfDigits {
            let digitView = DigitView(frame: CGRect(x: digitViewWidth * CGFloat(index) + leftInset,
                                                    y: topInset, width: digitViewWidth, height: bounds.height - topInset - bottomInset))
            digitView.backgroundColor = .clear
//            if index == 1 { digitView.backgroundColor = .gray }  // show size of digitView during development
            addSubview(digitView)
            digitViews.append(digitView)
        }
    }
    
    private func clearDisplay() {
        digitViews.forEach { $0.clear() }
    }
    
    // set digit character for each digitView, drawn from modifiedDisplayString
    // set trailingDecimal or trailingComma boolean to true for digitView preceding decimal point or comma
    private func updateDisplay() {
        clearDisplay()  // start with all blank digits
        // handle errors and sign of displayed number
        var modifiedDisplayString = displayString
        var errorDisplayed = false
        if displayString == "nan" || displayString == "inf" || displayString == "-inf"  {  // also handled in Brain.runProgram
            print(displayString.dropLast())
            modifiedDisplayString = "  Error  0"  // pws: +/-inf should show +/-9.9999999-99 blinking, rather than Error
            errorDisplayed = true
        } else if displayString.first != "-" {
            modifiedDisplayString = " " + displayString  // add leading blank, if number is positive
        }
        // set data for each digitView
        var displayIndex = 0
        var stringIndex = 0
        var decimalIndex = modifiedDisplayString.count - 1
        while displayIndex < numberOfDigits + 1 {  // look one more, in case decimal past last digit
            if stringIndex < modifiedDisplayString.count {
                let index = modifiedDisplayString.index(modifiedDisplayString.startIndex, offsetBy: stringIndex)
                let character = modifiedDisplayString[index]
                if character == "." {
                    displayIndex -= 1  // add decimal point to prior digitView (displayIndex will be one behind string index)
                    digitViews[displayIndex].trailingDecimal = true
                    decimalIndex = displayIndex
                } else if character == "e" {
                    exponentWasFound = true
                    displayIndex = 7  // will increment to 8, below
                } else if displayIndex < numberOfDigits {
                    // display this digit
                    digitViews[displayIndex].digit = character
                }
            }
            displayIndex += 1
            stringIndex += 1
        }
        // add commas every three digits before decimal point (or end of number, if no decimal point)
        if !errorDisplayed && decimalIndex < numberOfDigits {  // note: decimalIndex = 16, when pressing f-left-arrow (PREFIX)
            var commaIndex = decimalIndex - 3
            while commaIndex > 0 {
                digitViews[commaIndex].trailingComma = true
                commaIndex -= 3
            }
        }
    }
}
