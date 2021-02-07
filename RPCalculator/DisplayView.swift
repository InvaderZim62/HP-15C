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
}

class DisplayView: UIView {
    
    var numberOfDigits = 0 { didSet { createDigitViews() } }
    var numberString = "0.0000" { didSet { updateDigits() } }
    var format = DisplayFormat.fixed(4)

    private var digitViews = [DigitView]()
    
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
    
    private func updateDigits() {
        clearDisplay()
        print(numberString)
        var displayString = numberString
        if numberString == "nan" || numberString == "inf" {
            displayString = "Error"
        } else if numberString.first != "-" {
            displayString = " " + numberString  // leave first digit blank, if number is positive
        }
        var displayIndex = 0
        var stringIndex = 0
        while displayIndex < numberOfDigits {
            if stringIndex < displayString.count {
                let index = displayString.index(displayString.startIndex, offsetBy: stringIndex)
                let character = displayString[index]
                if character == "." {
                    displayIndex -= 1  // add decimal point to prior digitView
                    digitViews[displayIndex].trailingDecimal = true
                } else {
                    digitViews[displayIndex].digit = character
                }
            }
            displayIndex += 1
            stringIndex += 1
        }
    }
}
