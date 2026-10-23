/// Reading one number and everything written around it.
extension FigureScanner {
    struct GroupedInteger {
        let digits: String
        let end: Int
        let grouped: Bool
    }

    /// Words that make the number after them part of a name: `iOS 17`, `step 2`, `Swift 6`.
    static let identifierMarkers: Set<String> = [
        "ios", "ipados", "macos", "watchos", "tvos", "visionos", "swift", "xcode", "version", "ver",
        "gpt", "claude", "gemini", "llama", "step", "chapter", "section", "page", "item", "apollo",
        "figure", "fig", "table", "option", "line", "room", "rule", "issue", "article", "part", "phase",
        "level", "stage", "iphone", "ipad", "android", "windows", "python", "java", "port", "row",
        "column", "slide", "question", "task", "ticket", "appendix", "footnote", "build", "release",
        "sprint", "episode", "season", "volume", "vol"
    ]

    static let ordinalSuffixes: Set<String> = ["st", "nd", "rd", "th"]

    func number(at start: Int) -> RawFigure {
        var figure = mantissa(at: start)
        guard figure.role == .quantity else { return figure }
        readExponent(&figure)
        readPrefix(&figure)
        readSuffix(&figure)
        readFollowingWords(&figure)
        classifyYear(&figure)
        return figure
    }

    /// Digits with Western (`1,234,567`) or Indian (`12,34,567`) grouping, then decimals. A second
    /// decimal point (`1.2.3`) makes the whole run a version, not a number.
    func mantissa(at start: Int) -> RawFigure {
        let integer = groupedInteger(at: start)
        var figure = RawFigure(start: start, end: integer.end)
        figure.integerDigits = integer.digits
        figure.grouped = integer.grouped
        guard char(figure.end) == ".", char(figure.end + 1)?.isDigit == true else { return figure }
        let fractionEnd = digitRunEnd(from: figure.end + 1)
        figure.fraction = string(figure.end + 1, fractionEnd)
        figure.end = fractionEnd
        if char(fractionEnd) == ".", char(fractionEnd + 1)?.isDigit == true {
            figure.role = .identifier
            figure.end = endOfName(from: fractionEnd)
        }
        return figure
    }

    func groupedInteger(at start: Int) -> GroupedInteger {
        let firstEnd = digitRunEnd(from: start)
        var groups = [string(start, firstEnd)]
        var end = firstEnd
        while char(end) == ",", char(end + 1)?.isDigit == true {
            let groupEnd = digitRunEnd(from: end + 1)
            groups.append(string(end + 1, groupEnd))
            end = groupEnd
        }
        guard Self.isGrouping(groups) else { return GroupedInteger(digits: groups[0], end: firstEnd, grouped: false) }
        return GroupedInteger(digits: groups.joined(), end: end, grouped: true)
    }

    static func isGrouping(_ groups: [String]) -> Bool {
        let tail = groups.dropFirst().map(\.count)
        guard let last = tail.last else { return false }
        let head = groups[0].count
        let western = head <= 3 && tail.allSatisfy { $0 == 3 }
        let indian = head <= 2 && last == 3 && tail.count > 1 && tail.dropLast().allSatisfy { $0 == 2 }
        return western || indian
    }

    func readExponent(_ figure: inout RawFigure) {
        guard let marker = char(figure.end), marker == "e" || marker == "E" else { return }
        var index = figure.end + 1
        let sign = char(index)
        if sign == "+" || sign == "-" { index += 1 }
        let end = digitRunEnd(from: index)
        guard end > index, char(end)?.isLetter != true, let power = Int(string(index, end)) else { return }
        figure.exponent = sign == "-" ? -power : power
        figure.end = end
    }

    /// A currency symbol, a minus sign, an approximation or bound symbol, and qualifier or name words.
    func readPrefix(_ figure: inout RawFigure) {
        var index = figure.start - 1
        if let symbol = char(index), let currency = Units.currency(symbol) {
            figure.unit = currency
            figure.start = index
            index -= 1
        }
        if let sign = char(index), sign == "-" || sign == "−", char(index - 1).map(Self.opensValue) ?? true {
            figure.negative = true
            figure.start = index
            index -= 1
        }
        let symbolIndex = char(index) == " " ? index - 1 : index
        if let symbol = char(symbolIndex), let qualifier = Qualifier.symbols[symbol] {
            figure.qualifier = qualifier
            return
        }
        let words = precedingWords(before: figure.start)
        figure.qualifier = Qualifier(precedingWords: words)
        if let last = words.last, Self.identifierMarkers.contains(last) {
            figure.role = .identifier
        }
    }

    static func opensValue(_ character: Character) -> Bool {
        character.isWhitespace || "([{:=,\"'".contains(character)
    }

    /// Letters glued to the digits, a percent sign, or a temperature unit.
    func readSuffix(_ figure: inout RawFigure) {
        guard figure.role == .quantity else { return }
        let lettersEnd = letterRunEnd(from: figure.end)
        if lettersEnd > figure.end {
            applyGlued(string(figure.end, lettersEnd), to: &figure)
            figure.end = lettersEnd
        } else if char(figure.end) == "%" {
            figure.isPercent = true
            figure.end += 1
        } else if char(figure.end) == " ", char(figure.end + 1) == "%" {
            figure.isPercent = true
            figure.end += 2
        } else if char(figure.end) == "°", let letter = char(figure.end + 1), let unit = Units.temperature[letter] {
            figure.unit = unit
            figure.end += 2
        }
    }

    func applyGlued(_ suffix: String, to figure: inout RawFigure) {
        if Self.ordinalSuffixes.contains(suffix.lowercased()) {
            figure.role = .ordinal
        } else if suffix == "s", figure.isDecade {
            figure.role = .identifier
        } else if let scale = Self.gluedScale(suffix, afterCurrency: figure.unit != nil) {
            figure.scale = scale
        } else if let unit = Units.unit(named: suffix) {
            figure.unit = unit
        } else {
            figure.role = .identifier
        }
    }

    /// `5k`, `1.2M`, `$3bn`. Lower-case `m` and capital `B` mean million and billion only after a
    /// currency symbol; otherwise they are metres and bytes.
    static func gluedScale(_ suffix: String, afterCurrency: Bool) -> Scale? {
        if afterCurrency, let scale = currencyScales[suffix] { return scale }
        return gluedScales[suffix]
    }

    static let gluedScales: [String: Scale] = [
        "k": .thousand, "K": .thousand, "M": .million, "MM": .million, "mn": .million, "bn": .billion,
        "Bn": .billion, "T": .trillion, "tn": .trillion, "cr": .crore, "Cr": .crore
    ]

    static let currencyScales: [String: Scale] = ["m": .million, "B": .billion]

    /// A scale word (`million`), then `percent`, `per cent`, `percentage points` or a unit word.
    func readFollowingWords(_ figure: inout RawFigure) {
        guard figure.role == .quantity, !figure.isPercent else { return }
        if figure.scale == .unit, let word = word(after: figure.end), let scale = Scale.words[word.text.lowercased()] {
            figure.scale = scale
            figure.end = word.end
        }
        guard let word = word(after: figure.end) else { return }
        let text = word.text.lowercased()
        let next = self.word(after: word.end)
        let nextText = next?.text.lowercased() ?? ""
        if text == "percent" || text == "pct" {
            figure.isPercent = true
            figure.end = word.end
        } else if let next, (text == "per" && nextText == "cent") || (text == "percentage" && nextText == "points") {
            figure.isPercent = true
            figure.end = next.end
        } else if figure.unit == nil, word.text.count > 1, let unit = Units.unit(named: word.text) {
            figure.unit = unit
            figure.end = word.end
        }
    }

    func classifyYear(_ figure: inout RawFigure) {
        guard figure.role == .quantity, figure.isBareInteger, figure.integerDigits.count == 4,
              let year = Int(figure.integerDigits), (1_000...2_199).contains(year) else { return }
        figure.role = .year
    }
}
