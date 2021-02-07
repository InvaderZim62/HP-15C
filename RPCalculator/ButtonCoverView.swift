//
//  ButtonCoverView.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/5/21.
//
//                    .--------------.  ---
//                    | orange label |   | alternate height
//  .--------------.  |--------------|  ---
//  |              |  |              |   |
//  |              |  |  white label |   |  primary height (65% of button height)
//  |              |  |              |   |
//  |              |  |--------------|  ---
//  |              |  |  blue label  |   | alternate height
//  `--------------'  `--------------'  ---
//      UIButton       ButtonCoverView
//

import UIKit

struct CoverConst {
    static let primaryHeightFactor: CGFloat = 0.65  // times buttonFrame.height = primary height
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
        let primaryHeight = buttonFrame.height * CoverConst.primaryHeightFactor
        let alternateHeight = buttonFrame.height * (1 - CoverConst.primaryHeightFactor)
        
        let coverFrame = CGRect(x: buttonFrame.origin.x,
                                y: buttonFrame.origin.y - alternateHeight,
                                width: buttonFrame.width,
                                height: buttonFrame.height + alternateHeight)
        
        super.init(frame: coverFrame)
        
        isUserInteractionEnabled = false

        orangeLabel.frame = CGRect(x: 0,
                                   y: 0,
                                   width: coverFrame.width,
                                   height: alternateHeight)
        whiteLabel.frame = CGRect(x: 0,
                                  y: alternateHeight,
                                  width: coverFrame.width,
                                  height: primaryHeight)
        blueLabel.frame = CGRect(x: 0,
                                 y: alternateHeight + primaryHeight,
                                 width: coverFrame.width,
                                 height: alternateHeight)
        
        orangeLabel.textAlignment = .center
        whiteLabel.textAlignment = .center
        blueLabel.textAlignment = .center

        orangeLabel.textColor = CoverConst.orangeColor
        whiteLabel.textColor = CoverConst.whiteColor
        blueLabel.textColor = CoverConst.blueColor

        orangeLabel.font = orangeLabel.font.withSize(12)
        whiteLabel.font = whiteLabel.font.withSize(17)
        blueLabel.font = blueLabel.font.withSize(12)
        
        addSubview(orangeLabel)
        addSubview(whiteLabel)
        addSubview(blueLabel)
    }
}
