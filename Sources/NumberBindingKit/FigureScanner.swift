extension Character {
    var isDigit: Bool { isASCII && isNumber }
}

/// Walks a text once and returns every figure in it, in order.
///
/// Digits glued to a word or a path (`GPT-4o`, `v2`, `/2019/`, `#42`) are part of a name and are
/// skipped. Everything else becomes a figure: an ISO timestamp (its year, month, day and time), a time
/// of day, a citation or list marker, or a number with whatever is written around it.
struct FigureScanner {
    struct Token {
        let figures: [RawFigure]
        let end: Int
    }

    struct WordSpan {
        let text: String
        let end: Int
    }

    struct Meridiem {
        let isAfternoon: Bool
        let end: Int
    }

    let chars: [Character]

    init(_ text: String) {
        chars = Array(text)
    }

    func scan() -> [RawFigure] {
        var found: [RawFigure] = []
        var index = 0
        while index < chars.count {
            if !chars[index].isDigit {
                index += 1
            } else if gluedToName(index) {
                index = endOfName(from: index)
            } else {
                let token = token(at: index)
                found += token.figures
                index = token.end
            }
        }
        return found
    }

    func token(at index: Int) -> Token {
        if let date = isoTimestamp(at: index) { return date }
        if let time = clock(at: index) { return Token(figures: [time], end: time.end) }
        if let marker = marker(at: index) { return Token(figures: [marker], end: marker.end) }
        let figure = number(at: index)
        return Token(figures: [figure], end: figure.end)
    }

    // MARK: - Characters

    func char(_ index: Int) -> Character? {
        chars.indices.contains(index) ? chars[index] : nil
    }

    func string(_ start: Int, _ end: Int) -> String {
        String(chars[start..<end])
    }

    func digitRunEnd(from start: Int) -> Int {
        var end = start
        while char(end)?.isDigit == true { end += 1 }
        return end
    }

    func letterRunEnd(from start: Int) -> Int {
        var end = start
        while char(end)?.isLetter == true { end += 1 }
        return end
    }

    func twoDigits(at start: Int) -> Int? {
        digitRunEnd(from: start) == start + 2 ? Int(string(start, start + 2)) : nil
    }

    func gluedToName(_ index: Int) -> Bool {
        guard let previous = char(index - 1) else { return false }
        if previous.isLetter || "_/#@.".contains(previous) { return true }
        return previous == "-" && char(index - 2)?.isLetter == true
    }

    /// The end of a name that has digits in it: `GPT-4o`, `v1.2.3-beta`, `/2019/`.
    func endOfName(from start: Int) -> Int {
        var end = start
        while let current = char(end) {
            let joins = "._-".contains(current) && (char(end + 1).map { $0.isLetter || $0.isDigit } ?? false)
            guard current.isLetter || current.isDigit || joins else { break }
            end += 1
        }
        return end
    }

    func word(after start: Int) -> WordSpan? {
        var index = start
        while char(index) == " " { index += 1 }
        let end = letterRunEnd(from: index)
        guard index > start, end > index else { return nil }
        return WordSpan(text: string(index, end), end: end)
    }

    /// Up to three words directly before `index`, separated from it and from each other by spaces only.
    func precedingWords(before index: Int, limit: Int = 3) -> [String] {
        var words: [String] = []
        var cursor = index
        while words.count < limit {
            var end = cursor
            while char(end - 1) == " " { end -= 1 }
            var start = end
            while char(start - 1)?.isLetter == true { start -= 1 }
            guard end < cursor, start < end else { break }
            words.insert(string(start, end).lowercased(), at: 0)
            cursor = start
        }
        return words
    }

    // MARK: - Dates, times and markers

    /// `2026-10-23`, optionally followed by `T14:30:05.123+05:30`.
    func isoTimestamp(at start: Int) -> Token? {
        guard digitRunEnd(from: start) == start + 4, char(start + 4) == "-",
              digitRunEnd(from: start + 5) == start + 7, char(start + 7) == "-",
              digitRunEnd(from: start + 8) == start + 10 else { return nil }
        var figures = [
            part(start, start + 4, role: .year),
            part(start + 5, start + 7, role: .quantity),
            part(start + 8, start + 10, role: .quantity)
        ]
        var end = start + 10
        if let separator = char(end), separator == "T" || separator == " ",
           let time = clock(at: end + 1, allowsMeridiem: false) {
            figures.append(time)
            end = zoneEnd(after: time.end)
        }
        return Token(figures: figures, end: end)
    }

    func part(_ start: Int, _ end: Int, role: FigureRole) -> RawFigure {
        var figure = RawFigure(start: start, end: end)
        figure.integerDigits = string(start, end)
        figure.role = role
        return figure
    }

    func zoneEnd(after start: Int) -> Int {
        var end = start
        if char(end) == ".", char(end + 1)?.isDigit == true { end = digitRunEnd(from: end + 1) }
        if char(end) == "Z" { return end + 1 }
        guard let sign = char(end), sign == "+" || sign == "-" else { return end }
        let hours = digitRunEnd(from: end + 1)
        if hours == end + 5 { return hours }
        guard hours == end + 3, char(hours) == ":" else { return end }
        let minutes = digitRunEnd(from: hours + 1)
        return minutes == hours + 3 ? minutes : end
    }

    /// `14:30`, `14:30:05`, `2:30 PM`, `9 a.m.`. A bare hour needs the meridiem to count.
    func clock(at start: Int, allowsMeridiem: Bool = true) -> RawFigure? {
        let hourEnd = digitRunEnd(from: start)
        guard hourEnd - start <= 2, let hour = Int(string(start, hourEnd)) else { return nil }
        var end = hourEnd
        var minute = 0
        var second = 0
        var step = 3_600.0
        if char(end) == ":", let value = twoDigits(at: end + 1) {
            (minute, step, end) = (value, 60, end + 3)
            if char(end) == ":", let value = twoDigits(at: end + 1) { (second, step, end) = (value, 1, end + 3) }
        }
        var hour24 = hour
        if allowsMeridiem, let meridiem = meridiem(after: end) {
            guard (1...12).contains(hour) else { return nil }
            hour24 = hour % 12 + (meridiem.isAfternoon ? 12 : 0)
            end = meridiem.end
        } else if step == 3_600 {
            return nil
        }
        guard hour24 < 24, minute < 60, second < 60 else { return nil }
        var figure = part(start, end, role: .clock)
        figure.integerDigits = string(start, hourEnd)
        figure.fixedValue = Double(hour24 * 3_600 + minute * 60 + second)
        figure.fixedStep = step
        return figure
    }

    func meridiem(after start: Int) -> Meridiem? {
        var index = char(start) == " " ? start + 1 : start
        guard let first = char(index)?.lowercased(), first == "a" || first == "p" else { return nil }
        index += char(index + 1) == "." ? 2 : 1
        guard char(index)?.lowercased() == "m" else { return nil }
        index += char(index + 1) == "." ? 2 : 1
        guard char(index)?.isLetter != true else { return nil }
        return Meridiem(isAfternoon: first == "p", end: index)
    }

    /// `[3]` is a citation; `1.` or `2)` at the start of a line is a list marker.
    func marker(at start: Int) -> RawFigure? {
        let end = digitRunEnd(from: start)
        if char(start - 1) == "[", char(end) == "]" {
            return part(start, end, role: .citation)
        }
        guard atLineStart(start), let next = char(end), next == "." || next == ")",
              char(end + 1)?.isWhitespace ?? true else { return nil }
        var figure = part(start, end + 1, role: .listMarker)
        figure.integerDigits = string(start, end)
        return figure
    }

    func atLineStart(_ index: Int) -> Bool {
        var cursor = index - 1
        while char(cursor) == " " || char(cursor) == "\t" { cursor -= 1 }
        return cursor < 0 || chars[cursor] == "\n"
    }
}
