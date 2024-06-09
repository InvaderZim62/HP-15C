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

struct Complex {
    var real: Double
    var imag: Double

    var mag: Double {
        pow(real, 2) + pow(imag, 2)
    }
}

class CalculatorBrain: Codable {
    
    var trigMode = TrigMode.DEG
    var lastXRegister = 0.0
    var error = Error.none
    var isConvertingPolar = false

    var xRegister: Double? {
        get {
            return realStack.last
        }
        set {
            realStack[realStack.count - 1] = newValue!  // ok to assume realStack is not empty (count > 0)
            printMemory()
        }
    }
    
    var xRegisterImag: Double? {
        get {
            return imagStack.last
        }
        set {
            imagStack[imagStack.count - 1] = newValue!  // ok to assume imagStack is not empty (count > 0)
        }
    }
    
    var angleConversion: Double {
        if isComplexMode && !isConvertingPolar {
            return 1.0  // HP-15C does all trig function in radians, except conversions between rectangular and polar coordinates
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

    var isComplexMode = false {
        didSet {
            // clear imagStack when entering or exiting complex mode
            if isComplexMode != oldValue {
                clearImaginaryStack()
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

    private enum CodingKeys: String, CodingKey { case trigMode, lastXRegister, error, isComplexMode, xRegister, realStack, imagStack, storageRegisters }
    
    init() { }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trigMode = try container.decode(TrigMode.self, forKey: .trigMode)
        self.lastXRegister = try container.decode(Double.self, forKey: .lastXRegister)
        self.error = try container.decode(Error.self, forKey: .error)
        self.isComplexMode = try container.decode(Bool.self, forKey: .isComplexMode)
        self.xRegister = try container.decodeIfPresent(Double.self, forKey: .xRegister)
        self.realStack = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .realStack)) as? [Double] ?? []
        self.imagStack = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .imagStack)) as? [Double] ?? []
        self.storageRegisters = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .storageRegisters)) as? [String: Double] ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.trigMode, forKey: .trigMode)
        try container.encode(self.lastXRegister, forKey: .lastXRegister)
        try container.encode(self.error, forKey: .error)
        try container.encode(self.isComplexMode, forKey: .isComplexMode)
        try container.encodeIfPresent(self.xRegister, forKey: .xRegister)
        try container.encode(JSONSerialization.data(withJSONObject: realStack), forKey: .realStack)
        try container.encode(JSONSerialization.data(withJSONObject: imagStack), forKey: .imagStack)
        try container.encode(JSONSerialization.data(withJSONObject: storageRegisters), forKey: .storageRegisters)
    }
    
    // MARK: - Start of code
    
    func pushOperand(_ operand: Double) {
        realStack.append(operand)
        imagStack.append(0)
    }
    
    func pushOperand(_ operand: Complex) {
        realStack.append(operand.real)
        imagStack.append(operand.imag)
    }
    
    // remove and return end of stack (X register)
    func popOperand() -> Complex {
        Complex(real: realStack.popLast()!, imag: imagStack.popLast()!)
    }
    
    // remove end of stack
    func popXRegister() {
        realStack.removeLast()
        if isComplexMode { imagStack.removeLast() }
        printMemory()
    }
    
    func swapRealImag() {
        let temp = imagStack.last
        xRegisterImag = xRegister
        xRegister = temp
    }
    
    func clearAll() {
        clearStorageRegisters()
        clearRealStack()
        clearImaginaryStack()
        lastXRegister = 0.0
        printMemory()
    }
    
    func clearStorageRegisters() {
        storageRegisters.removeAll()
    }
    
    func clearRealStack() {
        realStack = [Double](repeating: 0.0, count: Constants.stackSize)
    }
    
    func clearImaginaryStack() {
        imagStack = [Double](repeating: 0.0, count: Constants.stackSize)
    }

    func swapXyRegisters() {
        realStack.swapAt(Constants.stackSize - 1, Constants.stackSize - 2)  // swap last two elements
        printMemory()
    }
    
    func rollStack(directionDown: Bool) {
        if directionDown {
            let xRegisterReal = realStack.removeLast()  // Note: realStack didSet pads beginning back to count = 4 after this
            realStack.insert(xRegisterReal, at: 1)      // that's why insert at 1 here, instead of 0 (didSet truncates index 0)
            let xRegisterImag = imagStack.removeLast()
            imagStack.insert(xRegisterImag, at: 1)
        } else {
            let tRegisterReal = realStack.remove(at: 0)
            realStack.append(tRegisterReal)
            let tRegisterImag = imagStack.remove(at: 0)
            imagStack.append(tRegisterImag)
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
        var result = Complex(real: 0, imag: 0)
        var secondResult: Complex? = nil
        
        let prefixKey = prefixAndOperation.first  // prefix is always one letter
        let operation = prefixAndOperation.dropFirst()

        isConvertingPolar = false
        
        switch prefixKey {
        case "n":  // none (primary button functions)
            switch operation {
            case "÷":
                // (a + bi) / (c + di) = (ac + bd)/(c² + d²) + (bc - ad)/(c² + d²)i
                let denominator = popOperand()
                let numerator = popOperand()
                // handle divide by zero, below (and in CalculatorViewController.updateDisplayString)
                let den = pow(denominator.real, 2) + pow(denominator.imag, 2)
                result.real = (numerator.real * denominator.real + numerator.imag * denominator.imag) / den
                result.imag = (numerator.imag * denominator.real - numerator.real * denominator.imag) / den
            case "×":
                // (a + bi) x (c + di) = (ac - bd) + (ad + bc)i
                let term1 = popOperand()
                let term2 = popOperand()
                result.real = (term1.real * term2.real - term1.imag * term2.imag)
                result.imag = (term1.real * term2.imag + term1.imag * term2.real)
            case "–":
                // (a + bi) - (c + di) = (a - c) + (b - d)i
                let term2 = popOperand()
                let term1 = popOperand()
                result.real = term1.real - term2.real
                result.imag = term1.imag - term2.imag
            case "+":
                // (a + bi) - (c + di) = (a - c) + (b - d)i
                let term1 = popOperand()
                let term2 = popOperand()
                result.real = term1.real + term2.real
                result.imag = term1.imag + term2.imag
            case "SIN":
                // sin(a + bi) = sin(a)cosh(b) + cos(a)sinh(b)i
                let term = popOperand()
                result.real = sin(term.real * angleConversion) * cosh(term.imag * angleConversion)
                result.imag = cos(term.real * angleConversion) * sinh(term.imag * angleConversion)
            case "COS":
                // cos(a + bi) = cos(a)cosh(b) + sin(a)sinh(b)i
                let term = popOperand()
                result.real = cos(term.real * angleConversion) * cosh(term.imag * angleConversion)
                result.imag = sin(term.real * angleConversion) * sinh(term.imag * angleConversion)
            case "TAN":
                // tan(a + bi) = [tan(a) - tan(a)tanh²(b)] / [1 + tan²(a)tanh²(b)] + [tanh(b) + tan²(a)tanh(b)] / [1 + tan²(a)tanh²(b)]i
                let term = popOperand()
                let den = 1 + pow(tan(term.real * angleConversion), 2) * pow(tanh(term.imag * angleConversion), 2)
                result.real = tan(term.real * angleConversion) * (1 - pow(tanh(term.imag * angleConversion), 2)) / den
                result.imag = (tanh(term.imag * angleConversion) * (1 + pow(tan(term.real * angleConversion), 2))) / den
            case "√x":
                // sqrt(a + bi) = sqrt[(mag + a)/2] + b/abs(b)*sqrt[(mag - a)/2]i, where mag = sqrt(a² + b²)
                let term = popOperand()
                if term.imag == 0 {
                    result.real = sqrt(term.real)
                    result.imag = 0
                } else {
                    let mag = pow(term.real, 2) + pow(term.imag, 2)
                    result.real = sqrt((mag + term.real) / 2)
                    result.imag = term.imag / abs(term.imag) * sqrt((mag - term.real) / 2)
                }
            case "ex":
                // e^(a + bi) = e^a * cos(b) + e^a * sin(b)i
                let term = popOperand()
                result.real = exp(term.real) * cos(term.imag * angleConversion)
                result.imag = exp(term.real) * sin(term.imag * angleConversion)
            case "10x":
                // 10^(a + bi) = 10^a * cos(b*ln(10)) + 10^a * sin(b*ln(10))i
                let power = popOperand()
                result.real = pow(10, power.real) * cos(power.imag * log(10) * angleConversion)
                result.imag = pow(10, power.real) * sin(power.imag * log(10) * angleConversion)
            case "yx":
                let power = popOperand()
                let term = popOperand()
                result.real = pow(term.real, power.real)  // pws: only implemented using the real parts, for now
                result.imag = 0
            case "1/x":
                // 1/(a + bi) = a/(a² + b²) - b/(a² + b²)i
                let term = popOperand()
                let den = pow(term.real, 2) + pow(term.imag, 2)
                result.real = term.real / den
                result.imag = -term.imag / den
            case "CHS":
                // CHS only changes the sign of the real part of the imaginary number on the HP-15C
                let term = popOperand()
                result.real = -term.real
                result.imag = term.imag
            default:
                break
            }
        case "f":  // functions above button (orange)
            switch operation {
            case "STO":
                // FRAC - decimal portion of number
                let number = popOperand()
                result.real = number.real - Double(Int(number.real))
                result.imag = number.imag
            case "1":  // sent from digitPressed
                // →R - convert polar coordinates to rectangular
                isConvertingPolar = true
                if isComplexMode {
                    let polar = popOperand()
                    let radius = polar.real
                    let angle = polar.imag
                    result.real = radius * cos(angle * angleConversion)  // x
                    result.imag = radius * sin(angle * angleConversion)  // y
                } else {
                    let radius = popOperand().real
                    let angle = popOperand().real
                    result.real = radius * cos(angle * angleConversion)  // x
                    secondResult?.real = radius * sin(angle * angleConversion)  // y
                }
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
            default:
                break
            }
        case "g":  // functions below button (blue)
            switch operation {
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
            case "1":  // sent from digitPressed
                // →P - convert rectangular coordinates to polar
                isConvertingPolar = true
                if isComplexMode {
                    let rectangular = popOperand()
                    let x = rectangular.real
                    let y = rectangular.imag
                    result.real = rectangular.mag  // radius
                    result.imag = atan2(y, x) / angleConversion  // angle
                } else {
                    let x = popOperand().real
                    let y = popOperand().real
                    result.real = sqrt(x * x + y * y)  // radius
                    secondResult?.real = atan2(y, x) / angleConversion  // angle
                }
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
            default:
                break
            }
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
        
        if result.real.isNaN || result.imag.isNaN || result.real.isInfinite || result.imag.isInfinite {  // ex. sqrt(-1) = NaN, 1/0 = +Inf, -1/0 = -Inf
            // restore stack to pre-error state
            realStack = saveStack
            error = .code(0)  // reset in CalculatorViewController.restoreFromError
        } else if result.mag > Constants.maxValue {
            error = result.real > 0 ? .overflow : .underflow  // pws wrong: underflow isn't negative overflow, it's mag < smallest allowable value
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
