//
//  Statistics.swift
//  RPCalculator
//
//  Created by Phil Stern on 9/23/24.
//

import UIKit

protocol StatisticsDelegate: AnyObject {
    func setError(_ number: Int)
}

class Statistics {
    
    weak var delegate: StatisticsDelegate?
    
    var brain: Brain!
    
    func addRemovePoint(isAdd: Bool) {
        if let x = brain.xRegister as? Double,
           let y = brain.yRegister as? Double,
           let n = brain.valueFromStorageRegister("2") as? Double,
           let sumX = brain.valueFromStorageRegister("3") as? Double,
           let sumX2 = brain.valueFromStorageRegister("4") as? Double,
           let sumY = brain.valueFromStorageRegister("5") as? Double,
           let sumY2 = brain.valueFromStorageRegister("6") as? Double,
           let sumXY = brain.valueFromStorageRegister("7") as? Double
        {
            if isAdd {
                _ = brain.storeValueInRegister("2", value: n + 1)
                _ = brain.storeValueInRegister("3", value: sumX + x)
                _ = brain.storeValueInRegister("4", value: sumX2 + x * x)
                _ = brain.storeValueInRegister("5", value: sumY + y)
                _ = brain.storeValueInRegister("6", value: sumY2 + y * y)
                _ = brain.storeValueInRegister("7", value: sumXY + x * y)
            } else {
                _ = brain.storeValueInRegister("2", value: n - 1)
                _ = brain.storeValueInRegister("3", value: sumX - x)
                _ = brain.storeValueInRegister("4", value: sumX2 - x * x)
                _ = brain.storeValueInRegister("5", value: sumY - y)
                _ = brain.storeValueInRegister("6", value: sumY2 - y * y)
                _ = brain.storeValueInRegister("7", value: sumXY - x * y)
            }
            brain.lastXRegister = x
            brain.xRegister = brain.valueFromStorageRegister("2")  // leave number of data points in X register to be displayed
        } else {
            // matrix stored in X or Y register, or one of the statistics registers
            delegate?.setError(1)
            print("statistics can't be performed with matrices")
        }
    }
    
    func mean() {
        if let n = brain.valueFromStorageRegister("2") as? Double,
           let sumX = brain.valueFromStorageRegister("3") as? Double,
           let sumY = brain.valueFromStorageRegister("5") as? Double
        {
            if n == 0 {
                delegate?.setError(2)
            } else {
                brain.pushOperand(sumY / n)  // mean of Y data points
                brain.pushOperand(sumX / n)  // mean of X data points
            }
        } else {
            // matrix stored in one of the statistics register
            delegate?.setError(1)
            print("mean can't be performed with matrices")
        }
    }
    
    func standardDeviation() {
        if let n = brain.valueFromStorageRegister("2") as? Double,
           let sumX = brain.valueFromStorageRegister("3") as? Double,
           let sumX2 = brain.valueFromStorageRegister("4") as? Double,
           let sumY = brain.valueFromStorageRegister("5") as? Double,
           let sumY2 = brain.valueFromStorageRegister("6") as? Double
        {
            if n <= 1 {
                delegate?.setError(2)
            } else {
                let M = n * sumX2 - sumX * sumX
                let N = n * sumY2 - sumY * sumY
                let den = n * (n - 1)
                brain.pushOperand(sqrt(N / den))  // std dev of Y data points
                brain.pushOperand(sqrt(M / den))  // std dev of X data points
            }
        } else {
            // matrix stored in one of the statistics register
            delegate?.setError(1)
            print("standard deviation can't be performed with matrices")
        }
    }
    
    func lineFit() {
        if let n = brain.valueFromStorageRegister("2") as? Double,
           let sumX = brain.valueFromStorageRegister("3") as? Double,
           let sumX2 = brain.valueFromStorageRegister("4") as? Double,
           let sumY = brain.valueFromStorageRegister("5") as? Double,
           let sumXY = brain.valueFromStorageRegister("7") as? Double
        {
            if n <= 1 {
                delegate?.setError(2)
            } else {
                let P = n * sumXY - sumX * sumY
                let M = n * sumX2 - sumX * sumX
                brain.pushOperand(P / M)  // slope of line
                brain.pushOperand((M * sumY - P * sumX) / n / M)  // y-intercept of line
            }
        } else {
            // matrix stored in one of the statistics register
            delegate?.setError(1)
            print("line fit can't be performed with matrices")
        }
    }
    
    func linearEstimation() {
        if let x = brain.xRegister as? Double,
           let n = brain.valueFromStorageRegister("2") as? Double,
           let sumX = brain.valueFromStorageRegister("3") as? Double,
           let sumX2 = brain.valueFromStorageRegister("4") as? Double,
           let sumY = brain.valueFromStorageRegister("5") as? Double,
           let sumY2 = brain.valueFromStorageRegister("6") as? Double,
           let sumXY = brain.valueFromStorageRegister("7") as? Double
        {
            if n <= 1 {
                delegate?.setError(2)
            } else {
                let P = n * sumXY - sumX * sumY
                let M = n * sumX2 - sumX * sumX
                let N = n * sumY2 - sumY * sumY
                brain.pushOperand(P / sqrt(M * N))  // correlation coefficient of line (-1 < c < 1, -1: perfect neg correl, 1: perfect pos correl)
                brain.pushOperand((M * sumY + P * (n * x - sumX)) / n / M)  // y-estimate of point on line
            }
        } else {
            // matrix stored in one of the statistics register
            delegate?.setError(1)
            print("linear estimation can't be performed with matrices")
        }
    }
}
