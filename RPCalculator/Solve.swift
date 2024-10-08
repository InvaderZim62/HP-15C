//
//  Solve.swift
//  RPCalculator
//
//  Created by Phil Stern on 7/2/24.
//

import UIKit

protocol SolveDelegate: AnyObject {
    func setError(_ number: Int)
    var displayStringNumber: Double { get }
}

class Solve {
    
    weak var delegate: SolveDelegate?
    
    var brain: Brain!
    var program: Program!
    
    var solveLoopCount = 0
    var alpha = 0.0
    var alphaPast = 0.0
    var beta = 0.0
    var falpha = 0.0
    var fbeta = 0.0
    var gamma = 0.0
    var leastPosFx = 0.0
    var leastNegFx = 0.0
    var xForLeastPosFx = 0.0
    var xForLeastNegFx = 0.0
    let plotMax = 30  // half width of error plot in spaces
    let errorScale = 10.0  // scale on residual f(x) for plotting

    var isRootFound: Bool {
        abs(falpha) < 1E-9
    }
    
    func findRootOfEquationAt(label: String, completion: @escaping () -> Void) {
        // assume user entered beta estimate and typed alpha estimate into display, before pressing SOLVE
        program.isAnyButtonPressed = false
        if program.gotoLabel(label) {
            if let xRegister = brain.xRegister as? Double,
               let yRegister = brain.yRegister as? Double {
                print(String(format: "\nSolving error (plot resolution: %.2f, plot limits: +/-%.1f)", 1 / errorScale, abs(Double(plotMax) / errorScale)))
                brain.isSolving = true  // suppress printMemory
                alpha = xRegister
                beta = yRegister
                alphaPast = alpha
                // fill all registers with alpha, run program, store results f(alpha)
                brain.fillRegistersWith(alpha)
                program.runFrom(label: label) { [unowned self] in  // run first time to get initial falpha; results left in display
                    falpha = delegate!.displayStringNumber
                    initializeBrackets()
                    solveLoopCount = 0
                    // run solve loop recursively, until root found
                    runSolveLoop(label: label) { [unowned self] in
                        // solve is done - store A, B, and G in X, Y, and Z registers and stop
                        brain.pushOperand(falpha)
                        brain.pushOperand(beta)
                        brain.pushOperand(alpha)
                        brain.isSolving = false
                        brain.printMemory()
                        completion()
                    }
                }
            } else {
                // alpha or beta is a matrix
                DispatchQueue.main.async {
                    self.delegate?.setError(1)  // main queue, since setError changes prefix (changes falpha.alpha)
                    print("bounds of SOLVE can't be a matrix")
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
    
    private func runSolveLoop(label: String, completion: @escaping () -> Void) {
        solveLoopCount += 1
        printSolveError()
        if solveLoopCount >= Constants.maxSolveIterations {  // pws: HP-15C uses more sophisticated methods to give up search
            print("root not found after \(solveLoopCount) iterations\n")
            delegate?.setError(8)
            completion()
        } else if isRootFound {
            print("root found in \(solveLoopCount) iterations\n")
            completion()
        } else {
            // fill all registers with beta, run program, store results f(beta)
            brain.fillRegistersWith(beta)
            program.runFrom(label: label) { [unowned self] in  // results left in display
                fbeta = delegate!.displayStringNumber
                computeGamma()
                // store beta, gamma, and f(beta) in place of alpha, beta, and f(alpha), and call recursively
                alphaPast = alpha
                alpha = beta
                beta = gamma
                falpha = fbeta
                runSolveLoop(label: label, completion: completion)
            }
        }
    }

    // compute gamma using Solve routine with A, B, f(A), f(B)
    // references:
    // William H. Kahan, https://people.eecs.berkeley.edu/~wkahan/Math128/SOLVEkey.pdf
    // Patrick, https://www.hpmuseum.org/cgi-sys/cgiwrap/hpmuseum/archv013.cgi?read=44372
    func computeGamma() {
        gamma = beta - (beta - alpha) * fbeta / (fbeta - falpha)  // secant method
        if fbeta > 0 && fbeta < leastPosFx {
            xForLeastPosFx = beta
            leastPosFx = fbeta
        }
        if fbeta < 0 && fbeta > leastNegFx {
            xForLeastNegFx = beta
            leastNegFx = fbeta
        }
        let xForBracketMax = max(xForLeastNegFx, xForLeastPosFx)
        let xForBracketMin = min(xForLeastNegFx, xForLeastPosFx)
        if gamma > xForBracketMax || gamma < xForBracketMin {
            // gamma outside bracket - bend gamma back inside
            var r: Double
            if gamma == beta {
                r = 0  // secant parallel to x-axis
            } else {
                r = (alphaPast - beta) / (gamma - beta)
            }
            let t = (2 - r) / (3 - 2 * r)
            gamma = beta + t * (alphaPast - beta)
        }
    }
    
    private func initializeBrackets() {
        leastPosFx = Double.greatestFiniteMagnitude
        leastNegFx = -Double.greatestFiniteMagnitude
        xForLeastPosFx = Double.greatestFiniteMagnitude
        xForLeastNegFx = -Double.greatestFiniteMagnitude
        if falpha > 0 {
            xForLeastPosFx = alpha
            leastPosFx = falpha
        } else {
            xForLeastNegFx = alpha
            leastNegFx = falpha
        }
    }

    private func printSolveError() {
        let scaledValue = min(max(falpha * errorScale, 0.99 * Double(Int.min)), 0.99 * Double(Int.max))  // keep scaledValue inside range of Int
        let error = min(max(Int(scaledValue), -plotMax), plotMax)
        if error < 0 {
            print(String(repeating: " ", count: plotMax + error) + "." + String(repeating: " ", count: -error - 1) + "|")
        } else if error == 0 {
            print(String(repeating: " ", count: plotMax) + ".")
        } else {  // error > 0
            print(String(repeating: " ", count: plotMax) + "|" + String(repeating: " ", count: error - 1) + ".")
        }
    }
}
