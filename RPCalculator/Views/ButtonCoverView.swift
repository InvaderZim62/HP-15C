//
//  ButtonCoverView.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/5/21.
//
//                    .--------------.  ---
//                    | orange label |   | alternate height (14 points)
//  .--------------.  |--------------|  ---
//  |              |  |              |   |
//  |              |  |  white label |   |  primary height (button height - 14)
//  |              |  |              |   |
//  |              |  |--------------|  ---
//  |              |  |  blue label  |   | alternate height (14 points)
//  `--------------'  `--------------'  ---
//      UIButton       ButtonCoverView
//

import UIKit

struct CoverConst {
    static let alternateHeight: CGFloat = 14  // fixed, so it works with all buttons, including Enter
    static let keyTopColor = #colorLiteral(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)  // slightly lighter than black to look bevelled
    static let orangeColor = #colorLiteral(red: 0.81, green: 0.46, blue: 0.0, alpha: 1)
    static let whiteColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    static let blueColor = #colorLiteral(red: 0.38, green: 0.60, blue: 0.78, alpha: 1)
}

class ButtonCoverView: UIView {
    
    var orangeLabel = UILabel()
    var whiteLabel = UILabel()
    var blueLabel = UILabel()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init(buttonFrame: CGRect) {
        let primaryHeight = buttonFrame.height - CoverConst.alternateHeight
        
        let coverFrame = CGRect(x: buttonFrame.origin.x,
                                y: buttonFrame.origin.y - CoverConst.alternateHeight,
                                width: buttonFrame.width,
                                height: buttonFrame.height + CoverConst.alternateHeight)
        
        super.init(frame: coverFrame)
        
        isUserInteractionEnabled = false

        orangeLabel.frame = CGRect(x: 0,
                                   y: 0,
                                   width: coverFrame.width,
                                   height: CoverConst.alternateHeight)
        whiteLabel.frame = CGRect(x: 0,
                                  y: CoverConst.alternateHeight,
                                  width: coverFrame.width,
                                  height: primaryHeight)
        blueLabel.frame = CGRect(x: 0,
                                 y: CoverConst.alternateHeight + primaryHeight,
                                 width: coverFrame.width,
                                 height: CoverConst.alternateHeight)
        
        orangeLabel.textAlignment = .center
        whiteLabel.textAlignment = .center
        blueLabel.textAlignment = .center

        orangeLabel.textColor = CoverConst.orangeColor
        whiteLabel.textColor = CoverConst.whiteColor
        blueLabel.textColor = CoverConst.blueColor
        
        whiteLabel.backgroundColor = CoverConst.keyTopColor

        orangeLabel.font = orangeLabel.font.withSize(12)
        whiteLabel.font = whiteLabel.font.withSize(17)
        blueLabel.font = blueLabel.font.withSize(12)
        
        addSubview(orangeLabel)
        addSubview(whiteLabel)
        addSubview(blueLabel)
    }
}
