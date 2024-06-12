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
        imagStack.removeLast()
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
                let divisor = popOperand()
                result = popOperand() / divisor  // let DisplayView handle divide by zero (result = "inf")
            case "×":
                result = popOperand() * popOperand()
            case "–":
                result = -popOperand() + popOperand()
            case "+":
                result = popOperand() + popOperand()
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
                result = popOperand().squareRoot
            case "ex":
                result = popOperand().exponential
            case "10x":
                result = popOperand().tenToThePowerOf
            case "yx":
                let x = popOperand()
                result = popOperand()^x
            case "1/x":
                result = popOperand().inverse
            case "CHS":
                // CHS only changes the sign of the real part of the imaginary number on the HP-15C
                let term = popOperand()
                result = Complex(real: -term.real, imag: term.imag)
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
            case "2":  // sent from digitPressed
                // →H.MS - convert decimal hours to hours-minutes-seconds-decimal seconds (H.MMSSsssss)
                let term = popOperand()
                let decimalHours = term.real
                let hours = Int(decimalHours)
                let minutes = Int((decimalHours - Double(hours)) * 60)
                let seconds = (decimalHours - Double(hours) - Double(minutes) / 60) * 3600
                result.real = Double(hours) + Double(minutes) / 100 + seconds / 10000
                result.imag = term.imag
            case "3":  // sent from digitPressed
                // →RAD - convert to radians
                let term = popOperand()
                result = Complex(real: term.real * Constants.D2R, imag: term.imag)  // only applies to the real portion
            default:
                break
            }
        case "g":  // functions below button (blue)
            switch operation {
            case "STO":
                // INT
                let term = popOperand()
                result = Complex(real: Double(Int(term.real)), imag: term.imag)
            case "SIN":
                // SIN-1 (arcsin)
                // asin(z) = -i * ln{sqrt[1 - z²] + zi}
                let term = popOperand()
                result = -Complex.i * ((1 - term.squared).squareRoot + term * Complex.i).naturalLog / angleConversion
            case "COS":
                // COS-1 (arccos)
                // acos(z) = -i * ln{sqrt[z² - 1] + z}
                let term = popOperand()
                result = -Complex.i * ((term.squared - 1).squareRoot + term).naturalLog / angleConversion
            case "TAN":
                // TAN-1 (arctan)
                // atan(z) = -i / 2 * ln{(i - z)/(i + z)}
                let term = popOperand()
                result = -Complex.i / 2 * ((Complex.i - term) / (Complex.i + term)).naturalLog / angleConversion
            case "√x":
                // x²
                result = popOperand().squared
            case "ex":
                // LN (natural log)
                result = popOperand().naturalLog
            case "10x":
                // LOG (base 10)
                result = popOperand().logBase10
            case "yx":
                // %
                // Note: Owner's Handbook p.130 says "Any functions not mentioned below or in the rest of this section
                //       (Calculating With Complex Numbers) ignore the imaginary stack."  Percent seems to fall in this
                //       category, although (a + bi) ENTER (c + di) % gives a complex number answer.  I just use the
                //       real portion of the x value (c + 0i).
                let percent = popOperand().real * 0.01
                let baseNumber = popOperand()
                result.real = percent * baseNumber.real  // %
                secondResult = baseNumber
            case "1/x":
                // 𝝙% (delta %)
                let secondNumber = popOperand().real
                let baseNumber = popOperand()
                result.real = (secondNumber - baseNumber.real) / baseNumber.real * 100
                secondResult = baseNumber
            case "CHS":
                // ABS (absolute value)
                result = Complex(real: popOperand().mag, imag: 0)
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
            case "2":  // sent from digitPressed
                // →H convert hours-minutes-seconds-decimal seconds (H.MMSSsssss) to decimal hour
                let term = popOperand()
                let hoursMinuteSeconds = term.real  // ex. hoursMinutesSeconds = 1.1404200
                let hours = Int(hoursMinuteSeconds)  // ex. hours = 1
                let decimal = Int(round((hoursMinuteSeconds - Double(hours)) * 10000000))  // ex. decimal = 1404200
                let minutes = Int(decimal / 100000)  // ex. minutes = 14
                let seconds = Double(decimal - minutes * 100000) / 1000  // ex. seconds = 4.2
                result.real = Double(hours) + Double(minutes) / 60 + Double(seconds) / 3600
                result.imag = term.imag
            case "3":  // sent from digitPressed
                // →DEG - convert to degrees
                let term = popOperand()
                result = Complex(real: term.real / Constants.D2R, imag: term.imag)  // only applies to the real portion
            default:
                break
            }
        case "H":  // hyperbolic trig functions
            // Note: Owner's Handbook p.26 says "The trigonometric functions operate in the trigonometric mode you select",
            //       but this does not appear to be true for the hyperbolic trig functions.  They all operate in radians
            //       for real and complex numbers.
            switch operation {
            case "SIN":
                // sinh(a + bi) = sinh(a)cos(b) + cosh(a)sin(b)i
                let term = popOperand()
                result.real = sinh(term.real) * cos(term.imag)
                result.imag = cosh(term.real) * sin(term.imag)
            case "COS":
                // cosh(a + bi) = cosh(a)cos(b) + sinh(a)sin(b)i
                let term = popOperand()
                result.real = cosh(term.real) * cos(term.imag)
                result.imag = sinh(term.real) * sin(term.imag)
            case "TAN":
                // tanh(a + bi) = [tanh(a) + tanh(a)tan²(b)] / [1 + tanh²(a)tan²(b)] + [tan(b) - tanh²(a)tan(b)] / [1 + tanh²(a)tan²(b)]i
                let term = popOperand()
                let den = 1 + pow(tanh(term.real), 2) * pow(tan(term.imag), 2)
                result.real = tanh(term.real) * (1 + pow(tan(term.imag), 2)) / den
                result.imag = (tan(term.imag) * (1 - pow(tanh(term.real), 2))) / den
            default:
                break
            }
        case "h":  // inverse hyperbolic trig functions
            // See note above.  Inverse hyperbolic trig functions are all in radians.
            switch operation {
            case "SIN":
                // arcsinh(z) = ln(z + sqrt(z^2 + 1))
                let term = popOperand()
                result = (term + (term.squared + 1).squareRoot).naturalLog
            case "COS":
                // arccosh(z) = ln(z + sqrt(z^2 - 1))
                let term = popOperand()
                result = (term + (term.squared - 1).squareRoot).naturalLog
            case "TAN":
                // arctanh(z) = 1/2 * ln((1 + z)/(1 - z))
                let term = popOperand()
                result = 0.5 * ((1 + term) / (1 - term)).naturalLog
            default:
                break
            }
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
