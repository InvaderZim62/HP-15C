//
//  Brain.swift
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

protocol Stackable: Codable { }

extension Double: Stackable { }  // extend Double to also be of type "Stackable"

struct Constants {
    static let stackSize = 4  // T, Z, Y, X
    static let D2R = Double.pi / 180
    static let G2R = Double.pi / 200  // gradians to radians
    static let maxValue = 9.999999999e99  // more cause overflow on HP-15C
    static let maxSolveIterations = 100  // during Solve, show Error 8, if root not found after max iterations
}

enum Error: Equatable, Codable {
    case code(Int)  // see Appendix A of Owner's Handbook, ex. 1/0, sqrt(-1), acos(1.1) are code 0, STO √x is code 3, STO EEX is code 11
    case overflow
    case underflow
    case badKeySequence
    case none
}

class Brain: Codable {
    
    var trigUnits = TrigUnits.DEG
    var lastXRegister: Stackable = 0.0
    var error = Error.none
    var isConvertingPolar = false  // all complex trig functions are in radians, except conversions between rectangular and polar coordinates
    var isSolving = false  // use to disable printMemory while solving for root

    var xRegister: Stackable? {  // Double or Matrix
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
    
    var yRegister: Stackable {
        realStack[2]
    }
    
    // register name stored in the I register
    //  0:  "0",  1:  "1",...  9:  "9"
    // 10: ".0", 11: ".1",... 19: ".9"
    // 20: "20", 21: "21",... 29: "29"
    // ...
    var iRegisterName: String {
        let registerNumber = min(Int(abs(storageRegisters["I"]! as! Double)), 65)  // will fail if register I contains a Matrix
        switch registerNumber {
        case 10...19:
            return String(String(format: "%.1f", (Double(registerNumber) - 10)/10).dropFirst())
        default:
            return String(registerNumber)
        }
    }
    
    var angleConversion: Double {
        if isComplexMode && !isConvertingPolar {
            return 1.0  // HP-15C does all complex trig functions in radians, except conversions between rectangular and polar coordinates
        } else {
            switch trigUnits {
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
        var mantissa = String(abs(xRegister! as! Double))  // will fail, if xRegister contains a Matrix
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

    private var realStack = [Stackable](repeating: 0.0, count: Constants.stackSize) {  // T, Z, Y, X
        didSet {
            // truncate stack to last 4 elements, then pad front with repeat of 0th element if size < 4
            realStack = realStack.suffix(Constants.stackSize)
            realStack.insert(contentsOf: repeatElement(realStack[0], count: Constants.stackSize - realStack.count), at: 0)
        }
    }

    private var imagStack = [Double](repeating: 0.0, count: Constants.stackSize) {  // T, Z, Y, X
        didSet {
            // truncate stack to last 4 elements, then pad front with repeat of 0th element if size < 4
            imagStack = imagStack.suffix(Constants.stackSize)
            imagStack.insert(contentsOf: repeatElement(imagStack[0], count: Constants.stackSize - imagStack.count), at: 0)
        }
    }

    private var storageRegisters: [String: Stackable] = [  // [register name: number or matrix]
        "I": 0.0,
         "0": 0,  "1": 0,  "2": 0,  "3": 0,  "4": 0,  "5": 0,  "6": 0,  "7": 0,  "8": 0,  "9": 0,
        ".0": 0, ".1": 0, ".2": 0, ".3": 0, ".4": 0, ".5": 0, ".6": 0, ".7": 0, ".8": 0, ".9": 0,
         // the remaining registers are not available on the HP-15C by default;
         // they can be accessed by reallocating memory using the DIM function
//        "20": 0, "21": 0, "22": 0, "23": 0, "24": 0, "25": 0, "26": 0, "27": 0, "28": 0, "29": 0,
//        "30": 0, "31": 0, "32": 0, "33": 0, "34": 0, "35": 0, "36": 0, "37": 0, "38": 0, "39": 0,
//        "40": 0, "41": 0, "42": 0, "43": 0, "44": 0, "45": 0, "46": 0, "47": 0, "48": 0, "49": 0,
//        "50": 0, "51": 0, "52": 0, "53": 0, "54": 0, "55": 0, "56": 0, "57": 0, "58": 0, "59": 0,
//        "60": 0, "61": 0, "62": 0, "63": 0, "64": 0, "65": 0
        ]
    
    var matrices: [String: Matrix] = [  // button name: matrix
        "√x"  : Matrix(name: "A"),
        "ex"  : Matrix(name: "B"),
        "10x" : Matrix(name: "C"),
        "yx"  : Matrix(name: "D"),
        "1/x" : Matrix(name: "E")
    ]

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case trigUnits, lastXRegister, error, isComplexMode, realStack, imagStack, storageRegisters, matrices }
    
    init() { }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trigUnits = try container.decode(TrigUnits.self, forKey: .trigUnits)
        if let decoded = try? container.decode(AnyDecodable.self, forKey: .lastXRegister) {
            self.lastXRegister = decoded.item as! Stackable
        }
        self.error = try container.decode(Error.self, forKey: .error)
        self.isComplexMode = try container.decode(Bool.self, forKey: .isComplexMode)
        if let decoded = try? container.decode([AnyDecodable].self, forKey: .realStack) {
            // convert from [AnyDecodable] to [Stackable]
            self.realStack = decoded.map { $0.item as! Stackable }
        }
        self.imagStack = try JSONSerialization.jsonObject(with: container.decode(Data.self, forKey: .imagStack)) as? [Double] ?? []
        if let decoded = try? container.decode([String: AnyDecodable].self, forKey: .storageRegisters) {
            // convert from [String: AnyDecodable] to [String: Stackable]
            self.storageRegisters = decoded.mapValues { $0.item as! Stackable }
        }
        self.matrices = try container.decode([String: Matrix].self, forKey: .matrices)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.trigUnits, forKey: .trigUnits)
        try container.encode(self.lastXRegister, forKey: .lastXRegister)
        try container.encode(self.error, forKey: .error)
        try container.encode(self.isComplexMode, forKey: .isComplexMode)
        try container.encode(self.realStack.map { AnyEncodable(item: $0) }, forKey: .realStack)
        try container.encode(JSONSerialization.data(withJSONObject: imagStack), forKey: .imagStack)
        try container.encode(self.storageRegisters.mapValues { AnyEncodable(item: $0) }, forKey: .storageRegisters)
        try container.encode(self.matrices, forKey: .matrices)
    }

    // trick to encode items conforming to protocol Stackable
    // from: https://stackoverflow.com/a/78279115/2526464
    struct AnyEncodable: Encodable {
        let item: any Encodable
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.item)
        }
    }

    struct AnyDecodable: Decodable {
        let item: any Decodable
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(Double.self) {
                self.item = value
            } else if let value = try? container.decode(Matrix.self) {
                self.item = value
            } else {
                self.item = 0
            }
        }
    }

    // MARK: - Start of code
    
    func pushOperand(_ operand: Stackable) {
        realStack.append(operand)
        imagStack.append(0)
    }
    
    func pushOperand(_ operand: Complex) {
        realStack.append(operand.real)
        imagStack.append(operand.imag)
    }

    // remove and return end of stack (X register)
    func popOperand() -> Stackable {     // Complex or Matrix
        let real = realStack.popLast()!  // Stackable => Double or Matrix
        let imag = imagStack.popLast()!  // Double
        if real is Double {
            return Complex(real: real as! Double, imag: imag)
        } else {
            return real  // Matrix
        }
    }
    
    func pushXRegister() {
        realStack.append(xRegister!)
        imagStack.append(xRegisterImag!)
    }

    // remove end of stack
    func popXRegister() {
        realStack.removeLast()
        imagStack.removeLast()
        printMemory()
    }
    
    func fillRegistersWith(_ operand: Double) {
        pushOperand(operand)
        pushOperand(operand)
        pushOperand(operand)
        pushOperand(operand)
    }
    
    func swapRealImag() {
        let temp = imagStack.last
        xRegisterImag = xRegister as? Double  // will fail, if xRegister contains a Matrix
        xRegister = temp
    }
    
    func clearStorageRegisters() {
        storageRegisters.keys.forEach { storageRegisters[$0] = 0 }
        printMemory()
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
    
    func swapXWithRegister(_ name: String) {
        let temp = storageRegisters[name]!
        storageRegisters[name] = xRegister!
        xRegister = temp
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
    
    // store value in register, if it exists, else return false
    func storeValueInRegister(_ name: String, value: Stackable) -> Bool {
        if let _ = storageRegisters[name] {
            storageRegisters[name] = value
            return true
        } else {
            return false
        }
    }
    
    func valueFromStorageRegister(_ name: String) -> Stackable? {
        storageRegisters[name]
    }
    
    func moveRealXToImagX() {
        imagStack[2] = xRegister! as! Double  // will fail, if xRegister contains a Matrix
        popXRegister()
        printMemory()
    }

    func performOperation(_ prefixAndOperation: String) {
        let saveStack = realStack  // save in case of nan or inf
        var result: Stackable?  // Complex or Matrix
        var secondResult: Stackable? = nil
        
        let prefixKey = prefixAndOperation.first  // prefix is always one letter
        let operation = prefixAndOperation.dropFirst()

        isConvertingPolar = false
        
        switch prefixKey {
        case "n":  // none (primary button functions)
            switch operation {
//            case "÷":
//                let divisor = popOperand()
//                result = popOperand() / divisor  // let DisplayView handle divide by zero (result = "inf")
//            case "×":
//                result = popOperand() * popOperand()
//            case "–":
//                result = -popOperand() + popOperand()
            case "+":
                let operandA = popOperand()  // Complex or Matrix
                let operandB = popOperand()  // "
                if let complexA = operandA as? Complex {
                    if let complexB = operandB as? Complex {
                        result = complexA + complexB
                    } else if let matrixB = operandB as? Matrix {
                        result = matrixB + complexA.real
                    }
                } else if let matrixA = operandA as? Matrix {
                    if let matrixB = operandB as? Matrix {
                        result = matrixA + matrixB
                    } else if let complexB = operandB as? Complex {
                        result = matrixA + complexB.real
                    }
                }
//            case "SIN":
//                result = (popOperand() * angleConversion).sine
//            case "COS":
//                result = (popOperand() * angleConversion).cosine
//            case "TAN":
//                result = (popOperand() * angleConversion).tangent
//            case "√x":
//                if isComplexMode {
//                    // both methods give same real answer for positive operands, but .squareRoot does not return
//                    // NaN, if operand is negative (it return a valid complex number); must use sqrt() to get NaN.
//                    result = popOperand().squareRoot
//                } else {
//                    result.real = sqrt(popOperand().real)
//                }
//            case "ex":
//                result = popOperand().exponential
//            case "10x":
//                result = popOperand().tenToThePowerOf
//            case "yx":
//                let x = popOperand()
//                result = popOperand()^x
//            case "1/x":
//                result = popOperand().inverse
//            case "CHS":
//                // CHS only changes the sign of the real part of the imaginary number on the HP-15C
//                let term = popOperand()
//                result = Complex(real: -term.real, imag: term.imag)
//            default:
//                break
//            }
//        case "f":  // functions above button (orange)
//            switch operation {
//            case "STO":
//                // FRAC - decimal portion of number
//                let number = popOperand()
//                result.real = number.real - Double(Int(number.real))
//                result.imag = number.imag
//            case "1":
//                // →R - convert polar coordinates to rectangular
//                isConvertingPolar = true
//                if isComplexMode {
//                    let polar = popOperand()
//                    let radius = polar.real
//                    let angle = polar.imag
//                    result.real = radius * cos(angle * angleConversion)  // x
//                    result.imag = radius * sin(angle * angleConversion)  // y
//                } else {
//                    let radius = popOperand().real
//                    let angle = popOperand().real
//                    result.real = radius * cos(angle * angleConversion)  // x
//                    secondResult = Complex(real: radius * sin(angle * angleConversion), imag: 0)  // y
//                }
//            case "2":
//                // →H.MS - convert decimal hours to hours-minutes-seconds-decimal seconds (H.MMSSsssss)
//                let term = popOperand()
//                let decimalHours = term.real
//                let hours = Int(decimalHours)
//                let minutes = Int((decimalHours - Double(hours)) * 60)
//                let seconds = (decimalHours - Double(hours) - Double(minutes) / 60) * 3600
//                result.real = Double(hours) + Double(minutes) / 100 + seconds / 10000
//                result.imag = term.imag
//            case "3":
//                // →RAD - convert to radians
//                let term = popOperand()
//                result = Complex(real: term.real * Constants.D2R, imag: term.imag)  // only applies to the real portion
//            default:
//                break
//            }
//        case "g":  // functions below button (blue)
//            switch operation {
//            case "STO":
//                // INT
//                let term = popOperand()
//                result = Complex(real: Double(Int(term.real)), imag: term.imag)
//            case "SIN":
//                // SIN-1 (arcsin)
//                if isComplexMode {
//                    // both methods give same real answer for abs(operands) < 1, but .arcsin does not return
//                    // NaN, if abs(operand) > 1 (it returns a valid complex number); must use asin() to get NaN.
//                    result = popOperand().arcsin
//                } else {
//                    result.real = asin(popOperand().real) / angleConversion
//                }
//            case "COS":
//                // COS-1 (arccos)
//                if isComplexMode {
//                    // both methods give same real answer for abs(operands) < 1, but .arccos does not return
//                    // NaN, if abs(operand) > 1 (it returns a valid complex number); must use acos() to get NaN.
//                    result = popOperand().arccos
//                } else {
//                    result.real = acos(popOperand().real) / angleConversion
//                }
//            case "TAN":
//                // TAN-1 (arctan)
//                result = (popOperand() / angleConversion).arctan
//            case "√x":
//                // x²
//                result = popOperand().squared
//            case "ex":
//                // LN (natural log)
//                result = popOperand().naturalLog
//            case "10x":
//                // LOG (base 10)
//                result = popOperand().logBase10
//            case "yx":
//                // %
//                // Note: Owner's Handbook p.130 says "Any functions not mentioned below or in the rest of this section
//                //       (Calculating With Complex Numbers) ignore the imaginary stack."  Percent seems to fall in this
//                //       category, although (a + bi) ENTER (c + di) % gives a complex number answer.  I just use the
//                //       real portion of the x value (c + 0i).
//                let percent = popOperand().real * 0.01
//                let baseNumber = popOperand()
//                result.real = percent * baseNumber.real  // %
//                secondResult = baseNumber
//            case "1/x":
//                // 𝝙% (delta %)
//                let secondNumber = popOperand().real
//                let baseNumber = popOperand()
//                result.real = (secondNumber - baseNumber.real) / baseNumber.real * 100
//                secondResult = baseNumber
//            case "CHS":
//                // ABS (absolute value)
//                result = Complex(real: popOperand().mag, imag: 0)
//            case "1":
//                // →P - convert rectangular coordinates to polar
//                isConvertingPolar = true
//                if isComplexMode {
//                    // rectangular coordinates (x and y) come from real and imaginary parts of complex number in X registers
//                    let rectangular = popOperand()
//                    let x = rectangular.real
//                    let y = rectangular.imag
//                    result.real = rectangular.mag  // radius
//                    result.imag = atan2(y, x) / angleConversion  // angle
//                } else {
//                    // rectangular coordinate x comes from X register, y comes from Y register
//                    let x = popOperand().real
//                    let y = popOperand().real
//                    result.real = sqrt(x * x + y * y)  // radius
//                    secondResult = Complex(real: atan2(y, x) / angleConversion, imag: 0)  // angle
//                }
//            case "2":
//                // →H convert hours-minutes-seconds-decimal seconds (H.MMSSsssss) to decimal hour
//                let term = popOperand()
//                let hoursMinuteSeconds = term.real  // ex. hoursMinutesSeconds = 1.1404200
//                let hours = Int(hoursMinuteSeconds)  // ex. hours = 1
//                let decimal = Int(round((hoursMinuteSeconds - Double(hours)) * 10000000))  // ex. decimal = 1404200
//                let minutes = Int(decimal / 100000)  // ex. minutes = 14
//                let seconds = Double(decimal - minutes * 100000) / 1000  // ex. seconds = 4.2
//                result.real = Double(hours) + Double(minutes) / 60 + Double(seconds) / 3600
//                result.imag = term.imag
//            case "3":
//                // →DEG - convert to degrees
//                let term = popOperand()
//                result = Complex(real: term.real / Constants.D2R, imag: term.imag)  // only applies to the real portion
//            default:
//                break
//            }
//        case "H":  // hyperbolic trig functions
//            // Note: Owner's Handbook p.26 says "The trigonometric functions operate in the trigonometric mode you select",
//            //       but this does not appear to be true for the hyperbolic trig functions.  They all operate in radians
//            //       for real and complex numbers.
//            switch operation {
//            case "SIN":
//                // HYP SIN
//                result = popOperand().sinhyp
//            case "COS":
//                // HYP COS
//                result = popOperand().coshyp
//            case "TAN":
//                // HYP TAN
//                result = popOperand().tanhyp
//            default:
//                break
//            }
//        case "h":  // inverse hyperbolic trig functions
//            // See note above.  Inverse hyperbolic trig functions are all in radians.
//            switch operation {
//            case "SIN":
//                // HYP-1 SIN
//                result = popOperand().arcsinh
//            case "COS":
//                // HYP-1 COS
//                if isComplexMode {
//                    // both methods give same real answer for operands > 1, but .arccosh does not return
//                    // NaN, if operand < 1 (it return a valid complex number); must use acosh() to get NaN.
//                    result = popOperand().arccosh
//                } else {
//                    result.real = acosh(popOperand().real)
//                }
//            case "TAN":
//                // HYP-1 TAN
//                if isComplexMode {
//                    // both methods give same real answer for abs(operands) < 1, but .arctanh does not return
//                    // NaN, if abs(operand) > 1 (it return a valid complex number); must use atanh() to get NaN.
//                    result = popOperand().arctanh
//                } else {
//                    result.real = atanh(popOperand().real)
//                }
            default:
                result = Complex(real: 0, imag: 0)
            }
        default:
            result = Complex(real: 0, imag: 0)
        }
        
        if let complex = result as? Complex {
            if complex.real.isNaN || complex.imag.isNaN || complex.real.isInfinite || complex.imag.isInfinite {  // ex. sqrt(-1) = NaN, 1/0 = +Inf, -1/0 = -Inf
                // restore stack to pre-error state
                realStack = saveStack
                error = .code(0)  // reset in CalculatorViewController.restoreFromError
            } else if complex.mag > Constants.maxValue {
                error = complex.real > 0 ? .overflow : .underflow  // pws: underflow should be a number less than 1E-99 (not neg overflow)
            } else {
                if secondResult != nil {
                    pushOperand(secondResult as! Complex)
                }
                pushOperand(complex)
            }
        } else if result == nil {
            error = .code(11)
        } else if let matrix = result as? Matrix {
            // TBD: handle error cases with matrix operations
            matrix.name = "B"
            matrices["ex"] = matrix  // pws: hard-code to B, for now (should be the designate RESULT matrix)
            if secondResult != nil {
                pushOperand(secondResult as! Matrix)
            }
            pushOperand(matrix)
        }
        printMemory()
    }
    
    func printMemory() {
        guard !isSolving else { return }
        print("          Real         Imag")
        let labels = ["T", "Z", "Y", "X"]
//        for index in 0..<realStack.count {
//            let realString = String(format: "% 8f", realStack[index]).padding(toLength: 11, withPad: " ", startingAt: 0)
//            print(String(format: "   %@:  %@  % 8f", labels[index], realString, imagStack[index]))
//        }
//        print(String(format: "LSTx:  % 8f", lastXRegister))
//        print(String(format: "Reg  0: %8f   1: %8f   2: %8f   3: %8f   4: %8f", storageRegisters["0"]!, storageRegisters["1"]!, storageRegisters["2"]!, storageRegisters["3"]!, storageRegisters["4"]!))
//        print(String(format: "    .0: %8f  .1: %8f  .2: %8f  .3: %8f  .4: %8f", storageRegisters[".0"]!, storageRegisters[".1"]!, storageRegisters[".2"]!, storageRegisters[".3"]!, storageRegisters[".4"]!))
//        print(String(format: "     I: %8f", storageRegisters["I"]!))
        print("---------------------------------------------------------")
    }
}
