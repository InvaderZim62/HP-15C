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
        if let number = xRegister as? Double {
            var mantissa = String(abs(number))
            if let ne = mantissa.firstIndex(of: "e") {
                mantissa = String(mantissa.prefix(upTo: ne))  // drop the exponent
            }
            mantissa = mantissa.replacingOccurrences(of: ".", with: "")
            if mantissa.count < 10 { mantissa += repeatElement("0", count: 10 - mantissa.count) }
            return mantissa
        } else if let matrix = xRegister as? Matrix {
            return matrix.descriptor
        } else {
            return ""  // shouldn't get here
        }
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

    private var storageRegisters: [String: Stackable] = [  // [register name: double or matrix]
        "I": 0.0,
        "0": 0,  "1": 0,  "2": 0,  "3": 0,  "4": 0,  "5": 0,  "6": 0,  "7": 0,  "8": 0,  "9": 0,
        ".0": 0, ".1": 0, ".2": 0, ".3": 0, ".4": 0, ".5": 0, ".6": 0, ".7": 0, ".8": 0, ".9": 0,
         // the remaining registers are not available on the HP-15C by default; they can
         // be accessed by reallocating memory using the DIM function (not implemented)
//        "20": 0, "21": 0, "22": 0, "23": 0, "24": 0, "25": 0, "26": 0, "27": 0, "28": 0, "29": 0,
//        "30": 0, "31": 0, "32": 0, "33": 0, "34": 0, "35": 0, "36": 0, "37": 0, "38": 0, "39": 0,
//        "40": 0, "41": 0, "42": 0, "43": 0, "44": 0, "45": 0, "46": 0, "47": 0, "48": 0, "49": 0,
//        "50": 0, "51": 0, "52": 0, "53": 0, "54": 0, "55": 0, "56": 0, "57": 0, "58": 0, "59": 0,
//        "60": 0, "61": 0, "62": 0, "63": 0, "64": 0, "65": 0
        ]
    
    var matrices: [String: Matrix] = [  // button name: matrix
        "A"  : Matrix(name: "A"),
        "B"  : Matrix(name: "B"),
        "C" : Matrix(name: "C"),
        "D"  : Matrix(name: "D"),
        "E" : Matrix(name: "E")
    ]
    
    var resultMatrixName = "A"

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case trigUnits, lastXRegister, isComplexMode, realStack, imagStack, storageRegisters, matrices, resultMatrixName }
    
    init() { }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trigUnits = try container.decode(TrigUnits.self, forKey: .trigUnits)
        if let decoded = try? container.decode(AnyDecodable.self, forKey: .lastXRegister) {
            self.lastXRegister = decoded.item as! Stackable
        }
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
        self.resultMatrixName = try container.decode(String.self, forKey: .resultMatrixName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.trigUnits, forKey: .trigUnits)
        try container.encode(self.lastXRegister, forKey: .lastXRegister)
        try container.encode(self.isComplexMode, forKey: .isComplexMode)
        try container.encode(self.realStack.map { AnyEncodable(item: $0) }, forKey: .realStack)
        try container.encode(JSONSerialization.data(withJSONObject: imagStack), forKey: .imagStack)
        try container.encode(self.storageRegisters.mapValues { AnyEncodable(item: $0) }, forKey: .storageRegisters)
        try container.encode(self.matrices, forKey: .matrices)
        try container.encode(self.resultMatrixName, forKey: .resultMatrixName)
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
    
    func clearAllStorageRegisters() {
        storageRegisters.keys.forEach { storageRegisters[$0] = 0 }
        printMemory()
    }
    
    func clearStatisticsRegisters() {
        storageRegisters["2"] = 0
        storageRegisters["3"] = 0
        storageRegisters["4"] = 0
        storageRegisters["5"] = 0
        storageRegisters["6"] = 0
        storageRegisters["7"] = 0
        printMemory()
    }

    func clearRealStack() {
        realStack = [Double](repeating: 0.0, count: Constants.stackSize)
    }
    
    func clearImaginaryStack() {
        imagStack = [Double](repeating: 0.0, count: Constants.stackSize)
    }
    
    func clearMatrices() {
        matrices.values.forEach { $0.setDimensions(rows: 0, cols: 0) }
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
        var overwriteMatrix: String? = nil
        
        let prefixKey = prefixAndOperation.first  // prefix is always one letter
        let operation = prefixAndOperation.dropFirst()

        isConvertingPolar = false
        
        switch prefixKey {
        case "n":  // none (primary button functions)
            switch operation {
            case "÷":
                let operandB = popOperand()  // Complex or Matrix
                let operandA = popOperand()  // "
                if let complexA = operandA as? Complex {
                    if let complexB = operandB as? Complex {
                        result = complexA / complexB  // let DisplayView handle divide by zero (result = "inf")
                    } else if let matrixB = operandB as? Matrix {
                        if let inverseB = matrixB.inverse {
                            result = complexA.real * inverseB
                        } else {
                            realStack = saveStack  // restore stack to pre-error state
                            error = .code(11)
                            return
                        }
                    }
                } else if let matrixA = operandA as? Matrix {
                    if let complexB = operandB as? Complex {
                        result = matrixA / complexB.real
                    } else if let matrixB = operandB as? Matrix {
                        if let inverseB = matrixB.inverse {
                            result = matrixA * inverseB
                        } else {
                            realStack = saveStack  // restore stack to pre-error state
                            error = .code(11)
                            return
                        }
                    }
                }
            case "×":
                let operandB = popOperand()  // Complex or Matrix
                let operandA = popOperand()  // "
                if let complexA = operandA as? Complex {
                    if let complexB = operandB as? Complex {
                        result = complexA * complexB
                    } else if let matrixB = operandB as? Matrix {
                        result = complexA.real * matrixB
                    }
                } else if let matrixA = operandA as? Matrix {
                    if let complexB = operandB as? Complex {
                        result = matrixA * complexB.real
                    } else if let matrixB = operandB as? Matrix {
                        result = matrixA * matrixB
                    }
                }
            case "–":
                let operandB = popOperand()  // Complex or Matrix
                let operandA = popOperand()  // "
                if let complexA = operandA as? Complex {
                    if let complexB = operandB as? Complex {
                        result = complexA - complexB
                    } else if let matrixB = operandB as? Matrix {
                        result = complexA.real - matrixB
                    }
                } else if let matrixA = operandA as? Matrix {
                    if let complexB = operandB as? Complex {
                        result = matrixA - complexB.real
                    } else if let matrixB = operandB as? Matrix {
                        result = matrixA - matrixB
                    }
                }
            case "+":
                let operandB = popOperand()  // Complex or Matrix
                let operandA = popOperand()  // "
                if let complexA = operandA as? Complex {
                    if let complexB = operandB as? Complex {
                        result = complexA + complexB
                    } else if let matrixB = operandB as? Matrix {
                        result = complexA.real + matrixB
                    }
                } else if let matrixA = operandA as? Matrix {
                    if let complexB = operandB as? Complex {
                        result = matrixA + complexB.real
                    } else if let matrixB = operandB as? Matrix {
                        result = matrixA + matrixB
                    }
                }
            case "SIN":
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = (complex * angleConversion).sine
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "COS":
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = (complex * angleConversion).cosine
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "TAN":
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = (complex * angleConversion).tangent
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "√x":
                let operand = popOperand()
                if let complex = operand as? Complex {
                    if isComplexMode {
                        // both methods give same real answer for positive operands, but .squareRoot does not return
                        // NaN, if operand is negative (it return a valid complex number); must use sqrt() to get NaN.
                        result = complex.squareRoot
                    } else {
                        result = Complex(real: sqrt(complex.real), imag: 0)
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "ex":
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex.exponential
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "10x":
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex.tenToThePowerOf
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "yx":
                let operandB = popOperand()
                let operandA = popOperand()
                if let complexA = operandA as? Complex, let complexB = operandB as? Complex {
                    result = complexA^complexB
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "1/x":
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex.inverse
                } else if let matrix = operand as? Matrix {
                    result = matrix.inverse
                }
            case "CHS":
                // CHS only changes the sign of the real part of the imaginary number on the HP-15C
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = Complex(real: -complex.real, imag: complex.imag)
                } else if let matrix = operand as? Matrix {
                    result = -1 * matrix
                    overwriteMatrix = matrix.name  // overwrite original matrix
                }
            default:
                break
            }
        case "f":  // functions above button (orange)
            switch operation {
            case "STO":
                // FRAC - decimal portion of number
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = Complex(real: complex.real - Double(Int(complex.real)), imag: complex.imag)
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "0":
                // x!
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex.factorial
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "1":
                // →R - convert polar coordinates to rectangular
                isConvertingPolar = true
                let operandB = popOperand()
                if let complexB = operandB as? Complex {
                    if isComplexMode {
                        let polar = complexB
                        let radius = polar.real
                        let angle = polar.imag
                        result = Complex(real: radius * cos(angle * angleConversion),  // x
                                         imag: radius * sin(angle * angleConversion))  // y
                    } else {
                        let operandA = popOperand()
                        if let complexA = operandA as? Complex {
                            let radius = complexB.real
                            let angle = complexA.real
                            result = Complex(real: radius * cos(angle * angleConversion), imag: 0)  // x
                            secondResult = Complex(real: radius * sin(angle * angleConversion), imag: 0)  // y
                        } else {
                            realStack = saveStack  // restore stack to pre-error state
                            error = .code(1)
                            return
                        }
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "2":
                // →H.MS - convert decimal hours to hours-minutes-seconds-decimal seconds (H.MMSSsssss)
                let operand = popOperand()
                if let term = operand as? Complex {
                    let decimalHours = term.real
                    let hours = Int(decimalHours)
                    let minutes = Int((decimalHours - Double(hours)) * 60)
                    let seconds = (decimalHours - Double(hours) - Double(minutes) / 60) * 3600
                    result = Complex(real: Double(hours) + Double(minutes) / 100 + seconds / 10000, imag: term.imag)
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "3":
                // →RAD - convert to radians
                let operand = popOperand()
                if let term = operand as? Complex {
                    result = Complex(real: term.real * Constants.D2R, imag: term.imag)  // only applies to the real portion
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "+":
                // Py,x - permutations = y! / (y - x)!
                let operandX = popOperand()
                let operandY = popOperand()
                if let complexX = operandX as? Complex, let complexY = operandY as? Complex {
                    if floor(complexY.real) == complexY.real && floor(complexX.real) == complexX.real {
                        // complexX.real and complexY.real are whole numbers
                        result = Complex(real: floor(complexY.factorial.real / (complexY - complexX).factorial.real),
                                         imag: complexY.imag)
                    } else {
                        // can't compute permutation of decimals
                        realStack = saveStack  // restore stack to pre-error state
                        error = .code(0)
                        return
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(11)
                    return
                }
            default:
                break
            }
        case "g":  // functions below button (blue)
            switch operation {
            case "STO":
                // INT
                let operand = popOperand()
                if let term = operand as? Complex {
                    result = Complex(real: Double(Int(term.real)), imag: term.imag)
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "SIN":
                // SIN-1 (arcsin)
                let operand = popOperand()
                if let complex = operand as? Complex {
                    if isComplexMode {
                        // both methods give same real answer for abs(operands) < 1, but .arcsin does not return
                        // NaN, if abs(operand) > 1 (it returns a valid complex number); must use asin() to get NaN.
                        result = complex.arcsin
                    } else {
                        result = Complex(real: asin(complex.real) / angleConversion, imag: 0)
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "COS":
                // COS-1 (arccos)
                let operand = popOperand()
                if let complex = operand as? Complex {
                    if isComplexMode {
                        // both methods give same real answer for abs(operands) < 1, but .arccos does not return
                        // NaN, if abs(operand) > 1 (it returns a valid complex number); must use acos() to get NaN.
                        result = complex.arccos
                    } else {
                        result = Complex(real: acos(complex.real) / angleConversion, imag: 0)
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "TAN":
                // TAN-1 (arctan)
                let operand = popOperand()
                if let term = operand as? Complex {
                    result = (term / angleConversion).arctan
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "√x":
                // x²
                let operand = popOperand()
                if let term = operand as? Complex {
                    result = term.squared
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "ex":
                // LN (natural log)
                let operand = popOperand()
                if let term = operand as? Complex {
                    result = term.naturalLog
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "10x":
                // LOG (base 10)
                let operand = popOperand()
                if let term = operand as? Complex {
                    result = term.logBase10
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "yx":
                // %
                // Note: Owner's Handbook p.130 says "Any functions not mentioned below or in the rest of this section
                //       (Calculating With Complex Numbers) ignore the imaginary stack."  Percent seems to fall in this
                //       category, although (a + bi) ENTER (c + di) % gives a complex number answer.  I just use the
                //       real portion of the x value (c + 0i).
                let operandB = popOperand()
                let operandA = popOperand()
                if let baseNumber = operandA as? Complex, let complexB = operandB as? Complex {
                    let percent = complexB.real * 0.01
                    result = Complex(real: percent * baseNumber.real, imag: 0)  // %
                    secondResult = baseNumber
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "1/x":
                // 𝝙% (delta %)
                let operandB = popOperand()
                let operandA = popOperand()
                if let baseNumber = operandA as? Complex, let complexB = operandB as? Complex {
                    let secondNumber = complexB.real
                    result = Complex(real: (secondNumber - baseNumber.real) / baseNumber.real * 100, imag: 0)
                    secondResult = baseNumber
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "CHS":
                // ABS (absolute value)
                let operand = popOperand()
                if let term = operand as? Complex {
                    result = Complex(real: term.mag, imag: 0)
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "1":
                // →P - convert rectangular coordinates to polar
                isConvertingPolar = true
                let operandB = popOperand()
                if let complexB = operandB as? Complex {
                    if isComplexMode {
                        // rectangular coordinates (x and y) come from real and imaginary parts of complex number in X registers
                        let rectangular = complexB
                        let x = rectangular.real
                        let y = rectangular.imag
                        result = Complex(real: rectangular.mag,  // radians
                                         imag: atan2(y, x) / angleConversion)  // angle
                    } else {
                        let operandA = popOperand()
                        if let complexA = operandA as? Complex {
                            let x = complexB.real
                            let y = complexA.real
                            result = Complex(real: sqrt(x * x + y * y), imag: 0)  // radians
                            secondResult = Complex(real: atan2(y, x) / angleConversion, imag: 0)  // angle
                        } else {
                            realStack = saveStack  // restore stack to pre-error state
                            error = .code(1)
                            return
                        }
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "2":
                // →H convert hours-minutes-seconds-decimal seconds (H.MMSSsssss) to decimal hour
                let operand = popOperand()
                if let term = operand as? Complex {
                    let hoursMinuteSeconds = term.real  // ex. hoursMinutesSeconds = 1.1404200
                    let hours = Int(hoursMinuteSeconds)  // ex. hours = 1
                    let decimal = Int(round((hoursMinuteSeconds - Double(hours)) * 10000000))  // ex. decimal = 1404200
                    let minutes = Int(decimal / 100000)  // ex. minutes = 14
                    let seconds = Double(decimal - minutes * 100000) / 1000  // ex. seconds = 4.2
                    result = Complex(real: Double(hours) + Double(minutes) / 60 + Double(seconds) / 3600, imag: term.imag)
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "3":
                // →DEG - convert to degrees
                let operand = popOperand()
                if let term = operand as? Complex {
                    result = Complex(real: term.real / Constants.D2R, imag: term.imag)  // only applies to the real portion
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "+":
                // Cy,x - combinations = y! / x!(y - x)!
                let operandX = popOperand()
                let operandY = popOperand()
                if let complexX = operandX as? Complex, let complexY = operandY as? Complex {
                    if floor(complexY.real) == complexY.real && floor(complexX.real) == complexX.real {
                        // complexX.real and complexY.real are whole numbers
                        result = Complex(real: floor(complexY.factorial.real / (complexX.factorial.real * (complexY - complexX).factorial.real)),
                                         imag: complexY.imag)
                    } else {
                        // can't compute combinations of decimals
                        realStack = saveStack  // restore stack to pre-error state
                        error = .code(0)
                        return
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(11)
                    return
                }
            default:
                break
            }
        case "H":  // hyperbolic trig functions
            // Note: Owner's Handbook p.26 says "The trigonometric functions operate in the trigonometric mode you select",
            //       but this does not appear to be true for the hyperbolic trig functions.  They all operate in radians
            //       for real and complex numbers.
            switch operation {
            case "SIN":
                // HYP SIN
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex.sinhyp
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "COS":
                // HYP COS
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex.coshyp
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "TAN":
                // HYP TAN
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex.tanhyp
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            default:
                break
            }
        case "h":  // inverse hyperbolic trig functions
            // See note above.  Inverse hyperbolic trig functions are all in radians.
            switch operation {
            case "SIN":
                // HYP-1 SIN
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex.arcsinh
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "COS":
                // HYP-1 COS
                let operand = popOperand()
                if let complex = operand as? Complex {
                    if isComplexMode {
                        // both methods give same real answer for operands > 1, but .arccosh does not return
                        // NaN, if operand < 1 (it return a valid complex number); must use acosh() to get NaN.
                        result = complex.arccosh
                    } else {
                        result = Complex(real: acosh(complex.real), imag: 0)
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            case "TAN":
                // HYP-1 TAN
                let operand = popOperand()
                if let complex = operand as? Complex {
                    if isComplexMode {
                        // both methods give same real answer for abs(operands) < 1, but .arctanh does not return
                        // NaN, if abs(operand) > 1 (it return a valid complex number); must use atanh() to get NaN.
                        result = complex.arctanh
                    } else {
                        result = Complex(real: atanh(complex.real), imag: 0)
                    }
                } else {  // operand is Matrix
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(1)
                    return
                }
            default:
                result = Complex(real: 0, imag: 0)
            }
        case "M":  // Matrix function
            switch operation {
            case "4":
                // MATRIX 4 - transpose
                let operand = popOperand()
                if let matrix = operand as? Matrix {
                    result = matrix.transpose
                    overwriteMatrix = matrix.name  // overwrite original matrix
                } else {  // operand is Complex
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(11)
                    return
                }
            case "5":
                // MATRIX 6 - matrixY_transpose * matrixX
                let operandB = popOperand()
                let operandA = popOperand()
                if let matrixA = operandA as? Matrix, let matrixB = operandB as? Matrix,
                   resultMatrixName != matrixA.name, resultMatrixName != matrixB.name {  // can't store result in operand matrices
                    result = matrixA.transpose * matrixB
                } else {
                    realStack = saveStack  // restore stack to pre-error state
                    error = .code(11)
                    return
                }
            case "6":
                // MATRIX 6 - residual
                print("TBD - residual")  // description on p.159 of Handbook not clear what it does
            case "7":
                // MATRIX 7 - row norm
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex
                } else if let matrix = operand as? Matrix {
                    result = Complex(real: matrix.rowNorm, imag: 0)
                }
            case "8":
                // MATRIX 8 - Euclidean norm
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex
                } else if let matrix = operand as? Matrix {
                    result = Complex(real: matrix.euclideanNorm, imag: 0)
                }
            case "9":
                print("pws TBD: also need to store LU decomposition in RESULT matrix")
                // MATRIX 9 - determinant
                let operand = popOperand()
                if let complex = operand as? Complex {
                    result = complex
                } else if let matrix = operand as? Matrix {
                    if let determinant = matrix.determinant {
                        result = Complex(real: determinant, imag: 0)
                    } else {
                        realStack = saveStack  // restore stack to pre-error state
                        error = .code(11)
                        return
                    }
                }
            default:
                break
            }
        default:
            result = Complex(real: 0, imag: 0)
        }
        
        if let complex = result as? Complex {
            if complex.real.isNaN || complex.imag.isNaN || complex.real.isInfinite || complex.imag.isInfinite {  // ex. sqrt(-1) = NaN, 1/0 = +Inf, -1/0 = -Inf
                realStack = saveStack  // restore stack to pre-error state
                error = .code(0)  // reset in CalculatorViewController.restoreFromError
            } else if complex.mag > Constants.maxValue {
                realStack = saveStack  // restore stack to pre-error state
                error = complex.real > 0 ? .overflow : .underflow  // pws: underflow should be a number less than 1E-99 (not neg overflow)
            } else {
                if secondResult != nil {
                    pushOperand(secondResult as! Complex)
                }
                pushOperand(complex)
            }
            printMemory()
        } else if result == nil {
            realStack = saveStack  // restore stack to pre-error state
            error = .code(11)
        } else if let matrix = result as? Matrix {
            // TBD: handle error cases with matrix operations
            if let matrixName = overwriteMatrix {
                matrix.name = matrixName
            } else {
                matrix.name = resultMatrixName
            }
            matrices[matrix.name] = matrix
            if secondResult != nil {
                pushOperand(secondResult as! Matrix)
            }
            pushOperand(matrix)
            print(matrix)
        }
    }
    
    // MARK: - Statistics
    
    func statisticsAddRemovePoint(isAdd: Bool) {
        if let x = xRegister as? Double,
           let y = yRegister as? Double,
           let n = storageRegisters["2"] as? Double,
           let sumX = storageRegisters["3"] as? Double,
           let sumX2 = storageRegisters["4"] as? Double,
           let sumY = storageRegisters["5"] as? Double,
           let sumY2 = storageRegisters["6"] as? Double,
           let sumXY = storageRegisters["7"] as? Double
        {
            if isAdd {
                storageRegisters["2"] = n + 1
                storageRegisters["3"] = sumX + x
                storageRegisters["4"] = sumX2 + x * x
                storageRegisters["5"] = sumY + y
                storageRegisters["6"] = sumY2 + y * y
                storageRegisters["7"] = sumXY + x * y
            } else {
                storageRegisters["2"] = n - 1
                storageRegisters["3"] = sumX - x
                storageRegisters["4"] = sumX2 - x * x
                storageRegisters["5"] = sumY - y
                storageRegisters["6"] = sumY2 - y * y
                storageRegisters["7"] = sumXY - x * y
            }
            lastXRegister = x
            xRegister = storageRegisters["2"]  // leave number of data points in X register to be displayed
        } else {
            // matrix stored in X or Y register, or one of the statistics registers
            error = .code(1)
        }
    }
    
    func statisticsMean() {
        if let n = storageRegisters["2"] as? Double,
           let sumX = storageRegisters["3"] as? Double,
           let sumY = storageRegisters["5"] as? Double
        {
            if n == 0 {
                error = .code(2)
            } else {
                pushOperand(sumY / n)
                pushOperand(sumX / n)
            }
        } else {
            // matrix stored in one of the statistics register
            error = .code(1)
        }
    }
    
    func statisticsStandardDeviation() {
        if let n = storageRegisters["2"] as? Double,
           let sumX = storageRegisters["3"] as? Double,
           let sumX2 = storageRegisters["4"] as? Double,
           let sumY = storageRegisters["5"] as? Double,
           let sumY2 = storageRegisters["6"] as? Double
        {
            if n <= 1 {
                error = .code(2)
            } else {
                let M = n * sumX2 - sumX * sumX
                let N = n * sumY2 - sumY * sumY
                let den = n * (n - 1)
                pushOperand(sqrt(N / den))
                pushOperand(sqrt(M / den))
            }
        } else {
            // matrix stored in one of the statistics register
            error = .code(1)
        }
    }
    
    func statisticsFitLine() {
        if let n = storageRegisters["2"] as? Double,
           let sumX = storageRegisters["3"] as? Double,
           let sumX2 = storageRegisters["4"] as? Double,
           let sumY = storageRegisters["5"] as? Double,
           let sumY2 = storageRegisters["6"] as? Double,
            let sumXY = storageRegisters["7"] as? Double
        {
            if n <= 1 {
                error = .code(2)
            } else {
                let P = n * sumXY - sumX * sumY
                let M = n * sumX2 - sumX * sumX
                let N = n * sumY2 - sumY * sumY
                let den = n * (n - 1)
                pushOperand(P / M)  // slope
                pushOperand((M * sumY - P * sumX) / n / M)  // y-intercept
            }
        } else {
            // matrix stored in one of the statistics register
            error = .code(1)
        }
    }

    // MARK: -

    func printMemory() {
        guard !isSolving else { return }
        // print memory registers
        print("          Real         Imag")
        let labels = ["T", "Z", "Y", "X"]
        for index in 0..<realStack.count {
            if let number = realStack[index] as? Double {
                let realString = String(format: "% 8f", number).padding(toLength: 11, withPad: " ", startingAt: 0)
                print(String(format: "   %@:  %@  % 8f", labels[index], realString, imagStack[index]))
            } else if let matrix = realStack[index] as? Matrix {
                print(String(format: "   %@:      %@", labels[index], matrix.name))
            }
        }
        // print Last X
        if let number = lastXRegister as? Double {
            print(String(format: "LSTx:  % 8f", number))
        } else if let matrix = lastXRegister as? Matrix {
            print(String(format: "LSTx:      %@", matrix.name))
        }
        // print storage register 0-4 and .0-.4
        print("Reg", terminator: "")
        var dot = ""
        for _ in 0..<2 {
            for index in 0..<5 {
                let registerName = "\(dot)\(index)"
                let space = dot == "." ? "" : " "
                if let number = storageRegisters[registerName]! as? Double {
                    print(String(format: " %@%@: %8f ", space, registerName, number), terminator: "")
                } else if let matrix = storageRegisters[registerName]! as? Matrix {
                    print(String(format: " %@%@:    %@ ", space, registerName, matrix.name), terminator: "")
                }
            }
            print("\n   ", terminator: "")
            dot = "."
        }
        // print storage register I
        if let number = storageRegisters["I"]! as? Double {
            print(String(format: "  I: %8f", number))
        } else if let matrix = storageRegisters["I"]! as? Matrix {
            print(String(format: "  I:    %@", matrix.name))
        }
        print("---------------------------------------------------------")
    }
}
