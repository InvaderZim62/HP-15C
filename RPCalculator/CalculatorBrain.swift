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
    
    private var programStack = [Any]()
    private var storageRegisters = [String: Double]()  // [register name: number]
    
    var program: [Any] {
        let stackCopy = programStack
        return stackCopy
    }
    
    // MARK: - Start of code
    
    func pushOperand(_ operand: Double) {
        programStack.append(operand)
    }
    
    func pushOperation(_ operation: String) {
        programStack.append(operation)
    }
    
    static func runProgram(_ program: [Any]) -> Double {
        print(program)
        var stack = program
        return popOperandOffStack(&stack)
    }
    
    func clearStack() {
        programStack.removeAll()
    }
    
    func clearRegisters() {
        storageRegisters.removeAll()
    }
    
    func swapXyRegisters() {
        // TBD
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
                    case "STO":
                        let number = popOperandOffStack(&stack)
                        result = number - Double(Int(number))  // frac (decimal portion of number)
                    case "3":  // sent from digitPressed
                        result = popOperandOffStack(&stack) * Constants.D2R  // convert to radians
                    default:
                        break
                    }
                } else if prefixKey == "g" {  // functions below button (blue)
                    switch operation {
                    case "STO":
                        result = Double(Int(popOperandOffStack(&stack)))  // int
                    case "SIND":
                        result = asin(popOperandOffStack(&stack)) / Constants.D2R  // arcsine in degrees
                    case "COSD":
                        result = acos(popOperandOffStack(&stack)) / Constants.D2R  // arccosine in degrees
                    case "TAND":
                        result = atan(popOperandOffStack(&stack)) / Constants.D2R  // arctangent in degrees
                    case "SINR":
                        result = asin(popOperandOffStack(&stack))  // arcsine in radians
                    case "COSR":
                        result = acos(popOperandOffStack(&stack))  // arccosine in radians
                    case "TANR":
                        result = atan(popOperandOffStack(&stack))  // arctangent in radians
                    case "SING":
                        result = asin(popOperandOffStack(&stack)) / Constants.G2R  // arcsine in gradians
                    case "COSG":
                        result = acos(popOperandOffStack(&stack)) / Constants.G2R  // arccosine in gradians
                    case "TANG":
                        result = atan(popOperandOffStack(&stack)) / Constants.G2R  // arctangent in gradians
                    case "√x":
                        result = pow(popOperandOffStack(&stack), 2)  // square
                    case "ex":
                        result = log(popOperandOffStack(&stack))  // natural log
                    case "10x":
                        result = log10(popOperandOffStack(&stack))  // log base 10
                    case "CHS":
                        result = abs(popOperandOffStack(&stack))  // absolute value
                    case "3":  // sent from digitPressed
                        result = popOperandOffStack(&stack) / Constants.D2R  // convert to degrees
                    default:
                        break
                    }
                }
            }
        }
        
        return result;
    }
    
    func storeResultsInRegister(_ name: String) {
        storageRegisters[name] = CalculatorBrain.runProgram(program)
    }
    
    func recallNumberFromRegister(_ name: String) -> Double {
        return storageRegisters[name] ?? 0.0
    }
}
