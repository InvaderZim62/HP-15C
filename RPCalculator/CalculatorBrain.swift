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

enum Error: Codable {
    case NaN, badKeySequence, none
}

class CalculatorBrain: Codable {
    
    var trigMode = TrigMode.DEG
    var lastXRegister = 0.0
    var error = Error.none

    var xRegister: Double? {
        get {
            return programStack.last
        }
        set {
            programStack[programStack.count - 1] = newValue!  // ok to assume programStack is not empty (count > 0)
            printStack()
        }
    }

    private var programStack = [Double](repeating: 0.0, count: Constants.stackSize) {
        didSet {
            // truncate stack to last 5 elements, then pad front with repeat of 0th element if size < 5
            programStack = programStack.suffix(Constants.stackSize)
            programStack.insert(contentsOf: repeatElement(programStack[0], count: Constants.stackSize - programStack.count), at: 0)
        }
    }
    
    private var storageRegisters = [String: Double]()  // [register name: number]

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case trigMode, lastXRegister, error, xRegister, programStack, storageRegisters }
    
    init() { }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trigMode = try container.decode(TrigMode.self, forKey: .trigMode)
        self.lastXRegister = try container.decode(Double.self, forKey: .lastXRegister)
        self.error = try container.decode(Error.self, forKey: .error)
        self.xRegister = try container.decodeIfPresent(Double.self, forKey: .xRegister)
        self.programStack = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .programStack)) as? [Double] ?? []
        self.storageRegisters = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .storageRegisters)) as? [String: Double] ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.trigMode, forKey: .trigMode)
        try container.encode(self.lastXRegister, forKey: .lastXRegister)
        try container.encode(self.error, forKey: .error)
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
    
    func popOperand() -> Double {
        programStack.popLast()!
    }
    
    func popXRegister() {
        programStack.removeLast()
        printStack()
    }
    
    func clearAll() {
        clearStorageRegisters()
        programStack = [Double](repeating: 0.0, count: Constants.stackSize)
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
    
    func performOperation(_ prefixAndOperation: String) {
        let saveStack = programStack  // save in case of nan or inf
        var result = 0.0
        var secondResult: Double? = nil
        
        let prefixKey = prefixAndOperation.first  // prefix is always one letter
        let operation = prefixAndOperation.dropFirst()

        switch prefixKey {
        case "n":  // none (primary button functions)
            switch operation {
            case "÷":
                let divisor = popOperand()
                result = popOperand() / divisor  // let DisplayView handle divide by zero (result = "inf")
            case "×":
                result = popOperand() * popOperand()
            case "–":
                result = -popOperand() + popOperand()
            case "+":
                result = popOperand() + popOperand()
            case "SIN":
                result = sin(popOperand() * angleConversion)
            case "COS":
                result = cos(popOperand() * angleConversion)
            case "TAN":
                result = tan(popOperand() * angleConversion)
            case "√x":
                result = sqrt(popOperand())
            case "ex":
                result = exp(popOperand())
            case "10x":
                result = pow(10, popOperand())
            case "yx":
                let power = popOperand()
                result = pow(popOperand(), power)
            case "1/x":
                result = 1 / popOperand()
            case "CHS":
                result = -popOperand()
            default:
                break
            }
        case "f":  // functions above button (orange)
            switch operation {
            case "STO":
                // FRAC - decimal portion of number
                let number = popOperand()
                result = number - Double(Int(number))
            case "1":  // sent from digitPressed
                // →R - convert polar coordinates to rectangular
                let radius = popOperand()
                let angle = popOperand()
                result = radius * cos(angle * angleConversion)  // x
                secondResult = radius * sin(angle * angleConversion)  // y
            case "2":  // sent from digitPressed
                // →H.MS - convert decimal hours to hours-minutes-seconds-decimal seconds (H.MMSSsssss)
                let decimalHours = popOperand()
                let hours = Int(decimalHours)
                let minutes = Int((decimalHours - Double(hours)) * 60)
                let seconds = (decimalHours - Double(hours) - Double(minutes) / 60) * 3600
                result = Double(hours) + Double(minutes) / 100 + seconds / 10000
            case "3":  // sent from digitPressed
                // →RAD - convert to radians
                result = popOperand() * Constants.D2R
            default:
                break
            }
        case "g":  // functions below button (blue)
            switch operation {
            case "STO":
                // INT
                result = Double(Int(popOperand()))
            case "SIN":
                // SIN-1 (arcsin)
                result = asin(popOperand()) / angleConversion
            case "COS":
                // COS-1 (arccos)
                result = acos(popOperand()) / angleConversion
            case "TAN":
                // TAN-1 (arctan)
                result = atan(popOperand()) / angleConversion
            case "√x":
                // x²
                result = pow(popOperand(), 2)
            case "ex":
                // LN (natural log)
                result = log(popOperand())
            case "10x":
                // LOG (log base 10)
                result = log10(popOperand())
            case "yx":
                // %
                let percent = popOperand() * 0.01
                let baseNumber = popOperand()
                result = percent * baseNumber  // %
                secondResult = baseNumber
            case "1/x":
                // 𝝙% (delta %)
                let secondNumber = popOperand()
                let baseNumber = popOperand()
                result = (secondNumber - baseNumber) / baseNumber * 100
                secondResult = baseNumber
            case "CHS":
                // ABS (absolute value)
                result = abs(popOperand())
            case "1":  // sent from digitPressed
                // →P - convert rectangular coordinates to polar
                let x = popOperand()
                let y = popOperand()
                result = sqrt(x * x + y * y)  // radius
                secondResult = atan2(y, x) / angleConversion  // angle
            case "2":  // sent from digitPressed
                // →H convert hours-minutes-seconds-decimal seconds (H.MMSSsssss) to decimal hour
                let hoursMinuteSeconds = popOperand()  // ex. hoursMinutesSeconds = 1.1404200
                let hours = Int(hoursMinuteSeconds)  // ex. hours = 1
                let decimal = Int(round((hoursMinuteSeconds - Double(hours)) * 10000000))  // ex. decimal = 1404200
                let minutes = Int(decimal / 100000)  // ex. minutes = 14
                let seconds = Double(decimal - minutes * 100000) / 1000  // ex. seconds = 4.2
                result = Double(hours) + Double(minutes) / 60 + Double(seconds) / 3600
            case "3":  // sent from digitPressed
                // →DEG - convert to degrees
                result = popOperand() / Constants.D2R
            default:
                break
            }
        case "H":  // hyperbolic trig function
            switch operation {
            case "SIN":
                result = sinh(popOperand() * angleConversion)
            case "COS":
                result = cosh(popOperand() * angleConversion)
            case "TAN":
                result = tanh(popOperand() * angleConversion)
            default:
                break
            }
        case "h":  // inverse hyperbolic trig function
            switch operation {
            case "SIN":
                result = asinh(popOperand()) / angleConversion
            case "COS":
                result = acosh(popOperand()) / angleConversion
            case "TAN":
                result = atanh(popOperand()) / angleConversion
            default:
                break
            }
        default:
            break
        }
        
        if result.isNaN || result.isInfinite {
            // restore stack to pre-error state
            programStack = saveStack
            error = .NaN  // reset in CalculatorViewController.restoreFromError
        } else {
            if secondResult != nil {
                pushOperand(secondResult!)
            }
            pushOperand(result)
        }
        printStack()
    }
    
    func storeResultsInRegister(_ name: String) {
        storageRegisters[name] = xRegister
    }
    
    func recallNumberFromStorageRegister(_ name: String) -> Double {
        return storageRegisters[name] ?? 0.0
    }
}
