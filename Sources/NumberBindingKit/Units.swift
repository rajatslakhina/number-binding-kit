/// The units the reader recognises, by every spelling it accepts.
///
/// Lookups try the exact spelling first and then lower case, so `MB` and `mb` both read as megabytes,
/// while `B` (bytes) and `M` (million, handled as a scale) stay distinct. A spaced unit word must be
/// at least two letters: `5 m` is too ambiguous to read as metres.
enum Units {
    struct Row {
        let family: String
        let symbol: String
        let factor: Double
        let spellings: [String]

        init(_ family: String, _ symbol: String, _ factor: Double, _ spellings: [String]) {
            self.family = family
            self.symbol = symbol
            self.factor = factor
            self.spellings = spellings
        }
    }

    static let table: [String: MeasureUnit] = {
        var map: [String: MeasureUnit] = [:]
        let rows: [Row] = [
            Row("time", "ns", 1e-9, ["ns", "nanosecond", "nanoseconds"]),
            Row("time", "µs", 1e-6, ["µs", "us", "microsecond", "microseconds"]),
            Row("time", "ms", 1e-3, ["ms", "millisecond", "milliseconds"]),
            Row("time", "s", 1, ["s", "sec", "secs", "second", "seconds"]),
            Row("time", "min", 60, ["min", "mins", "minute", "minutes"]),
            Row("time", "h", 3_600, ["h", "hr", "hrs", "hour", "hours"]),
            Row("time", "day", 86_400, ["day", "days"]),
            Row("time", "week", 604_800, ["week", "weeks", "wk"]),
            Row("data", "B", 1, ["B", "byte", "bytes"]),
            Row("data", "KB", 1e3, ["KB", "kB", "kilobyte", "kilobytes"]),
            Row("data", "MB", 1e6, ["MB", "megabyte", "megabytes"]),
            Row("data", "GB", 1e9, ["GB", "gigabyte", "gigabytes"]),
            Row("data", "TB", 1e12, ["TB", "terabyte", "terabytes"]),
            Row("data", "KiB", 1_024, ["KiB"]),
            Row("data", "MiB", 1_048_576, ["MiB"]),
            Row("data", "GiB", 1_073_741_824, ["GiB"]),
            Row("length", "mm", 1e-3, ["mm", "millimetre", "millimetres", "millimeter", "millimeters"]),
            Row("length", "cm", 1e-2, ["cm", "centimetre", "centimetres", "centimeter", "centimeters"]),
            Row("length", "m", 1, ["m", "metre", "metres", "meter", "meters"]),
            Row("length", "km", 1e3, ["km", "kilometre", "kilometres", "kilometer", "kilometers"]),
            Row("length", "mi", 1_609.344, ["mi", "mile", "miles"]),
            Row("length", "ft", 0.3048, ["ft", "foot", "feet"]),
            Row("mass", "mg", 1e-6, ["mg", "milligram", "milligrams"]),
            Row("mass", "g", 1e-3, ["g", "gram", "grams"]),
            Row("mass", "kg", 1, ["kg", "kilogram", "kilograms", "kilo", "kilos"]),
            Row("mass", "lb", 0.45359237, ["lb", "lbs"]),
            Row("multiple", "x", 1, ["x", "X"]),
            Row("currency:USD", "USD", 1, ["USD", "usd", "dollar", "dollars"]),
            Row("currency:EUR", "EUR", 1, ["EUR", "eur", "euro", "euros"]),
            Row("currency:GBP", "GBP", 1, ["GBP", "gbp"]),
            Row("currency:INR", "INR", 1, ["INR", "inr", "rupee", "rupees", "Rs"])
        ]
        for row in rows {
            let unit = MeasureUnit(family: row.family, symbol: row.symbol, factor: row.factor)
            for spelling in row.spellings {
                map[spelling] = unit
            }
        }
        for row in rows {
            for spelling in row.spellings where map[spelling.lowercased()] == nil {
                map[spelling.lowercased()] = map[spelling]
            }
        }
        return map
    }()

    static let currencySymbols: [Character: String] = ["$": "USD", "€": "EUR", "£": "GBP", "₹": "INR"]

    static let temperature: [Character: MeasureUnit] = [
        "C": MeasureUnit(family: "celsius", symbol: "°C"),
        "F": MeasureUnit(family: "fahrenheit", symbol: "°F")
    ]

    /// Every spelling of every unit and scale, so labels can leave them out: "seconds" says nothing
    /// about what was measured.
    static let vocabulary: Set<String> = Set(table.keys.map { $0.lowercased() })
        .union(Scale.words.keys)
        .union(["percent", "pct", "per", "cent", "percentage", "points"])

    static func unit(named word: String) -> MeasureUnit? {
        table[word] ?? table[word.lowercased()]
    }

    static func currency(_ symbol: Character) -> MeasureUnit? {
        currencySymbols[symbol].flatMap { table[$0] }
    }
}
