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
    
    mutating func setDimensionsFor(_ name: String, nRows: Int, nCols: Int) {
        if nRows > 0 && nCols > 0 {
            matrices[name] = Array(repeating: Array(repeating: 0, count: nCols), count: nRows)
        } else {
            matrices[name] = nil
        }
    }
    
    func getDimensionsFor(_ name: String) -> (row: Int, col: Int) {
        guard let matrix = matrices[name] else { return(0, 0) }
        return (row: matrix.count, col: matrix[0].count)
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
