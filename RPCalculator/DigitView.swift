//
//  DigitView.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/6/21.
//
//   --            --     --            --     --     --     --     --
//  |  |      |      |      |   |  |   |      |         |   |  |   |  |
//                 --     --     --     --     --            --     --
//  |  |      |   |         |      |      |   |  |      |   |  |      |
//   --            --     --            --     --            --     --
//

import UIKit

struct DigitConst {
    static let topOffsetFactor: CGFloat = 0.05  // times view height (or width, if height > 2 width)
    static let segmentThicknessFactor: CGFloat = 0.28  // times segment length
    static let gapWidth: CGFloat = 0.6  // points
    static let periodOffsetFactor: CGFloat = 0.2  // times view width
    static let periodRadiusFactor: CGFloat = 0.1  // times view width
}

class DigitView: UIView {
    
    var digit: Character = " " { didSet { setNeedsDisplay() } }
    var trailingDecimal = false
    
    enum Segment {
        case upperCross
        case middleCross
        case lowerCross
        case upperLeft
        case upperRight
        case lowerLeft
        case lowerRight
    }
    
    func clear() {
        digit = " "
        trailingDecimal = false
    }
    
    private let allSegments: [Character: [Segment]] = [
        "0": [.upperCross, .upperLeft, .upperRight, .lowerLeft, .lowerRight, .lowerCross],
        "1": [.upperRight, .lowerRight],
        "2": [.upperCross, .upperRight, .middleCross, .lowerLeft, .lowerCross],
        "3": [.upperCross, .upperRight, .middleCross, .lowerRight, .lowerCross],
        "4": [.upperLeft, .upperRight, .middleCross, .lowerRight],
        "5": [.upperCross, .upperLeft, .middleCross, .lowerRight, .lowerCross],
        "6": [.upperCross, .upperLeft, .middleCross, .lowerLeft, .lowerRight, .lowerCross],
        "7": [.upperCross, .upperRight, .lowerRight],
        "8": [.upperCross, .upperLeft, .upperRight, .middleCross, .lowerLeft, .lowerRight, .lowerCross],
        "9": [.upperCross, .upperLeft, .upperRight, .middleCross, .lowerRight, .lowerCross],
        "-": [.middleCross],
        "E": [.upperCross, .upperLeft, .middleCross, .lowerLeft, .lowerCross],
        "e": [.upperCross, .upperLeft, .middleCross, .lowerLeft, .lowerCross],  // swift uses "e" for exponent (ex. 1.234e-02)
        "r": [.middleCross, .lowerLeft],
        "o": [.middleCross, .lowerLeft, .lowerRight, .lowerCross]
        // unlisted characters will appear as blanks
    ]

    override func draw(_ rect: CGRect) {
        var topOffset: CGFloat = 0
        if bounds.height > 2 * bounds.width {
            // if tall and narrow view, set topOffset so sides are topFactor times width from edges
            // Note: this was done before I added the decimal point, so it may have to be reworked
            topOffset = bounds.height / 2 - bounds.width + 2 * DigitConst.topOffsetFactor * bounds.width
        } else {
            topOffset = DigitConst.topOffsetFactor * bounds.height
        }
        let segmentLength = bounds.height / 2 - topOffset
        let segmentWidth = DigitConst.segmentThicknessFactor * segmentLength
        let periodOffset = DigitConst.periodOffsetFactor * bounds.width
        let periodRadius = DigitConst.periodRadiusFactor * bounds.width
        let segmentMidX = bounds.midX - (periodOffset + periodRadius) / 2
        
        let topLeftCorner = CGPoint(x: segmentMidX - segmentLength / 2, y: topOffset)
        let topRightCorner = CGPoint(x: segmentMidX + segmentLength / 2, y: topOffset)
        let middleLeftCorner = CGPoint(x: segmentMidX - segmentLength / 2, y: topOffset + segmentLength)
        let middleRightCorner = CGPoint(x: segmentMidX + segmentLength / 2, y: topOffset + segmentLength)
        let bottomLeftCorner = CGPoint(x: segmentMidX - segmentLength / 2, y: topOffset + 2 * segmentLength)
        let bottomRightCorner = CGPoint(x: segmentMidX + segmentLength / 2, y: topOffset + 2 * segmentLength)
        
        if let segments = allSegments[digit] {
            for segment in segments {
                // draw all paths from upper left corner, clockwise (let shape close itself)
                let shape = UIBezierPath()
                switch segment {
                case .upperCross:
                    shape.move(to: CGPoint(x: topLeftCorner.x + DigitConst.gapWidth, y: topLeftCorner.y))
                    shape.addLine(to: CGPoint(x: topRightCorner.x - DigitConst.gapWidth, y: topRightCorner.y))
                    shape.addLine(to: CGPoint(x: topRightCorner.x - segmentWidth - DigitConst.gapWidth, y: topRightCorner.y + segmentWidth))
                    shape.addLine(to: CGPoint(x: topLeftCorner.x + segmentWidth + DigitConst.gapWidth, y: topLeftCorner.y + segmentWidth))
                case .upperLeft:
                    shape.move(to: CGPoint(x: topLeftCorner.x, y: topLeftCorner.y + DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: topLeftCorner.x + segmentWidth, y: topLeftCorner.y + segmentWidth + DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x + segmentWidth, y: middleLeftCorner.y - segmentWidth / 2 - DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x, y: middleLeftCorner.y - DigitConst.gapWidth))
                case .upperRight:
                    shape.move(to: CGPoint(x: topRightCorner.x, y: topRightCorner.y + DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x, y: middleRightCorner.y - DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - segmentWidth, y: middleRightCorner.y - segmentWidth / 2 - DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: topRightCorner.x - segmentWidth, y: topRightCorner.y + segmentWidth + DigitConst.gapWidth))
                case .middleCross:
                    shape.move(to: CGPoint(x: middleLeftCorner.x + DigitConst.gapWidth, y: middleLeftCorner.y))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x + segmentWidth + DigitConst.gapWidth, y: middleLeftCorner.y - segmentWidth / 2))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - segmentWidth - DigitConst.gapWidth, y: middleRightCorner.y - segmentWidth / 2))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - DigitConst.gapWidth, y: middleRightCorner.y))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - segmentWidth - DigitConst.gapWidth, y: middleRightCorner.y + segmentWidth / 2))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x + segmentWidth + DigitConst.gapWidth, y: middleLeftCorner.y + segmentWidth / 2))
                case .lowerLeft:
                    shape.move(to: CGPoint(x: middleLeftCorner.x, y: middleLeftCorner.y + DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x + segmentWidth, y: middleLeftCorner.y + segmentWidth / 2 + DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: bottomLeftCorner.x + segmentWidth, y: bottomLeftCorner.y - segmentWidth - DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: bottomLeftCorner.x, y: bottomLeftCorner.y - DigitConst.gapWidth))
                case .lowerRight:
                    shape.move(to: CGPoint(x: middleRightCorner.x, y: middleRightCorner.y + DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: bottomRightCorner.x, y: bottomRightCorner.y - DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: bottomRightCorner.x - segmentWidth, y: bottomRightCorner.y - segmentWidth - DigitConst.gapWidth))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - segmentWidth, y: middleRightCorner.y + segmentWidth / 2 + DigitConst.gapWidth))
                case .lowerCross:
                    shape.move(to: CGPoint(x: bottomLeftCorner.x + DigitConst.gapWidth, y: bottomLeftCorner.y))
                    shape.addLine(to: CGPoint(x: bottomLeftCorner.x + segmentWidth + DigitConst.gapWidth, y: bottomLeftCorner.y - segmentWidth))
                    shape.addLine(to: CGPoint(x: bottomRightCorner.x - segmentWidth - DigitConst.gapWidth, y: bottomRightCorner.y - segmentWidth))
                    shape.addLine(to: CGPoint(x: bottomRightCorner.x - DigitConst.gapWidth, y: bottomRightCorner.y))
                }
                shape.fill()
            }
        }
        if trailingDecimal {
            let dotCenter = CGPoint(x: bottomRightCorner.x + periodOffset, y: bottomRightCorner.y - periodRadius)
            let dot = UIBezierPath(arcCenter: dotCenter,
                                   radius: periodRadius,
                                   startAngle: 0,
                                   endAngle: 2 * CGFloat.pi,
                                   clockwise: true)
            dot.fill()
        }
    }
}
