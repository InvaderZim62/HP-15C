//
//  Matrix.swift
//  RPCalculator
//
//  Created by Phil Stern on 8/26/24.
//

import UIKit
import simd  // for simd_doubleNxM...

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
    
    func copy() -> Matrix {
        let matrix = Matrix(name: self.name)
        matrix.values = self.values
        return matrix
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
    // matrix functions
    //----------------------------
    
    var inverse: Matrix? {
        guard rows <= 4 && cols <= 4 else { return nil }  // max dimension for simd is 4 x 4
        let matrix = Matrix()
        switch rows {
        case 2:
            let simdSelf = simd_double2x2(values.map { simd_double2($0) })
            let simdInverse = simdSelf.inverse
            matrix.values = (0..<2).map { [simdInverse[$0].x, simdInverse[$0].y] }
        case 3:
            let simdSelf = simd_double3x3(values.map { simd_double3($0) })
            let simdInverse = simdSelf.inverse
            matrix.values = (0..<3).map { [simdInverse[$0].x, simdInverse[$0].y, simdInverse[$0].z] }
        case 4:
            let simdSelf = simd_double4x4(values.map { simd_double4($0) })
            let simdInverse = simdSelf.inverse
            matrix.values = (0..<4).map { [simdInverse[$0].x, simdInverse[$0].y, simdInverse[$0].z, simdInverse[$0].w] }
        default:
            return nil
        }
        return matrix
    }
    
    var determinant: Double? {
        guard rows <= 4 && cols <= 4 else { return nil }  // max dimension for simd is 4 x 4
        switch rows {
        case 2:
            let simdSelf = simd_double2x2(values.map { simd_double2($0) })
            return simdSelf.determinant
        case 3:
            let simdSelf = simd_double3x3(values.map { simd_double3($0) })
            return simdSelf.determinant
        case 4:
            let simdSelf = simd_double4x4(values.map { simd_double4($0) })
            return simdSelf.determinant
        default:
            return nil
        }
    }

    var transpose: Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: cols, cols: rows)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = values[col][row]
            }
        }
        return matrix
    }
    
    // sum absolute values of elements in each row
    // return max of the sums
    var rowNorm: Double {
        var maxSum = 0.0
        for row in 0..<self.values.count {
            var sum = 0.0
            for col in 0..<self.values[0].count {
                sum += abs(self.values[row][col])
            }
            maxSum = max(maxSum, sum)
        }
        return maxSum
    }
    
    // square root of sum of squares of all elements
    var euclideanNorm: Double {
        var sumSquared = 0.0
        for row in 0..<self.values.count {
            for col in 0..<self.values[0].count {
                sumSquared += pow(self.values[row][col], 2)
            }
        }
        return sqrt(sumSquared)
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
    
    //----------------------------------------------------------------------------------
    
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
    
    //----------------------------------------------------------------------------------

    static func *(lhs: Matrix, rhs: Matrix) -> Matrix? {
        guard lhs.rows == rhs.cols && lhs.cols == rhs.rows else { return nil }
        let resultSize = lhs.rows
        let matrix = Matrix()
        matrix.setDimensions(rows: resultSize, cols: resultSize)
        for resultRow in 0..<resultSize {
            for resultCol in 0..<resultSize {
                var total = 0.0
                for i in 0..<lhs.cols {
                    total += lhs.values[resultRow][i] * rhs.values[i][resultCol]
                }
                matrix.values[resultRow][resultCol] = total
            }
        }
        return matrix
    }

    static func *(lhs: Matrix, rhs: Double) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: lhs.rows, cols: lhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs.values[row][col] * rhs
            }
        }
        return matrix
    }

    static func *(lhs: Double, rhs: Matrix) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: rhs.rows, cols: rhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs * rhs.values[row][col]
            }
        }
        return matrix
    }
    
    //----------------------------------------------------------------------------------

    static func /(lhs: Matrix, rhs: Double) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: lhs.rows, cols: lhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs.values[row][col] / rhs
            }
        }
        return matrix
    }

    static func /(lhs: Double, rhs: Matrix) -> Matrix {
        let matrix = Matrix()
        matrix.setDimensions(rows: rhs.rows, cols: rhs.cols)
        for row in 0..<matrix.rows {
            for col in 0..<matrix.cols {
                matrix.values[row][col] = lhs / rhs.values[row][col]
            }
        }
        return matrix
    }

    //----------------------------------------------------------------------------------

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
