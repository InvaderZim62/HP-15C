//
//  Solve.swift
//  RPCalculator
//
//  Created by Phil Stern on 7/2/24.
//

import Foundation

protocol SolveDelegate: AnyObject {
    func setError(_ number: Int)
    func updateDisplayString()
    var displayStringNumber: Double { get }
}

class Solve {
    
    weak var delegate: SolveDelegate?
    
    var brain: CalculatorBrain!
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
    
    func findRootOfEquationAt(label: String) {
        // assume user entered beta estimate and typed alpha estimate into display, before pressing SOLVE
        if program.gotoLabel(label) {
            print(String(format: "\nSolving error (plot resolution: %.2f, plot limits: +/-%.1f)", 1 / errorScale, abs(Double(plotMax) / errorScale)))
            brain.isSolving = true  // suppress printMemory
            alpha = delegate!.displayStringNumber
            alphaPast = alpha
            beta = brain.xRegister!
            // fill all registers with alpha, run program, store results f(alpha)
            brain.fillRegistersWith(alpha)
            program.runFrom(label: label) { [unowned self] in  // results left in display
                falpha = delegate!.displayStringNumber
                initializeBrackets()
                solveLoopCount = 0
                // run solve loop recursively, until root found
                runSolveLoop(label: label) { [unowned self] in
                    // store A, B, and G in X, Y, and Z registers and stop
                    brain.pushOperand(falpha)
                    brain.pushOperand(beta)
                    brain.pushOperand(alpha)
                    delegate?.updateDisplayString()
                    brain.isSolving = false
                    brain.printMemory()
                }
            }
        } else {
            delegate?.setError(4)  // label not found
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
        let error = min(max(Int(falpha * errorScale), -plotMax), plotMax)
        if error < 0 {
            print(String(repeating: " ", count: plotMax + error) + "." + String(repeating: " ", count: -error - 1) + "|")
        } else if error == 0 {
            print(String(repeating: " ", count: plotMax) + ".")
        } else {  // error > 0
            print(String(repeating: " ", count: plotMax) + "|" + String(repeating: " ", count: error - 1) + ".")
        }
    }
}
