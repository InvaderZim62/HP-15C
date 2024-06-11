//
//  Complex.swift
//  RPCalculator
//
//  Created by Phil Stern on 6/10/24.
//

import Foundation

struct Complex {
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
        Complex(real: lhs / rhs.real, imag: lhs / rhs.imag)
    }
}
