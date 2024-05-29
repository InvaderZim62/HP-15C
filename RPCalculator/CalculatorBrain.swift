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
    static let stackSize = 5  // dummy, T, Z, Y, X (dummy needed to allow operation to temporarily push onto stack)
    static let D2R = Double.pi / 180
    static let G2R = Double.pi / 200  // gradians to radians
}

class CalculatorBrain: Codable {
    
    var trigMode = TrigMode.DEG
    var lastXRegister = 0.0
    var errorPresent = false

    var xRegister: Double? {
        get {
            return programStack.last as? Double
        }
        set {
            programStack[programStack.count - 1] = newValue!  // ok to assume programStack is not empty (count > 0)
            printStack()
        }
    }

    // programStack is array of Any, to accommodate mixture of Double (operands) and String (operations)
    private var programStack = [Any](repeating: 0.0, count: Constants.stackSize) {
        didSet {
            // truncate stack to last 5 elements, then pad front with repeat of 0th element if size < 5
            programStack = programStack.suffix(Constants.stackSize)
            programStack.insert(contentsOf: repeatElement(programStack[0], count: Constants.stackSize - programStack.count), at: 0)
        }
    }
    
    private var storageRegisters = [String: Double]()  // [register name: number]

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case trigMode, lastXRegister, errorPresent, xRegister, programStack, storageRegisters }
    
    init() { }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trigMode = try container.decode(TrigMode.self, forKey: .trigMode)
        self.lastXRegister = try container.decode(Double.self, forKey: .lastXRegister)
        self.errorPresent = try container.decode(Bool.self, forKey: .errorPresent)
        self.xRegister = try container.decodeIfPresent(Double.self, forKey: .xRegister)
        self.programStack = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .programStack)) as? [Any] ?? []
        self.storageRegisters = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .storageRegisters)) as? [String: Double] ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.trigMode, forKey: .trigMode)
        try container.encode(self.lastXRegister, forKey: .lastXRegister)
        try container.encode(self.errorPresent, forKey: .errorPresent)
        try container.encodeIfPresent(self.xRegister, forKey: .xRegister)
        try container.encode(JSONSerialization.data(withJSONObject: programStack), forKey: .programStack)
        try container.encode(JSONSerialization.data(withJSONObject: storageRegisters), forKey: .storageRegisters)
    }

    // MARK: - Computed properties
    
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

    // mantissa (in this case) is all digits of displayed number, without punctuation ("-", "e", ".", ",")
    var displayMantissa: String {
        var mantissa = String(abs(xRegister!))
        if let ne = mantissa.firstIndex(of: "e") {
            mantissa = String(mantissa.prefix(upTo: ne))  // drop the exponent
        }
        mantissa = mantissa.replacingOccurrences(of: ".", with: "")
        if mantissa.count < 10 { mantissa += repeatElement("0", count: 10 - mantissa.count) }
        return mantissa
    }
    
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
    
    func popXRegister() {
        programStack.removeLast()
        printStack()
    }
    
    func runProgram() -> Double {
        var saveStack = programStack  // save in case of nan or inf
        //------------------------------------------------------------
        let (result, secondResult) = popOperandOffStack(&programStack)  // call recursively, until results obtained
        //------------------------------------------------------------
        if result.isNaN || result.isInfinite {
            // restore stack to pre-error state
            saveStack.removeLast()  // last element is the operation causing the error
            programStack = saveStack
            errorPresent = true  // reset in CalculatorViewController.restoreFromError
        } else {
            if secondResult != nil {
                pushOperand(secondResult!)
            }
            pushOperand(result)
        }
        printStack()
        return result
    }
    
    func clearAll() {
        clearStorageRegisters()
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
    
    private func popOperandOffStack(_ stack: inout [Any]) -> (result: Double, secondResult: Double?) {
        var result = 0.0
        var secondResult: Double? = nil

        if let topOfStack = stack.popLast() {
            if topOfStack is Double {
                return (topOfStack as! Double, nil)
            } else if topOfStack is String {
                let prefixAndOperation = topOfStack as! String
                let prefixKey = prefixAndOperation.first  // prefix is always one letter
                let operation = prefixAndOperation.dropFirst()
                
                switch prefixKey {
                case "n":  // none (primary button functions)
                    switch operation {
                    case "÷":
                        let divisor = popOperandOffStack(&stack).result
                        result = popOperandOffStack(&stack).result / divisor  // let DisplayView handle divide by zero (result = "inf")
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
                case "f":  // functions above button (orange)
                    switch operation {
                    case "STO":
                        // FRAC - decimal portion of number
                        let number = popOperandOffStack(&stack).result
                        result = number - Double(Int(number))
                    case "1":  // sent from digitPressed
                        // →R - convert polar coordinates to rectangular
                        let radius = popOperandOffStack(&stack).result
                        let angle = popOperandOffStack(&stack).result
                        result = radius * cos(angle * angleConversion)  // x
                        secondResult = radius * sin(angle * angleConversion)  // y
                    case "2":  // sent from digitPressed
                        // →H.MS - convert decimal hours to hours-minutes-seconds-decimal seconds (H.MMSSsssss)
                        let decimalHours = popOperandOffStack(&stack).result
                        let hours = Int(decimalHours)
                        let minutes = Int((decimalHours - Double(hours)) * 60)
                        let seconds = (decimalHours - Double(hours) - Double(minutes) / 60) * 3600
                        result = Double(hours) + Double(minutes) / 100 + seconds / 10000
                    case "3":  // sent from digitPressed
                        // →RAD - convert to radians
                        result = popOperandOffStack(&stack).result * Constants.D2R
                    default:
                        break
                    }
                case "g":  // functions below button (blue)
                    switch operation {
                    case "STO":
                        // INT
                        result = Double(Int(popOperandOffStack(&stack).result))
                    case "SIN":
                        // SIN-1 (arcsin)
                        result = asin(popOperandOffStack(&stack).result) / angleConversion
                    case "COS":
                        // COS-1 (arccos)
                        result = acos(popOperandOffStack(&stack).result) / angleConversion
                    case "TAN":
                        // TAN-1 (arctan)
                        result = atan(popOperandOffStack(&stack).result) / angleConversion
                    case "√x":
                        // x²
                        result = pow(popOperandOffStack(&stack).result, 2)
                    case "ex":
                        // LN (natural log)
                        result = log(popOperandOffStack(&stack).result)
                    case "10x":
                        // LOG (log base 10)
                        result = log10(popOperandOffStack(&stack).result)
                    case "yx":
                        // %
                        let percent = popOperandOffStack(&stack).result * 0.01
                        let baseNumber = popOperandOffStack(&stack).result
                        result = percent * baseNumber  // %
                        secondResult = baseNumber
                    case "1/x":
                        // 𝝙% (delta %)
                        let secondNumber = popOperandOffStack(&stack).result
                        let baseNumber = popOperandOffStack(&stack).result
                        result = (secondNumber - baseNumber) / baseNumber * 100
                        secondResult = baseNumber
                    case "CHS":
                        // ABS (absolute value)
                        result = abs(popOperandOffStack(&stack).result)
                    case "1":  // sent from digitPressed
                        // →P - convert rectangular coordinates to polar
                        let x = popOperandOffStack(&stack).result
                        let y = popOperandOffStack(&stack).result
                        result = sqrt(x * x + y * y)  // radius
                        secondResult = atan2(y, x) / angleConversion  // angle
                    case "2":  // sent from digitPressed
                        // →H convert hours-minutes-seconds-decimal seconds (H.MMSSsssss) to decimal hour
                        let hoursMinuteSeconds = popOperandOffStack(&stack).result  // ex. hoursMinutesSeconds = 1.1404200
                        let hours = Int(hoursMinuteSeconds)  // ex. hours = 1
                        let decimal = Int(round((hoursMinuteSeconds - Double(hours)) * 10000000))  // ex. decimal = 1404200
                        let minutes = Int(decimal / 100000)  // ex. minutes = 14
                        let seconds = Double(decimal - minutes * 100000) / 1000  // ex. seconds = 4.2
                        result = Double(hours) + Double(minutes) / 60 + Double(seconds) / 3600
                    case "3":  // sent from digitPressed
                        // →DEG - convert to degrees
                        result = popOperandOffStack(&stack).result / Constants.D2R
                    default:
                        break
                    }
                case "H":  // hyperbolic trig function
                    switch operation {
                    case "SIN":
                        result = sinh(popOperandOffStack(&stack).result * angleConversion)
                    case "COS":
                        result = cosh(popOperandOffStack(&stack).result * angleConversion)
                    case "TAN":
                        result = tanh(popOperandOffStack(&stack).result * angleConversion)
                    default:
                        break
                    }
                case "h":  // inverse hyperbolic trig function
                    switch operation {
                    case "SIN":
                        result = asinh(popOperandOffStack(&stack).result) / angleConversion
                    case "COS":
                        result = acosh(popOperandOffStack(&stack).result) / angleConversion
                    case "TAN":
                        result = atanh(popOperandOffStack(&stack).result) / angleConversion
                    default:
                        break
                    }
                default:
                    break
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
