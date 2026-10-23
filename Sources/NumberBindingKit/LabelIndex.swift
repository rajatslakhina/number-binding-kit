/// The content words around each figure, kept inside the figure's clause, so `churn` labels `4.3%` in
/// "churn was 4.3%, revenue 1,265" and `revenue` labels only `1,265`.
///
/// A label is what lets the binder call a near miss a contradiction: an answer's `6.7%` labelled
/// `conversion` against a source's `5.7%` labelled `conversion` is the same quantity written wrong.
struct LabelIndex {
    struct Word {
        let text: String
        let start: Int
        let end: Int
        let clause: Int
    }

    static let stopwords: Set<String> = [
        "the", "and", "for", "was", "were", "with", "that", "this", "these", "those", "from", "are", "has",
        "have", "had", "its", "his", "her", "our", "their", "your", "you", "they", "them", "which", "what",
        "when", "where", "who", "will", "would", "could", "should", "can", "into", "onto", "out", "than",
        "then", "there", "here", "also", "just", "only", "very", "but", "not", "all", "any", "each", "per",
        "about", "around", "approximately", "approx", "roughly", "nearly", "almost", "some", "over", "under",
        "above", "below", "more", "less", "least", "most", "fewer", "greater", "upwards", "within", "exceeding",
        "beyond", "circa", "estimated", "close", "is", "be", "been", "being", "did", "does", "got", "gets"
    ]

    let chars: [Character]
    let words: [Word]
    let clauses: [Int]

    init(_ chars: [Character]) {
        self.chars = chars
        var clauses: [Int] = []
        var current = 0
        for index in chars.indices {
            clauses.append(current)
            if Self.endsClause(chars, at: index) { current += 1 }
        }
        var words: [Word] = []
        var index = 0
        while index < chars.count {
            guard chars[index].isLetter else {
                index += 1
                continue
            }
            var end = index
            while end < chars.count, chars[end].isLetter { end += 1 }
            let text = String(chars[index..<end]).lowercased()
            if Self.isContent(text) {
                words.append(Word(text: text, start: index, end: end, clause: clauses[index]))
            }
            index = end
        }
        self.words = words
        self.clauses = clauses
    }

    static func isContent(_ word: String) -> Bool {
        word.count >= 3 && !stopwords.contains(word) && !Units.vocabulary.contains(word)
    }

    /// A sentence end, a semicolon, a line break, a brace, or a comma that is not grouping digits.
    static func endsClause(_ chars: [Character], at index: Int) -> Bool {
        let current = chars[index]
        let next = index + 1 < chars.count ? chars[index + 1] : nil
        switch current {
        case "!", "?", ";", "\n", "{", "}":
            return true
        case ".":
            return next.map { $0.isWhitespace || $0 == "\"" } ?? true
        case ",":
            let previous = index > 0 ? chars[index - 1] : nil
            return !(previous?.isDigit == true && next?.isDigit == true)
        default:
            return false
        }
    }

    /// Up to six content words before the figure and three after it, all in the figure's clause and
    /// none past a neighbouring figure: in "1,200 users and 1,400 seats", `seats` is not about 1,200.
    /// The word directly after the previous figure is that figure's noun, so `users` is not about 1,400.
    func label(start: Int, end: Int, after previous: Int? = nil, before upper: Int = .max) -> Set<String> {
        let lower = previous ?? 0
        let owned = previous.flatMap(nounStart)
        let before = words.filter {
            $0.end <= start && $0.start >= lower && $0.start != owned && $0.clause == clauses[start]
        }.suffix(6)
        let after = words.filter { $0.start >= end && $0.end <= upper && $0.clause == clauses[end - 1] }.prefix(3)
        return Set((before + after).map(\.text))
    }

    /// Where the word right after a figure starts, if one follows it after spaces.
    func nounStart(after end: Int) -> Int? {
        var index = end
        while index < chars.count, chars[index] == " " { index += 1 }
        return index > end && index < chars.count && chars[index].isLetter ? index : nil
    }
}
