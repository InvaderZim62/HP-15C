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
    
    var brain: Brain!
    var program: Program!
    
    // code is similar to Solve.findRootOfEquationAt, except Solve quits when falpha is small
    // Owner's Handbook p.195
    //   HP-15C: 2.404005
    //   incr.    my app
    //   100000  2.403971 (very slow)
    //   10000   2.404254
    //   1000    2.407081
    //   100     2.435355
    // Owner's Handbook p.197
    //   HP-15C: 1.382460
    //     dx     my app
    //   10000   1.382460
    //   1000    1.382460
    //   100     1.382460
    
    // integration only accurate to around three decimal places
    func integrateAt(label: String, completion: @escaping () -> Void) {
        program.isAnyButtonPressed = false
        if program.gotoLabel(label) {
            // integrate from lower limit (in Y register) to upper limit (in X register)
            // leave result in X register
            if let lowerLimit = brain.yRegister as? Double,
               let upperLimit = brain.xRegister as? Double
            {
                let increments = 10000
                let dx = (upperLimit - lowerLimit) / Double(increments)
                var integral = 0.0
                for i in 0...increments {
                    let x = lowerLimit + Double(i) * dx
                    brain.fillRegistersWith(x)
                    program.runFrom(label: label) { [unowned self] in
                        let y = brain.xRegister as! Double
                        integral += y * dx  // Euler integration for area under curve
                    }
                }
                brain.xRegister = integral
                completion()
            }
        } else {
            delegate?.setError(4)  // label not found
        }
    }

}
