//
//  CalculatorBrain.swift
//  RPCalculator
//
//  Created by Phil Stern on 2/5/21.
//
//  Useful functions...
//     realStack = realStack.suffix(4)                                                      // only save last 4 elements of array
//     realStack.insert(contentsOf: repeatElement(0.0, count: 4 - realStack.count), at: 0)  // pad front of array with 0.0, to total count = 4
//     realStack.swapAt(Constants.stackSize - 1, Constants.stackSize - 2)                   // swap last two elements of array
//

import Foundation

struct Constants {
    static let stackSize = 4  // T, Z, Y, X
    static let D2R = Double.pi / 180
    static let G2R = Double.pi / 200  // gradians to radians
    static let maxValue = 9.999999999e99  // more cause overflow on HP-15C
}

enum Error: Equatable, Codable {
    case code(Int)  // see Appendix A of Owner's Handbook, ex. 1/0, sqrt(-1), acos(1.1) are code 0, STO √x is code 3, STO EEX is code 11
    case overflow
    case underflow
    case badKeySequence
    case none
}

class CalculatorBrain: Codable {
    
    var trigMode = TrigMode.DEG
    var lastXRegister = 0.0
    var error = Error.none

    var xRegister: Double? {
        get {
            return realStack.last
        }
        set {
            realStack[realStack.count - 1] = newValue!  // ok to assume realStack is not empty (count > 0)
            printMemory()
        }
    }
    
    var isComplexMode = false {
        didSet {
            if isComplexMode != oldValue {
                // clear imagStack when entering or exiting complex mode
                imagStack = [Double](repeating: 0.0, count: Constants.stackSize)
            }
        }
    }

    private var realStack = [Double](repeating: 0.0, count: Constants.stackSize) {
        didSet {
            // truncate stack to last 4 elements, then pad front with repeat of 0th element if size < 4
            realStack = realStack.suffix(Constants.stackSize)
            realStack.insert(contentsOf: repeatElement(realStack[0], count: Constants.stackSize - realStack.count), at: 0)
        }
    }

    private var imagStack = [Double](repeating: 0.0, count: Constants.stackSize) {
        didSet {
            // truncate stack to last 4 elements, then pad front with repeat of 0th element if size < 4
            imagStack = imagStack.suffix(Constants.stackSize)
            imagStack.insert(contentsOf: repeatElement(imagStack[0], count: Constants.stackSize - imagStack.count), at: 0)
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
        self.realStack = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .programStack)) as? [Double] ?? []
        self.storageRegisters = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .storageRegisters)) as? [String: Double] ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.trigMode, forKey: .trigMode)
        try container.encode(self.lastXRegister, forKey: .lastXRegister)
        try container.encode(self.error, forKey: .error)
        try container.encodeIfPresent(self.xRegister, forKey: .xRegister)
        try container.encode(JSONSerialization.data(withJSONObject: realStack), forKey: .programStack)
        try container.encode(JSONSerialization.data(withJSONObject: storageRegisters), forKey: .storageRegisters)
    }

    // MARK: - Computed properties
    
    var angleConversion: Double {
        if isComplexMode {
            return 1.0  // HP-15C does all trig function in radians
        } else {
            switch trigMode {
            case .DEG:
                return Constants.D2R
            case .RAD:
                return 1.0
            case .GRAD:
                return Constants.G2R
            }
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
    
    func pushOperand(_ operand: Double) {
        realStack.append(operand)
        if isComplexMode { imagStack.append(0) }
    }
    
    // remove and return end of stack (X register)
    func popOperand() -> (real: Double, imag: Double) {
        (realStack.popLast()!, imagStack.popLast()!)
    }
    
    // remove end of stack
    func popXRegister() {
        realStack.removeLast()
        if isComplexMode { imagStack.removeLast() }
        printMemory()
    }
    
    func clearAll() {
        clearStorageRegisters()
        realStack = [Double](repeating: 0.0, count: Constants.stackSize)
        lastXRegister = 0.0
        printMemory()
    }
    
    func clearStorageRegisters() {
        storageRegisters.removeAll()
    }
    
    func swapXyRegisters() {
        realStack.swapAt(Constants.stackSize - 1, Constants.stackSize - 2)  // swap last two elements
        printMemory()
    }
    
    func rollStack(directionDown: Bool) {
        if directionDown {
            let xRegister = realStack.removeLast()  // Note: realStack didSet pads beginning back to count = 4 after this
            realStack.insert(xRegister, at: 1)      // that's why insert at 1 here, instead of 0 (didSet truncates index 0)
        } else {
            let tRegister = realStack.remove(at: 0)
            realStack.append(tRegister)
        }
        printMemory()
    }
    
    func storeResultInRegister(_ name: String, result: Double) {
        storageRegisters[name] = result
    }
    
    func recallNumberFromStorageRegister(_ name: String) -> Double {
        storageRegisters[name] ?? 0.0
    }
    
    func moveRealXToImagX() {
        imagStack[2] = xRegister!
        popXRegister()
        printMemory()
    }

    func performOperation(_ prefixAndOperation: String) {
        let saveStack = realStack  // save in case of nan or inf
        var result = (0.0, 0.0)  // (real, imaginary)
        var secondResult: Double? = nil
        
        let prefixKey = prefixAndOperation.first  // prefix is always one letter
        let operation = prefixAndOperation.dropFirst()

        switch prefixKey {
        case "n":  // none (primary button functions)
            switch operation {
            case "÷":
                // (a + bi) / (c + di) = (ac + bd)/(c² + d²) + (bc - ad)/(c² + d²)i
                let denominator = popOperand()
                let numerator = popOperand()
                // handle divide by zero, below (and in CalculatorViewController.updateDisplayString)
                let den = pow(denominator.real, 2) + pow(denominator.imag, 2)
                let real = (numerator.real * denominator.real + numerator.imag * denominator.imag) / den
                let imag = (numerator.imag * denominator.real - numerator.real * denominator.imag) / den
                result = (real, imag)
            case "×":
                // (a + bi) x (c + di) = (ac - bd) + (ad + bc)i
                let term1 = popOperand()
                let term2 = popOperand()
                let real = (term1.real * term2.real - term1.imag * term2.imag)
                let imag = (term1.real * term2.imag + term1.imag * term2.real)
                result = (real, imag)
            case "–":
                // (a + bi) - (c + di) = (a - c) + (b - d)i
                let term2 = popOperand()
                let term1 = popOperand()
                let real = term1.real - term2.real
                let imag = term1.imag - term2.imag
                result = (real, imag)
            case "+":
                // (a + bi) - (c + di) = (a - c) + (b - d)i
                let term1 = popOperand()
                let term2 = popOperand()
                let real = term1.real + term2.real
                let imag = term1.imag + term2.imag
                result = (real, imag)
            case "SIN":
                // sin(a + bi) = sin(a)cosh(b) + cos(a)sinh(b)i
                let term = popOperand()
                let real = sin(term.real * angleConversion) * cosh(term.imag * angleConversion)
                let imag = cos(term.real * angleConversion) * sinh(term.imag * angleConversion)
                result = (real, imag)
            case "COS":
                // cos(a + bi) = cos(a)cosh(b) + sin(a)sinh(b)i
                let term = popOperand()
                let real = cos(term.real * angleConversion) * cosh(term.imag * angleConversion)
                let imag = sin(term.real * angleConversion) * sinh(term.imag * angleConversion)
                result = (real, imag)
            case "TAN":
                // tan(a + bi) = [tan(a) - tan(a)tanh²(b)] / [1 + tan²(a)tanh²(b)] + [tanh(b) + tan²(a)tanh(b)] / [1 + tan²(a)tanh²(b)]i
                let term = popOperand()
                let den = 1 + pow(tan(term.real * angleConversion), 2) * pow(tanh(term.imag * angleConversion), 2)
                let real = tan(term.real * angleConversion) * (1 - pow(tanh(term.imag * angleConversion), 2)) / den
                let imag = (tanh(term.imag * angleConversion) + pow(tan(term.real * angleConversion), 2)) / den
                result = (real, imag)
            case "√x":
                // sqrt(a + bi) = sqrt[(mag + a)/2] + b/abs(b)*sqrt[(mag - a)/2]i, where mag = sqrt(a² + b²)
                let term = popOperand()
                if term.imag == 0 {
                    result = (sqrt(term.real), 0)
                } else {
                    let mag = pow(term.real, 2) + pow(term.imag, 2)
                    let real = sqrt((mag + term.real) / 2)
                    let imag = term.imag / abs(term.imag) * sqrt((mag - term.real) / 2)
                    result = (real, imag)
                }
            case "ex":
                // e^(a + bi) = e^a * cos(b) + e^a * sin(b)i
                let term = popOperand()
                let real = exp(term.real) * cos(term.imag * angleConversion)
                let imag = exp(term.real) * sin(term.imag * angleConversion)
                result = (real, imag)
            case "10x":
                // 10^(a + bi) = 10^a * cos(b*ln(10)) + 10^a * sin(b*ln(10))i
                let power = popOperand()
                let real = pow(10, power.real) * cos(power.imag * log(10) * angleConversion)
                let imag = pow(10, power.real) * sin(power.imag * log(10) * angleConversion)
                result = (real, imag)
            case "yx":
                let power = popOperand()
//                result = pow(popOperand(), power)
                result = (pow(popOperand().real, power.real), 0)  // pws: only implemented using the real parts, for now
            case "1/x":
                // 1/(a + bi) = a/(a² + b²) - b/(a² + b²)i
                let term = popOperand()
                let den = pow(term.real, 2) + pow(term.imag, 2)
                let real = term.real / den
                let imag = -term.imag / den
                result = (real, imag)
            case "CHS":
                // CHS only changes the sign of the real part of the imaginary number on the HP-15C
                let term = popOperand()
                result = (-term.real, term.imag)
            default:
                break
            }
//        case "f":  // functions above button (orange)
//            switch operation {
//            case "STO":
//                // FRAC - decimal portion of number
//                let number = popOperand()
//                result = number - Double(Int(number))
//            case "1":  // sent from digitPressed
//                // →R - convert polar coordinates to rectangular
//                let radius = popOperand()
//                let angle = popOperand()
//                result = radius * cos(angle * angleConversion)  // x
//                secondResult = radius * sin(angle * angleConversion)  // y
//            case "2":  // sent from digitPressed
//                // →H.MS - convert decimal hours to hours-minutes-seconds-decimal seconds (H.MMSSsssss)
//                let decimalHours = popOperand()
//                let hours = Int(decimalHours)
//                let minutes = Int((decimalHours - Double(hours)) * 60)
//                let seconds = (decimalHours - Double(hours) - Double(minutes) / 60) * 3600
//                result = Double(hours) + Double(minutes) / 100 + seconds / 10000
//            case "3":  // sent from digitPressed
//                // →RAD - convert to radians
//                result = popOperand() * Constants.D2R
//            default:
//                break
//            }
//        case "g":  // functions below button (blue)
//            switch operation {
//            case "STO":
//                // INT
//                result = Double(Int(popOperand()))
//            case "SIN":
//                // SIN-1 (arcsin)
//                result = asin(popOperand()) / angleConversion
//            case "COS":
//                // COS-1 (arccos)
//                result = acos(popOperand()) / angleConversion
//            case "TAN":
//                // TAN-1 (arctan)
//                result = atan(popOperand()) / angleConversion
//            case "√x":
//                // x²
//                result = pow(popOperand(), 2)
//            case "ex":
//                // LN (natural log)
//                result = log(popOperand())
//            case "10x":
//                // LOG (log base 10)
//                result = log10(popOperand())
//            case "yx":
//                // %
//                let percent = popOperand() * 0.01
//                let baseNumber = popOperand()
//                result = percent * baseNumber  // %
//                secondResult = baseNumber
//            case "1/x":
//                // 𝝙% (delta %)
//                let secondNumber = popOperand()
//                let baseNumber = popOperand()
//                result = (secondNumber - baseNumber) / baseNumber * 100
//                secondResult = baseNumber
//            case "CHS":
//                // ABS (absolute value)
//                result = abs(popOperand())
//            case "1":  // sent from digitPressed
//                // →P - convert rectangular coordinates to polar
//                let x = popOperand()
//                let y = popOperand()
//                result = sqrt(x * x + y * y)  // radius
//                secondResult = atan2(y, x) / angleConversion  // angle
//            case "2":  // sent from digitPressed
//                // →H convert hours-minutes-seconds-decimal seconds (H.MMSSsssss) to decimal hour
//                let hoursMinuteSeconds = popOperand()  // ex. hoursMinutesSeconds = 1.1404200
//                let hours = Int(hoursMinuteSeconds)  // ex. hours = 1
//                let decimal = Int(round((hoursMinuteSeconds - Double(hours)) * 10000000))  // ex. decimal = 1404200
//                let minutes = Int(decimal / 100000)  // ex. minutes = 14
//                let seconds = Double(decimal - minutes * 100000) / 1000  // ex. seconds = 4.2
//                result = Double(hours) + Double(minutes) / 60 + Double(seconds) / 3600
//            case "3":  // sent from digitPressed
//                // →DEG - convert to degrees
//                result = popOperand() / Constants.D2R
//            default:
//                break
//            }
//        case "H":  // hyperbolic trig function
//            switch operation {
//            case "SIN":
//                result = sinh(popOperand() * angleConversion)
//            case "COS":
//                result = cosh(popOperand() * angleConversion)
//            case "TAN":
//                result = tanh(popOperand() * angleConversion)
//            default:
//                break
//            }
//        case "h":  // inverse hyperbolic trig function
//            switch operation {
//            case "SIN":
//                result = asinh(popOperand()) / angleConversion
//            case "COS":
//                result = acosh(popOperand()) / angleConversion
//            case "TAN":
//                result = atanh(popOperand()) / angleConversion
//            default:
//                break
//            }
        default:
            break
        }
        
        if result.isNaN || result.isInfinite {  // ex. sqrt(-1) = NaN, 1/0 = +Inf, -1/0 = -Inf
            // restore stack to pre-error state
            realStack = saveStack
            error = .code(0)  // reset in CalculatorViewController.restoreFromError
        } else if abs(result) > Constants.maxValue {
            error = result > 0 ? .overflow : .underflow
        } else {
            if secondResult != nil {
                pushOperand(secondResult!)
            }
            pushOperand(result)
        }
        printMemory()
    }
    
    func printMemory() {
        print("          Real         Imag")
        let labels = ["T", "Z", "Y", "X"]
        for index in 0..<realStack.count {
            let realString = String(format: "% 8f", realStack[index]).padding(toLength: 11, withPad: " ", startingAt: 0)
            print(String(format: "   %@:  %@  % 8f", labels[index], realString, imagStack[index]))
        }
        print(String(format: "LSTx:  % 8f", lastXRegister))
        print(String(format: " RCL 0: %8f  1: %8f  2: %8f  3: %8f", storageRegisters["0"] ?? 0, storageRegisters["1"] ?? 0, storageRegisters["2"] ?? 0, storageRegisters["3"] ?? 0))
        print("---------------------------------------------------------")
    }
}
