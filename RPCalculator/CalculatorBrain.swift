//
//  CalculatorBrain.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/5/21.
//

import Foundation

struct Constants {
    static let D2R = Double.pi / 180
    static let G2R = Double.pi / 200  // gradians to radians
}

class CalculatorBrain {
    
    var program: [Any] {
        let stackCopy = programStack
        return stackCopy
    }
    
    private var programStack = [Any]()
    
    func pushOperand(_ operand: Double) {
        programStack.append(operand)
    }
    
    func pushOperation(_ operation: String) {
        programStack.append(operation)
    }

    static func runProgram(_ program: [Any]) -> Double {
        var stack = program
        return popOperandOffStack(&stack)
    }
    
    func clearStack() {
        programStack.removeAll()
    }
    
    static func popOperandOffStack(_ stack: inout [Any]) -> Double {
        var result = 0.0;
        
        if let topOfStack = stack.popLast() {
            if topOfStack is Double {
                return topOfStack as! Double
            } else if topOfStack is String {
                let alternatePlusOperation = topOfStack as! String
                let prefixKey = alternatePlusOperation.first
                let operation = alternatePlusOperation.dropFirst()
                
                if prefixKey == "n" {  // none (primary button functions)
                    switch operation {
                    case "÷":
                        let divisor = popOperandOffStack(&stack)
                        result = popOperandOffStack(&stack) / divisor  // let DisplayView hanndle divide by zero (result = "inf")
                    case "×":
                        result = popOperandOffStack(&stack) * popOperandOffStack(&stack)
                    case "–":
                        result = -popOperandOffStack(&stack) + popOperandOffStack(&stack)
                    case "+":
                        result = popOperandOffStack(&stack) + popOperandOffStack(&stack)
                    case "SIND":
                        result = sin(popOperandOffStack(&stack) * Constants.D2R)
                    case "COSD":
                        result = cos(popOperandOffStack(&stack) * Constants.D2R)
                    case "TAND":
                        result = tan(popOperandOffStack(&stack) * Constants.D2R)
                    case "SINR":
                        result = sin(popOperandOffStack(&stack))
                    case "COSR":
                        result = cos(popOperandOffStack(&stack))
                    case "TANR":
                        result = tan(popOperandOffStack(&stack))
                    case "SING":
                        result = sin(popOperandOffStack(&stack) * Constants.G2R)
                    case "COSG":
                        result = cos(popOperandOffStack(&stack) * Constants.G2R)
                    case "TANG":
                        result = tan(popOperandOffStack(&stack) * Constants.G2R)
                    case "√x":
                        result = sqrt(popOperandOffStack(&stack))
                    case "ex":
                        result = exp(popOperandOffStack(&stack))
                    case "10x":
                        result = pow(10, popOperandOffStack(&stack))
                    case "yx":
                        let power = popOperandOffStack(&stack)
                        result = pow(popOperandOffStack(&stack), power)
                    case "1/x":
                        result = 1 / popOperandOffStack(&stack)
                    case "CHS":
                        result = -popOperandOffStack(&stack)
                    default:
                        break
                    }
                } else if prefixKey == "f" {  // functions above button (orange)
                    switch operation {
                    case "3":  // sent from digitPressed
                        result = popOperandOffStack(&stack) * Constants.D2R
                    default:
                        break
                    }
                } else if prefixKey == "g" {  // functions below button (blue)
                    switch operation {
                    case "SIND":
                        result = asin(popOperandOffStack(&stack)) / Constants.D2R
                    case "COSD":
                        result = acos(popOperandOffStack(&stack)) / Constants.D2R
                    case "TAND":
                        result = atan(popOperandOffStack(&stack)) / Constants.D2R
                    case "SINR":
                        result = asin(popOperandOffStack(&stack))
                    case "COSR":
                        result = acos(popOperandOffStack(&stack))
                    case "TANR":
                        result = atan(popOperandOffStack(&stack))
                    case "SING":
                        result = asin(popOperandOffStack(&stack)) / Constants.G2R
                    case "COSG":
                        result = acos(popOperandOffStack(&stack)) / Constants.G2R
                    case "TANG":
                        result = atan(popOperandOffStack(&stack)) / Constants.G2R
                    case "√x":
                        result = pow(popOperandOffStack(&stack), 2)
                    case "ex":
                        result = log(popOperandOffStack(&stack))  // natural log
                    case "10x":
                        result = log10(popOperandOffStack(&stack))
                    case "CHS":
                        result = abs(popOperandOffStack(&stack))
                    case "3":  // sent from digitPressed
                        result = popOperandOffStack(&stack) / Constants.D2R
                    default:
                        break
                    }
                }
            }
        }
        
        return result;
    }
}
