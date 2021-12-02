//
//  DisplayFormat.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/25/21.
//

import Foundation

enum DisplayFormat: Codable {  // pws: move to its own file?
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
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey { case fixed, scientific, engineering }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(Int.self, forKey: .fixed) {
            self = .fixed(value)
        } else if let value = try? container.decode(Int.self, forKey: .scientific) {
            self = .fixed(value)
        } else if let value = try? container.decode(Int.self, forKey: .engineering) {
            self = .fixed(value)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Data doesn't match"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fixed(let decimalPlaces):
            try container.encode(decimalPlaces, forKey: .fixed)
        case .scientific(let decimalPlaces):
            try container.encode(decimalPlaces, forKey: .scientific)
        case .engineering(let additionalDigits):
            try container.encode(additionalDigits, forKey: .engineering)
        }
    }
}
