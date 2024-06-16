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
//  Decimal points and commas are drawn with digit to its left.
//

import UIKit

class DisplayView: UIView {
    
    var numberOfDigits = 0 { didSet { createDigitViews() } }
    var displayString = "" { didSet { updateDisplay() } }
    var showCommas = true  // show commas, except when displaying mantissa (PREFIX)

    private var digitViews = [DigitView]()
    private var exponentWasFound = false
    
    func turnOnIf(_ isOn: Bool) {
        digitViews.forEach { $0.alpha = isOn ? 1 : 0 }
    }
    
    // program mode display three-digit line number followed by a dash
    var isProgramMode: Bool {
        if displayString.count > 3 {
            let index = displayString.index(displayString.startIndex, offsetBy: 3)
            return displayString[index] == "-"
        } else {
            return false
        }
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
    
    private func updateDisplay() {
        clearDisplay()  // start with all blank digits
        // handle errors and sign of displayed number
        var modifiedDisplayString = displayString
        var errorDisplayed = false
        if displayString.contains("Error") {
            print(displayString)
            errorDisplayed = true
        } else if displayString.first != "-" {
            modifiedDisplayString = " " + displayString  // add leading blank, if number is positive
        }
        // set data for each digitView
        var displayIndex = 0
        var stringIndex = 0
        while displayIndex < numberOfDigits + 1 {  // look one more, in case decimal past last digit
            if stringIndex < modifiedDisplayString.count {
                let index = modifiedDisplayString.index(modifiedDisplayString.startIndex, offsetBy: stringIndex)
                let character = modifiedDisplayString[index]
                if character == "." {
                    displayIndex -= 1  // add decimal point to prior digitView (displayIndex will be one behind string index)
                    digitViews[displayIndex].trailingDecimal = true
                } else if character == "," {  // displaying program
                    displayIndex -= 1  // add comma to prior digitView (displayIndex will be one behind string index)
                    digitViews[displayIndex].trailingComma = true
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
        // add commas every three digits before decimal point (or end of number,
        // if no decimal point), except when displaying mantissa (PREFIX)
        if !errorDisplayed && !isProgramMode && showCommas {
            var endIndex: Int
            if let i = modifiedDisplayString.firstIndex(of: ".") {
                endIndex = modifiedDisplayString.distance(from: modifiedDisplayString.startIndex, to: i) - 1  // ex. "1234.0" -> "1,234.0"
            } else if let i = modifiedDisplayString.dropFirst().firstIndex(of: " ") {
                endIndex = modifiedDisplayString.distance(from: modifiedDisplayString.startIndex, to: i) - 1  // ex. "1234  05" -> "1,234  05"
            } else {
                endIndex = min(modifiedDisplayString.count - 1, numberOfDigits - 4)                           // ex. "1234" -> "1,234"
            }
            var commaIndex = endIndex - 3
            while commaIndex > 0 {
                digitViews[commaIndex].trailingComma = true
                commaIndex -= 3
            }
        }
    }
}
