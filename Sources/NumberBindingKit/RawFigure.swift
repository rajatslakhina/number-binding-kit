import Foundation

/// A figure as the scanner found it, before its label is attached.
struct RawFigure {
    var start: Int
    var end: Int
    var integerDigits = ""
    var fraction = ""
    var exponent = 0
    var grouped = false
    var negative = false
    var isPercent = false
    var unit: MeasureUnit?
    var scale = Scale.unit
    var qualifier: Qualifier?
    var role = FigureRole.quantity
    /// Set for a time of day, whose digits are not one decimal number.
    var fixedValue: Double?
    var fixedStep: Double?

    init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    var value: Double {
        if let fixedValue { return fixedValue }
        let written = fraction.isEmpty ? integerDigits : integerDigits + "." + fraction
        let magnitude = (Double(written) ?? 0) * pow(10, Double(exponent)) * scale.multiplier
        return negative ? -magnitude : magnitude
    }

    var step: Double {
        fixedStep ?? pow(10, Double(exponent - fraction.count)) * scale.multiplier
    }

    var significantDigits: Int {
        max((integerDigits + fraction).drop { $0 == "0" }.count, 1)
    }

    var trailingZeros: Int {
        guard fraction.isEmpty, exponent == 0 else { return 0 }
        let zeros = integerDigits.reversed().prefix { $0 == "0" }.count
        return zeros == integerDigits.count ? 0 : zeros
    }

    /// Nothing attached: no decimals, grouping, exponent, sign, unit, percent or scale.
    var isBareInteger: Bool {
        fraction.isEmpty && !grouped && exponent == 0 && !negative && unit == nil && !isPercent && scale == .unit
    }

    /// `80s`, `1990s`: a decade, not eighty seconds.
    var isDecade: Bool {
        fraction.isEmpty && [2, 4].contains(integerDigits.count) && integerDigits.hasSuffix("0")
    }
}
