//
//  CalculatorView.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/13/21.
//

import UIKit

struct CalcConst {
    static let orangeColor = #colorLiteral(red: 0.81, green: 0.46, blue: 0.0, alpha: 1)
    static let horizontalLineLength: CGFloat = 100
    static let verticalLineLength: CGFloat = 6
    static let lineGapToLabel: CGFloat = 4
}

class CalculatorView: UIView {
    
    var clearLabel = UILabel()

    // draw bracket around four buttons below CLEAR label
    override func draw(_ rect: CGRect) {
        clearLabel.textColor = CalcConst.orangeColor
        let clearLabelFront = CGPoint(x: clearLabel.frame.minX - CalcConst.lineGapToLabel, y: clearLabel.frame.midY)
        let clearLabelBack = CGPoint(x: clearLabel.frame.maxX + CalcConst.lineGapToLabel, y: clearLabel.frame.midY)
        let line = UIBezierPath()
        line.move(to: clearLabelFront)
        line.addLine(to: CGPoint(x: clearLabelFront.x - CalcConst.horizontalLineLength, y: clearLabelFront.y))
        line.addLine(to: CGPoint(x: clearLabelFront.x - CalcConst.horizontalLineLength, y: clearLabelFront.y + CalcConst.verticalLineLength))
        line.move(to: clearLabelBack)
        line.addLine(to: CGPoint(x: clearLabelBack.x + CalcConst.horizontalLineLength, y: clearLabelBack.y))
        line.addLine(to: CGPoint(x: clearLabelBack.x + CalcConst.horizontalLineLength, y: clearLabelBack.y + CalcConst.verticalLineLength))
        CalcConst.orangeColor.setStroke()
        line.stroke()
    }
}
