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
    
    // mid point integration and error estimate reference: https://math.libretexts.org/Courses/Mount_Royal_University/MATH_2200%3A_Calculus_for_Scientists_II/2%3A_Techniques_of_Integration/2.5%3A_Numerical_Integration_-_Midpoint%2C_Trapezoid%2C_Simpson's_rule

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
                let increments = 100
                let dx = (upperLimit - lowerLimit) / Double(increments)
                var yPast = 0.0
                var dyDx = 0.0
                var dyDxPast = 0.0
                var dyDxDx = 0.0
                var dyDxDxMax = 0.0
                var integral = 0.0
                for i in 0..<increments {  // handbook p.199 says "algorithm normally does not evaluate functions at either limit of integration"
                    let x = lowerLimit + (Double(i) + 0.5) * dx  // half-way to next i
                    brain.fillRegistersWith(x)
                    program.runFrom(label: label) { [unowned self] in
                        
                        let y = brain.xRegister as! Double
                        integral += y * dx  // Euler integration for area under curve
                        
                        dyDx = (y - yPast) / dx  // f'(x)
                        dyDxDx = (dyDx - dyDxPast) / dx  // f''(x)
                        if i > 1 && abs(dyDxDx) > dyDxDxMax { dyDxDxMax = abs(dyDxDx) }  // f''(x)_max
                        yPast = y
                        dyDxPast = dyDx
                    }
                }
                let integrationError = dyDxDxMax * (upperLimit - lowerLimit) / 24 / pow(Double(increments), 2)
                
                brain.pushOperand(lowerLimit)
                brain.pushOperand(upperLimit)
                brain.pushOperand(integrationError)
                brain.pushOperand(integral)
                completion()
            } else {
                // integral limits are matrices
                DispatchQueue.main.async {
                    self.delegate?.setError(1)  // main queue, since setError changes prefix (changes falpha.alpha)
                    print("integral limits are matrices")
                }
                completion()
            }
        } else {
            // label not found
            DispatchQueue.main.async {
                self.delegate?.setError(4)  // main queue, since setError changes prefix (changes falpha.alpha)
                print("goto label \(label) not found")
            }
            completion()
        }
    }

}
