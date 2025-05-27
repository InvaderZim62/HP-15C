//
//  Complex.swift
//  RPCalculator
//
//  Created by Phil Stern on 6/10/24.
//

import Foundation

struct Complex: Equatable, Stackable {
    var real: Double
    var imag: Double

    static let i = Complex(real: 0, imag: 1)

    // |(a + bi)| = sqrt(a² + b²)
    var mag: Double {
        sqrt(pow(real, 2) + pow(imag, 2))
    }

    // 1/(a + bi) = a/(a² + b²) - b/(a² + b²)i
    var inverse: Complex {
        let den = pow(real, 2) + pow(imag, 2)
        return Complex(real: real / den,
                       imag: -imag / den)
    }
    
    // (a + bi)² = a² - b² + 2abi
    var squared: Complex {
        Complex(real: pow(real, 2) - pow(imag, 2),
                imag: 2 * real * imag)
    }
    
    // sqrt(a + bi) = sqrt[(mag + a)/2] + sign(b) * sqrt[(mag - a)/2]i
    var squareRoot: Complex {
        Complex(real: sqrt((mag + real) / 2),
                imag: sqrt((mag - real) / 2) * (imag >= 0 ? 1 : -1))
    }
    
    // ln(a + bi) = ln(sqrt(a² + b²)) + atan2(b, a)i
    var naturalLog: Complex {
        Complex(real: log(mag),
                imag: atan2(imag, real))
    }
    
    // log10(a + bi) = ln(a + bi) / ln(10)
    var logBase10: Complex {
        self.naturalLog / log(10)
    }
    
    // e^(a + bi) = e^a * cos(b) + e^a * sin(b)i
    var exponential: Complex {
        Complex(real: exp(real) * cos(imag),
                imag: exp(real) * sin(imag))
    }
    
    // 10^(a + bi) = 10^a * cos(b*ln(10)) + 10^a * sin(b*ln(10))i
    var tenToThePowerOf: Complex {
        Complex(real: pow(10, real) * cos(imag * log(10)),
                imag: pow(10, real) * sin(imag * log(10)))
    }
    
    // factorial of decimal numbers (also integers) is the gamma function:
    // d! = gamma(d + 1) = integral(t^d * e^-t * dt) as t goes from 0 -> inf (ie. area under plot of t^d * e^-t)
    // since gamma goes to zero as t goes to inf (ie. e^t shrinks faster the t^d grows), quit when gamma falls below some epsilon
    // note: factorials < ~0.4 start to show larger differences with HP-15C
    var factorial: Complex {
        let dt = max(min(0.0001 * self.real, 0.01), 0.000001)  // smaller dt needed for smaller decimal factorials
        var integral = 0.0
        var i = 0
        var gamma = 0.0
        repeat {
            let t = Double(i) * dt
            gamma = pow(t, real) * exp(-t)
            integral += gamma * dt  // Euler integration for area under curve
            i += 1
            if i > 5000000 { break }
        } while i < 1000 || gamma > 1E-8  // at least 1000 iterations needed, since gamma starts small and grows, before shrinking again
        print("\n\(self.real) factorial = \(integral) (\(i) iterations), dt: \(dt)\n")
        return Complex(real: integral, imag: imag)
    }

    //----------------------------
    // trig functions
    //----------------------------
    
    // sin(a + bi) = sin(a)cosh(b) + cos(a)sinh(b)i
    var sine: Complex {
        Complex(real: sin(real) * cosh(imag),
                imag: cos(real) * sinh(imag))
    }
    
    // cos(a + bi) = cos(a)cosh(b) - sin(a)sinh(b)i
    var cosine: Complex {
        Complex(real: cos(real) * cosh(imag),
                imag: -sin(real) * sinh(imag))
    }
    
    // tan(a + bi) = [tan(a) - tan(a)tanh²(b)] / [1 + tan²(a)tanh²(b)] + [tanh(b) + tan²(a)tanh(b)] / [1 + tan²(a)tanh²(b)]i
    var tangent: Complex {
        let den = 1 + pow(tan(real), 2) * pow(tanh(imag), 2)
        return Complex(real: tan(real) * (1 - pow(tanh(imag), 2)) / den,
                       imag: tanh(imag) * (1 + pow(tan(real), 2)) / den)
    }
    
    // sinh(a + bi) = sinh(a)cos(b) + cosh(a)sin(b)i
    var sinhyp: Complex {
        Complex(real: sinh(real) * cos(imag),
                imag: cosh(real) * sin(imag))
    }
    
    // cosh(a + bi) = cosh(a)cos(b) + sinh(a)sin(b)i
    var coshyp: Complex {
        Complex(real: cosh(real) * cos(imag),
                imag: sinh(real) * sin(imag))
    }
    
    // tanh(a + bi) = [tanh(a) + tanh(a)tan²(b)] / [1 + tanh²(a)tan²(b)] + [tan(b) - tanh²(a)tan(b)] / [1 + tanh²(a)tan²(b)]i
    var tanhyp: Complex {
        let den = 1 + pow(tanh(real), 2) * pow(tan(imag), 2)
        return Complex(real: tanh(real) * (1 + pow(tan(imag), 2)) / den,
                       imag: tan(imag) * (1 - pow(tanh(real), 2)) / den)
    }
    
    //----------------------------
    // inverse trig functions
    //----------------------------

    // asin(z) = -i * ln{sqrt[1 - z²] + zi}
    var arcsin: Complex {
        -Complex.i * ((1 - squared).squareRoot + self * Complex.i).naturalLog
    }

    // acos(z) = -i * ln{sqrt[z² - 1] + z}
    var arccos: Complex {
        -Complex.i * ((squared - 1).squareRoot + self).naturalLog
    }
    
    // atan(z) = -i / 2 * ln{(i - z)/(i + z)}
    var arctan: Complex {
        -Complex.i / 2 * ((Complex.i - self) / (Complex.i + self)).naturalLog
    }

    // arcsinh(z) = ln(z + sqrt(z^2 + 1))
    var arcsinh: Complex {
        (self + (squared + 1).squareRoot).naturalLog
    }

    // arccosh(z) = ln(z + sqrt(z^2 - 1))
    var arccosh: Complex {
        (self + (squared - 1).squareRoot).naturalLog
    }

    // arctanh(z) = 1/2 * ln((1 + z)/(1 - z))
    var arctanh: Complex {
        0.5 * ((1 + self) / (1 - self)).naturalLog
    }

    //----------------------------
    // math functions
    //----------------------------

    // (a + bi) - (c + di) = (a - c) + (b - d)i
    static func +(lhs: Complex, rhs: Complex) -> Complex {
        Complex(real: lhs.real + rhs.real,
                imag: lhs.imag + rhs.imag)
    }

    // (a + bi) - (c + di) = (a - c) + (b - d)i
    static func -(lhs: Complex, rhs: Complex) -> Complex {
        Complex(real: lhs.real - rhs.real,
                imag: lhs.imag - rhs.imag)
    }

    // (a + bi) x (c + di) = (ac - bd) + (ad + bc)i
    static func *(lhs: Complex, rhs: Complex) -> Complex {
        Complex(real: lhs.real * rhs.real - lhs.imag * rhs.imag,
                imag: lhs.real * rhs.imag + lhs.imag * rhs.real)
    }

    // (a + bi) / (c + di) = (ac + bd)/(c² + d²) + (bc - ad)/(c² + d²)i
    static func /(lhs: Complex, rhs: Complex) -> Complex {
        let den = pow(rhs.real, 2) + pow(rhs.imag, 2)
        return Complex(real: (lhs.real * rhs.real + lhs.imag * rhs.imag) / den,
                       imag: (lhs.imag * rhs.real - lhs.real * rhs.imag) / den)
    }
    
    // (a + bi)^(c + di) = e^((c + di) * ln(a + bi))
    static func ^(lhs: Complex, rhs: Complex) -> Complex {
        (rhs * lhs.naturalLog).exponential
    }
    
    //----------------------------
    // unary operator
    //----------------------------

    // -(a + bi) = -a - bi
    static prefix func -(rhs: Complex) -> Complex {
        Complex(real: -rhs.real,
                imag: -rhs.imag)
    }
    
    //----------------------------
    // complex combined with real
    //----------------------------
    
    static func +(lhs: Double, rhs: Complex) -> Complex {
        Complex(real: lhs + rhs.real, imag: rhs.imag)
    }
    
    static func +(lhs: Complex, rhs: Double) -> Complex {
        Complex(real: lhs.real + rhs, imag: lhs.imag)
    }

    static func -(lhs: Double, rhs: Complex) -> Complex {
        Complex(real: lhs - rhs.real, imag: -rhs.imag)
    }
    
    static func -(lhs: Complex, rhs: Double) -> Complex {
        Complex(real: lhs.real - rhs, imag: lhs.imag)
    }

    static func *(lhs: Double, rhs: Complex) -> Complex {
        Complex(real: lhs * rhs.real, imag: lhs * rhs.imag)
    }

    static func *(lhs: Complex, rhs: Double) -> Complex {
        Complex(real: lhs.real * rhs, imag: lhs.imag * rhs)
    }

    static func /(lhs: Complex, rhs: Double) -> Complex {
        Complex(real: lhs.real / rhs, imag: lhs.imag / rhs)
    }

    static func /(lhs: Double, rhs: Complex) -> Complex {
        let den = pow(rhs.real, 2) + pow(rhs.imag, 2)
        return lhs * Complex(real: rhs.real / den, imag: -rhs.imag / den)
    }
}
