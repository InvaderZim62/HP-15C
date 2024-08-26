//
//  Matrix.swift
//  RPCalculator
//
//  Created by Phil Stern on 8/26/24.
//

import Foundation

struct Matrix: Codable {
    var oneDs = [String: [Double]]()  // [array name: 1D array]
    var twoDs = [String: [[Double]]]()  // [array name: 2D array]
    
    static let label = [
        "√x": "A",
        "ex": "B",
        "10x": "C",
        "yx": "D",
        "1/x": "E"
    ]
    
    mutating func setDimensionsFor(_ name: String, nRows: Int, nCols: Int) {
        twoDs[name] = Array(repeating: Array(repeating: 0, count: nCols), count: nRows)  // twoD[row][col]
    }
    
    func getDimensionsFor(_ name: String) -> (row: Int, col: Int) {
        guard let twoD = twoDs[name] else { return(0, 0) }
        return (row: twoD.count, col: twoD[0].count)
    }
    
    func printMatrices() {
        for twoD in twoDs {
            printMatrix(twoD.key)
        }
    }
    
    func printMatrix(_ name: String) {
        guard let twoD = twoDs[name] else { return }
        print("matrix \(Matrix.label[name]!):")
        for row in 0..<twoD.count {
            for col in 0..<twoD[0].count {
                print("\(twoDs[name]![row][col])", terminator: " ")
            }
            print()
        }
    }
}
