/// Running totals across a conversation.
public struct SessionTotals: Sendable, Hashable {
    public internal(set) var turns = 0
    public internal(set) var checked = 0
    public internal(set) var verified = 0
    public internal(set) var contradicted = 0
    /// Unbound or echoed.
    public internal(set) var unverified = 0

    public var verifiedFraction: Double? {
        checked == 0 ? nil : Double(verified) / Double(checked)
    }
}

/// Binds the answers of one conversation, and remembers them so a later answer that only repeats an
/// earlier number is reported as `echoed` rather than verified by its own history.
///
/// An actor because a conversation's answers arrive one at a time from whatever task finished the
/// turn, and the history it binds against must be the history before that answer, never during it.
public actor BindingSession {
    public nonisolated let binder: NumberBinder
    private var answers: [String] = []
    public private(set) var totals = SessionTotals()

    public init(binder: NumberBinder = NumberBinder()) {
        self.binder = binder
    }

    public func review(answer: String, evidence: [NumberSource]) -> NumberBindingReport {
        let earlier = answers.enumerated().map { NumberSource.earlierAnswer($0.element, index: $0.offset + 1) }
        let report = binder.bind(answer: answer, sources: evidence + earlier)
        answers.append(answer)
        totals.turns += 1
        totals.checked += report.checked.count
        totals.verified += report.verified.count
        totals.contradicted += report.contradicted.count
        totals.unverified += report.unbound.count + report.echoed.count
        return report
    }
}
