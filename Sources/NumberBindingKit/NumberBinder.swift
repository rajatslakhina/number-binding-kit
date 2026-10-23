/// Binds every figure in an answer to a figure the turn actually had, or says it could not.
///
/// The idea comes from *Proof-Carrying Numbers* (Solatorio, arXiv 2509.06902): a number is shown as
/// verified only after a mechanical check against structured claims under a declared policy, the
/// check runs outside the model, and the absence of a check means unverified. PCN asks the model to
/// emit claim-bound tokens. A chat client talking to arbitrary models gets plain prose, so this binder
/// reads the figures out of the prose itself and binds them to the figures in the turn's evidence:
/// tool outputs, retrieved documents, the user's message.
public struct NumberBinder: Sendable {
    struct Match {
        let relation: Relation
        let support: Support
    }

    public let policy: BindingPolicy
    let reader = FigureReader()

    public init(policy: BindingPolicy = .standard) {
        self.policy = policy
    }

    var matcher: Matcher { Matcher(policy: policy) }

    public func figures(in text: String) -> [Figure] {
        reader.figures(in: text)
    }

    public func bind(answer: String, sources: [NumberSource]) -> NumberBindingReport {
        let pool = EvidencePool(sources: sources, reader: reader, exempt: policy.exemptRoles)
        return NumberBindingReport(answer: answer, figures: figures(in: answer).map { classify($0, pool: pool) })
    }

    /// Exempt, then a direct match, a derivation, a contradiction, an echo, a small count, unbound.
    func classify(_ figure: Figure, pool: EvidencePool) -> BoundFigure {
        if policy.exemptRoles.contains(figure.role) {
            return BoundFigure(figure: figure, status: .exempt(.role(figure.role)), support: [])
        }
        if let match = bestMatch(for: figure, in: pool.evidence) {
            return BoundFigure(figure: figure, status: match.relation.status, support: [match.support])
        }
        if let derived = derivation(for: figure, operands: pool.operands) {
            return derived
        }
        if let rival = contradiction(for: figure, in: pool.evidence) {
            return BoundFigure(figure: figure, status: .contradicted, support: [rival])
        }
        if let echo = bestMatch(for: figure, in: pool.echoes) {
            return BoundFigure(figure: figure, status: .echoed, support: [echo.support])
        }
        let small = policy.smallCountLimit.map { figure.isPlainInteger && abs(figure.value) <= Double($0) } ?? false
        return BoundFigure(figure: figure, status: small ? .exempt(.smallCount) : .unbound, support: [])
    }

    func bestMatch(for figure: Figure, in candidates: [Support]) -> Match? {
        candidates.compactMap { candidate in
            matcher.relation(of: figure, to: candidate.figure).map { Match(relation: $0, support: candidate) }
        }.min { $0.relation < $1.relation }
    }

    func derivation(for figure: Figure, operands: [Support]) -> BoundFigure? {
        guard figure.role == .quantity, figure.significantDigits >= 2, operands.count >= 2,
              operands.count <= policy.maxDerivationOperands else { return nil }
        for derivation in Derivation.allCases where policy.derivations.contains(derivation) {
            for first in operands {
                for second in operands where second != first {
                    guard let raw = derivation.apply(first.figure, second.figure, answerIsPercent: figure.isPercent)
                    else { continue }
                    let target = derivation.isDirectional && figure.value >= 0 ? abs(raw) : raw
                    if matcher.closeness(of: figure, to: target, derived: true) != nil {
                        return BoundFigure(figure: figure, status: .derived(derivation), support: [first, second])
                    }
                }
            }
        }
        return nil
    }

    /// An evidence figure of the same kind that shares a label word: the same quantity, written wrong.
    /// Only when no such figure is within reach of the lenient policy: a figure a looser policy would
    /// accept ("over 1,200" of 1,234 under `.strict`) is unbound, not contradicted. The most shared
    /// words win, then the nearest value. A time of day needs no shared word: a turn rarely carries
    /// two clocks, and a tool's timestamp is labelled by its key, not by the city the answer names.
    func contradiction(for figure: Figure, in evidence: [Support]) -> Support? {
        let yardstick = Matcher(policy: .lenient)
        let rivals = evidence.filter {
            matcher.comparable(figure, $0.figure)
                && (figure.role == .clock || !$0.figure.label.isDisjoint(with: figure.label))
        }
        guard !rivals.contains(where: { yardstick.relation(of: figure, to: $0.figure) != nil }) else { return nil }
        return rivals.min { rank($0, against: figure) < rank($1, against: figure) }
    }

    func rank(_ support: Support, against figure: Figure) -> RivalRank {
        let shared = support.figure.label.intersection(figure.label).count
        let distance = abs(support.figure.value - figure.value) / max(abs(support.figure.value), 1)
        return RivalRank(shared: shared, distance: distance)
    }
}

/// Orders contradiction candidates: more shared label words first, then the closer value.
struct RivalRank: Comparable {
    let shared: Int
    let distance: Double

    static func < (lhs: RivalRank, rhs: RivalRank) -> Bool {
        lhs.shared != rhs.shared ? lhs.shared > rhs.shared : lhs.distance < rhs.distance
    }
}

/// The turn's evidence, read once: figures that can verify, figures that can only be echoed, and the
/// distinct quantities derivations may use.
struct EvidencePool {
    let evidence: [Support]
    let echoes: [Support]
    let operands: [Support]

    init(sources: [NumberSource], reader: FigureReader, exempt: Set<FigureRole>) {
        var evidence: [Support] = []
        var echoes: [Support] = []
        for source in sources {
            let supports = reader.figures(in: source.text).filter { !exempt.contains($0.role) }.map {
                Support(source, $0)
            }
            if source.kind == .assistant {
                echoes += supports
            } else {
                evidence += supports
            }
        }
        var seen: Set<Double> = []
        self.evidence = evidence
        self.echoes = echoes
        operands = evidence.filter { $0.figure.role == .quantity && seen.insert($0.figure.value).inserted }
    }
}
