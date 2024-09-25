//
//  Integral.swift
//  RPCalculator
//
//  Created by Phil Stern on 9/23/24.
//

import UIKit

protocol IntegralDelegate: AnyObject {
    func setError(_ number: Int)
    var displayStringNumber: Double { get }
}

class Integral {
    
    weak var delegate: IntegralDelegate?
    
    var brain: Brain!
    var program: Program!
    
    // Owner's Handbook p.195
    //   HP-15C: 2.404005
    //   incrmt   Euler    Tustin
    //   ------  --------  --------
    //   100000  2.403971           (very slow)
    //   10000   2.404254  2.404254
    //   1000    2.407081  2.405510
    //   100     2.435355  2.419647
    //
    // Owner's Handbook p.197
    //   HP-15C: 1.382460
    //   incrmt   Euler    Tustin
    //   ------  --------  --------
    //   10000   1.382460  1.382617
    //   1000    1.382460  1.384030
    //   100     1.382460  1.398168
    
    // this integration is only accurate to around three decimal places
    // HP-15C integration accuracy (and time to solve) depends on the number
    // of decimal places selected for the display; this function does not
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
//                for i in 0...increments {
                for i in 1...increments-1 {  // handbook p.199 says "algorithm normally does not evaluate functions at either limit of integration"
                    let x = lowerLimit + Double(i) * dx  // = upperLimit, for i = increments
                    brain.fillRegistersWith(x)
                    program.runFrom(label: label) { [unowned self] in
                        let y = brain.xRegister as! Double
                        integral += y * dx  // Euler integration for area under curve
                    }
                }
                brain.xRegister = integral
                completion()
            } else {
                // integration limits are matrices
                DispatchQueue.main.async {
                    self.delegate?.setError(1)  // main queue, since setError changes prefix (changes falpha.alpha)
                }
                completion()
            }
        } else {
            // label not found
            DispatchQueue.main.async {
                self.delegate?.setError(4)  // main queue, since setError changes prefix (changes falpha.alpha)
            }
            completion()
        }
    }

}
