//
//  Matrix.swift
//  RPCalculator
//
//  Created by Phil Stern on 8/26/24.
//

import UIKit

class Matrix: Codable, Stackable, CustomStringConvertible {
    var name: String  // "A" - "E"
    var values: [[Double]]
    
    init(name: String) {
        self.name = name
        self.values = [[Double]]()
    }
    
    convenience init() {
        self.init(name: "")
    }

    var rows: Int {
        values.count
    }
    
    var cols: Int {
        guard rows > 0 else { return 0 }
        return values[0].count
    }
    
    static let names = [  // button title: matrix name
        "√x": "A",
        "ex": "B",
        "10x": "C",
        "yx": "D",
        "1/x": "E"
    ]
    
    func setDimensions(rows: Int, cols: Int) {
        if rows > 0 && cols > 0 {
            values = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        } else {
            values = []
        }
    }
    
    // note: row and col are 1-based indices, matrices are 0-based
    func storeValue(_ value: Double, atRow row: Int, col: Int) -> Bool {
        if row <= rows && col <= cols {
            values[row - 1][col - 1] = value
            return true
        } else {
            return false
        }
    }
    
    // note: row and col are 1-based indices, matrices are 0-based
    func recallValue(atRow row: Int, col: Int) -> Double? {
        if row <= rows && col <= cols {
            return values[row - 1][col - 1]
        } else {
            return nil
        }
    }
    
    // wrap col, then row, then return to start for input matrix
    // assumes matrices[name] exists and row and col are within its dimensions
    // (ok, if called after storeValueFor or recallValueFor)
    // note: row and col are 1-based indices, matrices are 0-based
    func incrementRowCol(row: Int, col: Int) -> (Int, Int) {
        var nextRow = row
        var nextCol = col
        if col < cols {
            nextCol = col + 1
        } else if row < rows {
            nextRow = row + 1
            nextCol = 1
        } else {
            nextRow = 1
            nextCol = 1
        }
        return (nextRow, nextCol)
    }
    
    var description: String {
        var descriptionString = "matrix \(name):\n"
        for row in 0..<rows {
            for col in 0..<cols {
                descriptionString += " \(values[row][col])"
            }
            descriptionString += "\n"
        }
        return descriptionString
    }

    //----------------------------
    // math functions
    //----------------------------

    // (a + bi) - (c + di) = (a - c) + (b - d)i
    static func +(lhs: Matrix, rhs: Matrix) -> Matrix {
        var matrix = Matrix()
        matrix.setDimensions(rows: lhs.rows, cols: lhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs.values[row][col] + rhs.values[row][col]
            }
        }
        return matrix
    }
}
