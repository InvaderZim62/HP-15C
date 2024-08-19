//
//  DisplayFormat.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/25/21.
//

import Foundation

enum DisplayFormat: Codable {
    case fixed(Int)  // (decimal places)
    case scientific(Int)  // (decimal places)
    case engineering(Int)  // (additional digits) similar to scientific, except exponent is always a multiple of three
    
    var string: String {  // usage: String(format: displayFormat.string, number)
        switch self {
        case .fixed(let decimalPlaces):
            return "%.\(decimalPlaces)f"
        case .scientific(let decimalPlaces):
            return "%.\(decimalPlaces)e"
        case .engineering(let additionalDigits):
            return "%.\(additionalDigits)e"  // engineering format can't be done through string alone (see runAndUpdateInterface)
        }
    }
    
    var decimals: Int {
        switch self {
        case .fixed(let decimals):
            return decimals
        case .scientific(let decimals):
            return decimals
        case .engineering(let decimals):
            return decimals
        }
    }
}
