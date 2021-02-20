//
//  CalculatorBrain.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/5/21.
//
//  Useful functions...
//     programStack = programStack.suffix(5)                                                      // only save last 5 elements of array
//     programStack.insert(contentsOf: repeatElement(0.0, count: 5 - programStack.count), at: 0)  // pad front of array with 0.0, to total count = 5
//     programStack.swapAt(Constants.stackSize - 1, Constants.stackSize - 2)                      // swap last two elements of array
//

import Foundation

struct Constants {
    static let stackSize = 5  // dummy, T, Z, Y, X (dummy needed to allow operand to temporarily push onto stack)
    static let D2R = Double.pi / 180
    static let G2R = Double.pi / 200  // gradians to radians
}

class CalculatorBrain {
    
    var trigMode = TrigMode.DEG
    var lastXRegister = 0.0
    var errorPresent = false
    
    var angleConversion: Double {
        switch trigMode {
        case .DEG:
            return Constants.D2R
        case .RAD:
            return 1.0
        case .GRAD:
            return Constants.G2R
        }
    }
    
    var xRegister: Double? {
        get { return programStack.last as? Double }
        set { programStack[programStack.count - 1] = newValue! }  // ok to assume programStack is not empty
    }
    
    // programStack is array of Any, to accomodate mixture of Double (operands) and String (operations)
    private var programStack = [Any](repeating: 0.0, count: Constants.stackSize) {
        didSet {
            // truncate stack to last 5 elements, then pad front with repeat of 0th element if size < 5
            programStack = programStack.suffix(Constants.stackSize)
            programStack.insert(contentsOf: repeatElement(programStack[0], count: Constants.stackSize - programStack.count), at: 0)
        }
    }
    
    private var storageRegisters = [String: Double]()  // [register name: number]
    
    // MARK: - Start of code
    
    func printStack() {
        print(programStack.suffix(Constants.stackSize - 1), lastXRegister)  // don't print dummy register
    }
    
    func pushOperand(_ operand: Double) {
        programStack.append(operand)
    }
    
    func pushOperation(_ operation: String) {
        programStack.append(operation)
    }
    
    func runProgram() -> Double {
        if let registerX = programStack.last as? Double { lastXRegister = registerX }  // save register X (display) before computing new results
        var saveStack = programStack  // save in case of nan or inf
        let (result, secondResult) = popOperandOffStack(&programStack)
        if result.isNaN || result.isInfinite {
            // restore stack to pre-error state
            saveStack.removeLast()  // last element is the operation causing the error
            programStack = saveStack
            errorPresent = true  // reset in CaclulatorViewController.restoreFromError
        } else {
            if secondResult != nil {
                pushOperand(secondResult!)
            }
            pushOperand(result)
        }
        printStack()
        return result
    }
    
    func clearStack() {
        programStack = [Any](repeating: 0.0, count: Constants.stackSize)
        lastXRegister = 0.0
        printStack()
    }
    
    func clearStorageRegisters() {
        storageRegisters.removeAll()
    }
    
    func swapXyRegisters() {
        programStack.swapAt(Constants.stackSize - 1, Constants.stackSize - 2)  // swap last two elements
        printStack()
    }
    
    // don't roll the dummy register at 0
    func rollStack(directionDown: Bool) {
        if directionDown {
            let xRegister = programStack.removeLast()  // Note: programStack didSet pads beginning back to count = 5 after this
            programStack.insert(xRegister, at: 2)      // that's why insert at 2 here, instead of 1
        } else {
            let tRegister = programStack.remove(at: 1)
            programStack.append(tRegister)
        }
    }
    
    func popOperandOffStack(_ stack: inout [Any]) -> (result: Double, secondResult: Double?) {
        var result = 0.0
        var secondResult: Double? = nil

        if let topOfStack = stack.popLast() {
            if topOfStack is Double {
                return (topOfStack as! Double, nil)
            } else if topOfStack is String {
                let alternatePlusOperation = topOfStack as! String
                let prefixKey = alternatePlusOperation.first
                let operation = alternatePlusOperation.dropFirst()
                
                if prefixKey == "n" {  // none (primary button functions)
                    switch operation {
                    case "÷":
                        let divisor = popOperandOffStack(&stack).result
                        result = popOperandOffStack(&stack).result / divisor  // let DisplayView hanndle divide by zero (result = "inf")
                    case "×":
                        result = popOperandOffStack(&stack).result * popOperandOffStack(&stack).result
                    case "–":
                        result = -popOperandOffStack(&stack).result + popOperandOffStack(&stack).result
                    case "+":
                        result = popOperandOffStack(&stack).result + popOperandOffStack(&stack).result
                    case "SIN":
                        result = sin(popOperandOffStack(&stack).result * angleConversion)
                    case "COS":
                        result = cos(popOperandOffStack(&stack).result * angleConversion)
                    case "TAN":
                        result = tan(popOperandOffStack(&stack).result * angleConversion)
                    case "√x":
                        result = sqrt(popOperandOffStack(&stack).result)
                    case "ex":
                        result = exp(popOperandOffStack(&stack).result)
                    case "10x":
                        result = pow(10, popOperandOffStack(&stack).result)
                    case "yx":
                        let power = popOperandOffStack(&stack).result
                        result = pow(popOperandOffStack(&stack).result, power)
                    case "1/x":
                        result = 1 / popOperandOffStack(&stack).result
                    case "CHS":
                        result = -popOperandOffStack(&stack).result
                    default:
                        break
                    }
                } else if prefixKey == "f" {  // functions above button (orange)
                    switch operation {
                    case "STO":
                        let number = popOperandOffStack(&stack).result
                        result = number - Double(Int(number))  // frac (decimal portion of number)
                    case "3":  // sent from digitPressed
                        result = popOperandOffStack(&stack).result * Constants.D2R  // convert to radians
                    default:
                        break
                    }
                } else if prefixKey == "g" {  // functions below button (blue)
                    switch operation {
                    case "STO":
                        result = Double(Int(popOperandOffStack(&stack).result))  // int
                    case "SIN":
                        result = asin(popOperandOffStack(&stack).result) / angleConversion  // arcsine
                    case "COS":
                        result = acos(popOperandOffStack(&stack).result) / angleConversion  // arccosine
                    case "TAN":
                        result = atan(popOperandOffStack(&stack).result) / angleConversion  // arctangent
                    case "√x":
                        result = pow(popOperandOffStack(&stack).result, 2)  // square
                    case "ex":
                        result = log(popOperandOffStack(&stack).result)  // natural log
                    case "10x":
                        result = log10(popOperandOffStack(&stack).result)  // log base 10
                    case "yx":
                        let percent = popOperandOffStack(&stack).result * 0.01
                        let baseNumber = popOperandOffStack(&stack).result
                        result = percent * baseNumber  // %
                        secondResult = baseNumber
                    case "1/x":
                        let secondNumber = popOperandOffStack(&stack).result
                        let baseNumber = popOperandOffStack(&stack).result
                        result = (secondNumber - baseNumber) / baseNumber * 100  // delta %
                        secondResult = baseNumber
                    case "CHS":
                        result = abs(popOperandOffStack(&stack).result)  // absolute value
                    case "3":  // sent from digitPressed
                        result = popOperandOffStack(&stack).result / Constants.D2R  // convert to degrees
                    default:
                        break
                    }
                }
            }
        }
        
        return (result, secondResult)
    }
    
    func storeResultsInRegister(_ name: String) {
        storageRegisters[name] = runProgram()
    }
    
    func recallNumberFromStorageRegister(_ name: String) -> Double {
        return storageRegisters[name] ?? 0.0
    }
}
