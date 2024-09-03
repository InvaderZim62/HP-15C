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

//    // MARK: - Codable
//
//    private enum CodingKeys: String, CodingKey { case name, values }
//
//    required init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.name = try container.decode(String.self, forKey: .name)
//        self.values = try container.decode([[Double]].self, forKey: .values)
//    }
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(self.name, forKey: .name)
//        try container.encode(self.values, forKey: .values)
//    }

    var rows: Int {
        values.count
    }
    
    var cols: Int {
        guard rows > 0 else { return 0 }
        return values[0].count
    }
    
    var descriptor: String {
        String(format: "%@ %5d %2d", name, rows, cols)
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

    static func +(lhs: Matrix, rhs: Matrix) -> Matrix? {
        guard lhs.rows == rhs.rows && lhs.cols == rhs.cols else { return nil }
        let matrix = Matrix()
        matrix.setDimensions(rows: lhs.rows, cols: lhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs.values[row][col] + rhs.values[row][col]
            }
        }
        return matrix
    }

    static func +(lhs: Matrix, rhs: Double) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: lhs.rows, cols: lhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs.values[row][col] + rhs
            }
        }
        return matrix
    }

    static func +(lhs: Double, rhs: Matrix) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: rhs.rows, cols: rhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs + rhs.values[row][col]
            }
        }
        return matrix
    }

    static func -(lhs: Matrix, rhs: Matrix) -> Matrix? {
        guard lhs.rows == rhs.rows && lhs.cols == rhs.cols else { return nil }
        let matrix = Matrix()
        matrix.setDimensions(rows: lhs.rows, cols: lhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs.values[row][col] - rhs.values[row][col]
            }
        }
        return matrix
    }

    static func -(lhs: Matrix, rhs: Double) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: lhs.rows, cols: lhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs.values[row][col] - rhs
            }
        }
        return matrix
    }

    static func -(lhs: Double, rhs: Matrix) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: rhs.rows, cols: rhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs - rhs.values[row][col]
            }
        }
        return matrix
    }

    //----------------------------
    // unary operator
    //----------------------------

    static prefix func -(rhs: Matrix) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: rhs.rows, cols: rhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = -rhs.values[row][col]
            }
        }
        return matrix
    }
}
