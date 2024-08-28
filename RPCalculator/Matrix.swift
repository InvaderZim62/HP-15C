//
//  Matrix.swift
//  RPCalculator
//
//  Created by Phil Stern on 8/26/24.
//

import Foundation

struct Matrix: Codable {
    var matrices = [String: [[Double]]]()  // [matrix name: 2D array], access using matrices[name][row][col]
    
    static let labels = [
        "√x": "A",
        "ex": "B",
        "10x": "C",
        "yx": "D",
        "1/x": "E"
    ]
    
    mutating func setDimensionsFor(_ name: String, rows: Int, cols: Int) {
        if rows > 0 && cols > 0 {
            matrices[name] = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        } else {
            matrices[name] = nil
        }
    }
    
    func getDimensionsFor(_ name: String) -> (rows: Int, cols: Int) {
        guard let matrix = matrices[name] else { return(0, 0) }
        return getDimensionsFor(matrix)
    }
    
    func getDimensionsFor(_ matrix: [[Double]]) -> (rows: Int, cols: Int) {
        (rows: matrix.count, cols: matrix[0].count)
    }
    
    // note: row and col are 1-based indices, matrices are 0-based
    mutating func storeValueFor(_ name: String, row: Int, col: Int, to value: Double) -> Bool {
        guard let matrix = matrices[name] else { return false }  // note: matrix is a copy
        let (rows, cols) = getDimensionsFor(matrix)
        if row <= rows && col <= cols {
            matrices[name]![row - 1][col - 1] = value
            return true
        } else {
            return false
        }
    }
    
    // note: row and col are 1-based indices, matrices are 0-based
    func recallValueFor(_ name: String, row: Int, col: Int) -> Double? {
        guard let matrix = matrices[name] else { return nil }  // note: matrix is a copy
        let (rows, cols) = getDimensionsFor(matrix)
        if row <= rows && col <= cols {
            return matrices[name]![row - 1][col - 1]
        } else {
            return nil
        }
    }
    
    // wrap col, then row, then return to start for input matrix
    // assumes matrices[name] exists and row and col are within its dimensions
    // (ok, if called after storeValueFor or recallValueFor)
    // note: row and col are 1-based indices, matrices are 0-based
    func incrementRowColFor(_ name: String, row: Int, col: Int) -> (Int, Int) {
        var nextRow = row
        var nextCol = col
        let (rows, cols) = getDimensionsFor(matrices[name]!)
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

    func printMatrices() {
        for matrix in matrices {
            printMatrix(matrix.key)
        }
    }
    
    func printMatrix(_ name: String) {
        guard let matrix = matrices[name] else { return }
        print("matrix \(Matrix.labels[name]!):")
        for row in 0..<matrix.count {
            for col in 0..<matrix[0].count {
                print("\(matrices[name]![row][col])", terminator: " ")
            }
            print()
        }
    }
}
