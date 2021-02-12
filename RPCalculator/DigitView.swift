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
//  Note: The real HP-15C has a rectangular dash in the first position for the minus sign (versus using a
//  complete digit with only the middleCross drawn for a minus sign).  That also means, words like Error
//  start at the second digit.
//

import UIKit

struct DigitConst {
    static let topOffsetFactor: CGFloat = 0.05  // offset of upperCross below view top (times view height or width, if height > 2 width)
    static let upperSegmentFraction: CGFloat = 0.47
    static let segmentThicknessFactor: CGFloat = 0.15  // (times view width)
    static let gapWidthFactor: CGFloat = 0.022  // (times view width)
    static let periodOffsetFactor: CGFloat = 0.11  // (times view width)
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
        let topOffset: CGFloat = DigitConst.topOffsetFactor * bounds.height
        let segmentThickness = DigitConst.segmentThicknessFactor * bounds.width
        let digitHeight = bounds.height - 2 * topOffset
        let upperSegmentHeight = digitHeight * DigitConst.upperSegmentFraction
        let lowerSegmentHeight = digitHeight * (1 - DigitConst.upperSegmentFraction)
        let lowerInnerBoxLength = lowerSegmentHeight - 3 * segmentThickness / 2
        let digitWidth = lowerInnerBoxLength + 2 * segmentThickness
        
        let gapWidth = DigitConst.gapWidthFactor * bounds.width
        let periodOffset = DigitConst.periodOffsetFactor * bounds.width
        let periodWidth = 1.1 * segmentThickness
        let segmentMidX = bounds.midX - (periodOffset + periodWidth) / 2

        let topLeftCorner = CGPoint(x: segmentMidX - digitWidth / 2, y: topOffset)
        let topRightCorner = CGPoint(x: segmentMidX + digitWidth / 2, y: topOffset)
        let middleLeftCorner = CGPoint(x: segmentMidX - digitWidth / 2, y: topOffset + upperSegmentHeight)
        let middleRightCorner = CGPoint(x: segmentMidX + digitWidth / 2, y: topOffset + upperSegmentHeight)
        let bottomLeftCorner = CGPoint(x: segmentMidX - digitWidth / 2, y: bounds.height - topOffset)
        let bottomRightCorner = CGPoint(x: segmentMidX + digitWidth / 2, y: bounds.height - topOffset)
        
        if let segments = allSegments[digit] {
            for segment in segments {
                // draw all paths from upper left corner, clockwise (let shape close itself)
                let shape = UIBezierPath()
                switch segment {
                case .upperCross:
                    shape.move(to: CGPoint(x: topLeftCorner.x + gapWidth, y: topLeftCorner.y))
                    shape.addLine(to: CGPoint(x: topRightCorner.x - gapWidth, y: topRightCorner.y))
                    shape.addLine(to: CGPoint(x: topRightCorner.x - segmentThickness - gapWidth, y: topRightCorner.y + segmentThickness))
                    shape.addLine(to: CGPoint(x: topLeftCorner.x + segmentThickness + gapWidth, y: topLeftCorner.y + segmentThickness))
                case .upperLeft:
                    shape.move(to: CGPoint(x: topLeftCorner.x, y: topLeftCorner.y + gapWidth))
                    shape.addLine(to: CGPoint(x: topLeftCorner.x + segmentThickness, y: topLeftCorner.y + segmentThickness + gapWidth))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x + segmentThickness, y: middleLeftCorner.y - segmentThickness / 2 - gapWidth))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x, y: middleLeftCorner.y - gapWidth))
                case .upperRight:
                    shape.move(to: CGPoint(x: topRightCorner.x, y: topRightCorner.y + gapWidth))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x, y: middleRightCorner.y - gapWidth))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - segmentThickness, y: middleRightCorner.y - segmentThickness / 2 - gapWidth))
                    shape.addLine(to: CGPoint(x: topRightCorner.x - segmentThickness, y: topRightCorner.y + segmentThickness + gapWidth))
                case .middleCross:
                    shape.move(to: CGPoint(x: middleLeftCorner.x + gapWidth, y: middleLeftCorner.y))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x + segmentThickness + gapWidth, y: middleLeftCorner.y - segmentThickness / 2))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - segmentThickness - gapWidth, y: middleRightCorner.y - segmentThickness / 2))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - gapWidth, y: middleRightCorner.y))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - segmentThickness - gapWidth, y: middleRightCorner.y + segmentThickness / 2))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x + segmentThickness + gapWidth, y: middleLeftCorner.y + segmentThickness / 2))
                case .lowerLeft:
                    shape.move(to: CGPoint(x: middleLeftCorner.x, y: middleLeftCorner.y + gapWidth))
                    shape.addLine(to: CGPoint(x: middleLeftCorner.x + segmentThickness, y: middleLeftCorner.y + segmentThickness / 2 + gapWidth))
                    shape.addLine(to: CGPoint(x: bottomLeftCorner.x + segmentThickness, y: bottomLeftCorner.y - segmentThickness - gapWidth))
                    shape.addLine(to: CGPoint(x: bottomLeftCorner.x, y: bottomLeftCorner.y - gapWidth))
                case .lowerRight:
                    shape.move(to: CGPoint(x: middleRightCorner.x, y: middleRightCorner.y + gapWidth))
                    shape.addLine(to: CGPoint(x: bottomRightCorner.x, y: bottomRightCorner.y - gapWidth))
                    shape.addLine(to: CGPoint(x: bottomRightCorner.x - segmentThickness, y: bottomRightCorner.y - segmentThickness - gapWidth))
                    shape.addLine(to: CGPoint(x: middleRightCorner.x - segmentThickness, y: middleRightCorner.y + segmentThickness / 2 + gapWidth))
                case .lowerCross:
                    shape.move(to: CGPoint(x: bottomLeftCorner.x + gapWidth, y: bottomLeftCorner.y))
                    shape.addLine(to: CGPoint(x: bottomLeftCorner.x + segmentThickness + gapWidth, y: bottomLeftCorner.y - segmentThickness))
                    shape.addLine(to: CGPoint(x: bottomRightCorner.x - segmentThickness - gapWidth, y: bottomRightCorner.y - segmentThickness))
                    shape.addLine(to: CGPoint(x: bottomRightCorner.x - gapWidth, y: bottomRightCorner.y))
                }
                shape.fill()
            }
        }
        if trailingDecimal {
            let rect = CGRect(x: bottomRightCorner.x + periodOffset,
                              y: bottomRightCorner.y - 1.1 * periodWidth,
                              width: periodWidth,
                              height: periodWidth)
            let square = UIBezierPath(roundedRect: rect, cornerRadius: 1.2)
            square.fill()
        }
    }
}
