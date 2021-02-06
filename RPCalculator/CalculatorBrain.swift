//
//  CalculatorBrain.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/5/21.
//

import Foundation

struct Constants {
    static let D2R = Double.pi / 180
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
                let alternateFunction = alternatePlusOperation.first
                let operation = alternatePlusOperation.dropFirst()
                
                if alternateFunction == "n" {  // none (primary button functions)
                    switch operation {
                    case "÷":
                        let divisor = popOperandOffStack(&stack)
                        if divisor != 0 {
                            result = popOperandOffStack(&stack) / divisor
                        }
                    case "×":
                        result = popOperandOffStack(&stack) * popOperandOffStack(&stack)
                    case "–":
                        result = -popOperandOffStack(&stack) + popOperandOffStack(&stack)
                    case "+":
                        result = popOperandOffStack(&stack) + popOperandOffStack(&stack)
                    case "SIN":
                        result = sin(popOperandOffStack(&stack) * Constants.D2R)
                    case "COS":
                        result = cos(popOperandOffStack(&stack) * Constants.D2R)
                    case "TAN":
                        result = tan(popOperandOffStack(&stack) * Constants.D2R)
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
                } else if alternateFunction == "g" {  // functions below button (blue)
                    switch operation {
                    case "SIN":
                        result = asin(popOperandOffStack(&stack)) / Constants.D2R
                    case "COS":
                        result = acos(popOperandOffStack(&stack)) / Constants.D2R
                    case "TAN":
                        result = atan(popOperandOffStack(&stack)) / Constants.D2R
                    case "√x":
                        result = pow(popOperandOffStack(&stack), 2)
                    case "ex":
                        result = log(popOperandOffStack(&stack))  // natural log
                    case "10x":
                        result = log10(popOperandOffStack(&stack))
                    case "CHS":
                        result = abs(popOperandOffStack(&stack))
                    default:
                        break
                    }
                }
            }
        }
        
        return result;
    }
}
