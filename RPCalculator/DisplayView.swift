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
//  Decimal point is drawn with prior digit.
//

import UIKit

enum DisplayFormat {
    case fixed(Int)  // (decimal places)
    case scientific(Int)  // (decimal places)
    case engineering(Int)  // (display digits) similar to scientific, except exponent is always a multiple of three
    
    var string: String {
        switch self {
        case .fixed(let decimalPlaces):
            return "%.\(decimalPlaces)f"
        case .scientific(let decimalPlaces):
            return "%.\(decimalPlaces)e"
        default:
            return "%g"
        }
    }
}

class DisplayView: UIView {
    
    var numberOfDigits = 0 { didSet { createDigitViews() } }
    var displayString = "0.0000" { didSet { updateDisplay() } }
    var format = DisplayFormat.fixed(4)  // pws: consider moving this up to CalculatorViewController

    private var digitViews = [DigitView]()
    private var exponentWasFound = false
    
    // create equally sized digitViews and add them to this DisplayView, leaving the specified
    // boarder (inset) around the digitViews
    func createDigitViews() {
        digitViews.forEach { $0.removeFromSuperview() }  // remove any past views and start over
        digitViews.removeAll()
        let leftInset: CGFloat = 10
        let rightInset: CGFloat = 15
        let topInset: CGFloat = 10
        let bottomInset: CGFloat = 0.3 * bounds.height
        let digitViewWidth = (bounds.width - leftInset - rightInset) / CGFloat(numberOfDigits)
        for index in 0..<numberOfDigits {
            let digitView = DigitView(frame: CGRect(x: digitViewWidth * CGFloat(index) + leftInset,
                                                    y: topInset, width: digitViewWidth, height: bounds.height - topInset - bottomInset))
            digitView.backgroundColor = .clear
            addSubview(digitView)
            digitViews.append(digitView)
        }
    }
    
    private func clearDisplay() {
        digitViews.forEach { $0.clear() }
    }
    
    // set the digit character for each of the digitViews, drawn from numberString
    // set the trailingDecimal boolean to true for the digitView preceding the decimal point
    private func updateDisplay() {
        clearDisplay()  // start with all blank digits
        var modifiedDisplayString = displayString
        if displayString == "nan" || displayString == "inf" {
            modifiedDisplayString = "Error"
        } else if displayString.first != "-" {
            modifiedDisplayString = " " + displayString  // leave first digit blank, if number is positive
        }
        var displayIndex = 0
        var stringIndex = 0
        while displayIndex < numberOfDigits {
            if stringIndex < modifiedDisplayString.count {
                let index = modifiedDisplayString.index(modifiedDisplayString.startIndex, offsetBy: stringIndex)
                let character = modifiedDisplayString[index]
                if character == "." {
                    displayIndex -= 1  // add decimal point to prior digitView
                    digitViews[displayIndex].trailingDecimal = true
                } else if character == "e" {
                    exponentWasFound = true
                    displayIndex = 7  // will increment to 8, below
                } else {
                    // display this digit
                    digitViews[displayIndex].digit = character
                }
            }
            displayIndex += 1
            stringIndex += 1
        }
    }
}
