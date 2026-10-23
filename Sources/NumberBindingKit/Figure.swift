/// A number stated in text, read with everything that decides what it may be matched against: the
/// precision it was written to, its scale word, whether it is a percentage, its unit, and any word
/// that loosens or bounds it.
public struct Figure: Sendable, Hashable {
    /// Exactly as written, including a currency symbol, scale word or unit: `$1.2 million`, `5.7%`.
    public let text: String
    /// The value with its scale applied: `1.2 million` is `1_200_000`. A percentage keeps the number
    /// as written (`5.7`), and a time of day is seconds since midnight.
    public let value: Double
    /// The place value of the last digit written, scaled the same way: `1.2 million` has a step of
    /// `100_000`, `5.7%` has `0.1`, `14:30` has `60`. Rounding is judged against half of it.
    public let step: Double
    /// Significant digits as written. `0.057` has 2, `351` has 3; trailing zeros of an integer count.
    public let significantDigits: Int
    /// Trailing zeros of an integer written without a decimal point: `1,200` has 2.
    public let trailingZeros: Int
    public let isPercent: Bool
    public let unit: MeasureUnit?
    public let scale: Scale
    public let qualifier: Qualifier?
    public let role: FigureRole
    /// Character offset of `text` in the string it was read from.
    public let offset: Int
    /// Content words near the figure in the same clause: what the number is a number *of*.
    public let label: Set<String>

    /// True when the figure was written without a decimal point, exponent or scale word.
    public var isPlainInteger: Bool {
        step == 1 && scale == .unit && !isPercent && role == .quantity && value == value.rounded()
    }
}

/// A scale word or suffix: `k`, `million`, `bn`, `lakh`, `crore`.
public enum Scale: String, Sendable, Hashable, CaseIterable {
    case unit, thousand, lakh, million, crore, billion, trillion

    public var multiplier: Double {
        switch self {
        case .unit: 1
        case .thousand: 1_000
        case .lakh: 100_000
        case .million: 1_000_000
        case .crore: 10_000_000
        case .billion: 1_000_000_000
        case .trillion: 1_000_000_000_000
        }
    }

    static let words: [String: Scale] = [
        "thousand": .thousand, "thousands": .thousand,
        "lakh": .lakh, "lakhs": .lakh, "lac": .lakh,
        "million": .million, "millions": .million, "mn": .million,
        "crore": .crore, "crores": .crore,
        "billion": .billion, "billions": .billion, "bn": .billion,
        "trillion": .trillion, "trillions": .trillion, "tn": .trillion
    ]
}

/// A word in front of a number that changes what counts as a match for it.
public enum Qualifier: String, Sendable, Hashable {
    /// "about", "roughly", "~": the source may differ by the policy's tolerance.
    case approximately
    /// "over", "more than", "at least": the source must be at or above the figure.
    case atLeast
    /// "under", "less than", "up to": the source must be at or below the figure.
    case atMost

    static let phrases: [String: Qualifier] = [
        "about": .approximately, "around": .approximately, "approximately": .approximately,
        "approx": .approximately, "roughly": .approximately, "nearly": .approximately,
        "almost": .approximately, "some": .approximately, "circa": .approximately,
        "estimated": .approximately, "close to": .approximately, "in the region of": .approximately,
        "over": .atLeast, "above": .atLeast, "exceeding": .atLeast, "beyond": .atLeast,
        "more than": .atLeast, "greater than": .atLeast, "at least": .atLeast, "upwards of": .atLeast,
        "no less than": .atLeast, "no fewer than": .atLeast, "in excess of": .atLeast,
        "under": .atMost, "below": .atMost, "within": .atMost, "less than": .atMost,
        "fewer than": .atMost, "at most": .atMost, "up to": .atMost, "no more than": .atMost
    ]

    static let symbols: [Character: Qualifier] = [
        "~": .approximately, "≈": .approximately, ">": .atLeast, "≥": .atLeast, "<": .atMost, "≤": .atMost
    ]

    /// The qualifier the last one, two or three words make, longest phrase first.
    init?(precedingWords words: [String]) {
        for length in stride(from: min(3, words.count), through: 1, by: -1) {
            if let found = Self.phrases[words.suffix(length).joined(separator: " ")] {
                self = found
                return
            }
        }
        return nil
    }
}

/// What kind of thing a number in text is. Only quantities, years and times of day are claims about
/// the world; the others name or number something and are exempt by default.
public enum FigureRole: String, Sendable, Hashable, CaseIterable {
    case quantity
    /// Four digits from 1000 to 2199 with nothing attached.
    case year
    /// A time of day, `14:30` or `2:30 PM`.
    case clock
    /// `1st`, `22nd`.
    case ordinal
    /// `1.` or `2)` at the start of a line.
    case listMarker
    /// `[3]`.
    case citation
    /// Part of a name: `iOS 17`, `Swift 6`, `1.2.3`, `3D`, the `1990s`.
    case identifier
}

/// A unit, reduced to a family and a factor to that family's base unit so `1500 ms` can meet `1.5 s`.
public struct MeasureUnit: Sendable, Hashable {
    /// What converts into what: `time`, `data`, `length`, `mass`, or `currency:USD` (never converted).
    public let family: String
    public let symbol: String
    public let factor: Double

    public init(family: String, symbol: String, factor: Double = 1) {
        self.family = family
        self.symbol = symbol
        self.factor = factor
    }
}
