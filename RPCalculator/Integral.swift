//
//  Integral.swift
//  RPCalculator
//
//  Created by Phil Stern on 9/23/24.
//

import UIKit

protocol IntegralDelegate: AnyObject {
    func setError(_ number: Int)
}

class Integral {
    
    weak var delegate: IntegralDelegate?
    
    var program: Program!

    func integrateAt(label: String, completion: @escaping () -> Void) {
        if program.gotoLabel(label) {
        } else {
            delegate?.setError(4)  // label not found
        }
    }
}
