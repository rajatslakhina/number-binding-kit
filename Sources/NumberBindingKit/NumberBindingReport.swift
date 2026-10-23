/// The overall reading of one answer.
public enum BindingVerdict: String, Sendable, Hashable {
    /// No figure in the answer needed checking.
    case nothingToCheck
    /// Every checked figure is bound to evidence.
    case allBound
    /// Some figure is unbound or only echoes an earlier answer.
    case unverified
    /// Some figure disagrees with evidence about the same thing.
    case contradicted
}

/// A piece of the answer: plain text, or a figure with what became of it. A UI renders verified figures
/// as they are and marks the rest.
public enum AnswerSegment: Sendable, Hashable {
    case text(String)
    case figure(BoundFigure)
}

/// What the binder found in one answer.
public struct NumberBindingReport: Sendable, Hashable {
    public let answer: String
    public let figures: [BoundFigure]

    public var checked: [BoundFigure] { figures.filter { !$0.status.isExempt } }
    public var verified: [BoundFigure] { figures.filter(\.status.isVerified) }
    public var contradicted: [BoundFigure] { figures.filter { $0.status == .contradicted } }
    public var unbound: [BoundFigure] { figures.filter { $0.status == .unbound } }
    public var echoed: [BoundFigure] { figures.filter { $0.status == .echoed } }
    public var exempt: [BoundFigure] { figures.filter(\.status.isExempt) }

    public var verdict: BindingVerdict {
        if checked.isEmpty { return .nothingToCheck }
        if !contradicted.isEmpty { return .contradicted }
        return verified.count == checked.count ? .allBound : .unverified
    }

    public var needsAttention: Bool { verdict == .contradicted || verdict == .unverified }

    /// Verified over checked; nil when nothing was checked.
    public var boundFraction: Double? {
        checked.isEmpty ? nil : Double(verified.count) / Double(checked.count)
    }

    /// One short paragraph for the user, or nil when every checked number is bound.
    public var note: String? {
        guard needsAttention else { return nil }
        var parts = ["Checked \(Self.count(checked.count)) against what this turn returned."]
        if !contradicted.isEmpty {
            parts.append("Doesn't match: " + contradicted.map(Self.mismatch).joined(separator: "; ") + ".")
        }
        if !unbound.isEmpty {
            parts.append("Nothing this turn returned backs " + Self.list(unbound.map(\.figure.text)) + ".")
        }
        if !echoed.isEmpty {
            parts.append("Only repeats an earlier answer: " + Self.list(echoed.map(\.figure.text)) + ".")
        }
        return parts.joined(separator: " ")
    }

    /// One line for a trace.
    public var summary: String {
        var head = "\(verdict.rawValue): checked \(checked.count), bound \(verified.count)"
        let kinds = Dictionary(grouping: verified, by: \.status.name).map { "\($0.key) \($0.value.count)" }
        if !kinds.isEmpty { head += " [" + kinds.sorted().joined(separator: ", ") + "]" }
        var parts = [head]
        if !contradicted.isEmpty {
            parts.append("contradicted " + contradicted.map(Self.versus).joined(separator: ", "))
        }
        if !unbound.isEmpty { parts.append("unbound " + unbound.map(\.figure.text).joined(separator: ", ")) }
        if !echoed.isEmpty { parts.append("echoed " + echoed.map(\.figure.text).joined(separator: ", ")) }
        if !exempt.isEmpty { parts.append("exempt \(exempt.count)") }
        return parts.joined(separator: "; ")
    }

    public var segments: [AnswerSegment] {
        let chars = Array(answer)
        var segments: [AnswerSegment] = []
        var cursor = 0
        for bound in figures {
            let start = bound.figure.offset
            if start > cursor { segments.append(.text(String(chars[cursor..<start]))) }
            segments.append(.figure(bound))
            cursor = start + bound.figure.text.count
        }
        if cursor < chars.count { segments.append(.text(String(chars[cursor...]))) }
        return segments
    }

    /// The answer with `mark` after every figure that needs attention.
    public func annotated(mark: String = " [unverified]") -> String {
        segments.map { segment in
            switch segment {
            case let .text(text): text
            case let .figure(bound): bound.figure.text + (bound.status.isVerified || bound.status.isExempt ? "" : mark)
            }
        }.joined()
    }

    static func count(_ value: Int) -> String {
        value == 1 ? "1 number" : "\(value) numbers"
    }

    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.joined() }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }

    static func mismatch(_ bound: BoundFigure) -> String {
        bound.figure.text + bound.support.map { " (\($0.sourceLabel) says \($0.figure.text))" }.joined()
    }

    static func versus(_ bound: BoundFigure) -> String {
        bound.figure.text + bound.support.map { " vs " + $0.figure.text }.joined()
    }
}
