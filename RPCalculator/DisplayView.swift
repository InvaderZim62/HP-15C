//
//  DisplayView.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/6/21.
//
//  Display "cells" can be energized to create any digit, sign, decimal, or comma
//
//        --     --     --
//       |  |   |  |   |  |
//  ---   --     --     --    ...10 digits
//       |  |   |  |   |  |
//        --  .  --  .  --  .
//            '      '      '
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
        let leftInset: CGFloat = 35
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
    
    private func updateDigits() {
        var digitNumber = 0
        for index in 0..<numberOfDigits {
            if index < numberString.count {
                let stringIndex = numberString.index(numberString.startIndex, offsetBy: index)
                let character = numberString[stringIndex]
                if character == "." {
                    digitNumber -= 1
                    digitViews[digitNumber].trailingDecimal = true
                } else {
                    digitViews[digitNumber].digit = character
                    digitViews[digitNumber].trailingDecimal = false
                }
            } else {
                digitViews[digitNumber].digit = " "
                digitViews[digitNumber].trailingDecimal = false
            }
            digitNumber += 1
        }
    }
}
