/// How closely an answer's figure meets one evidence figure, from strongest to weakest. The binder
/// reports the weakest relation a match needed: rescaled and then rounded is `rounded`.
enum Relation: Int, Comparable, Sendable {
    case exact, rescaled, converted, rounded, approximate, withinBound

    static func < (lhs: Relation, rhs: Relation) -> Bool { lhs.rawValue < rhs.rawValue }

    var status: BindingStatus {
        switch self {
        case .exact: .exact
        case .rescaled: .rescaled
        case .converted: .converted
        case .rounded: .rounded
        case .approximate: .approximate
        case .withinBound: .withinBound
        }
    }
}

/// Applies a policy's matching rules to one pair of figures.
struct Matcher: Sendable {
    struct Target {
        let value: Double
        let relation: Relation
    }

    let policy: BindingPolicy

    func relation(of figure: Figure, to source: Figure) -> Relation? {
        if figure.role == .clock || source.role == .clock {
            return clockRelation(figure, source)
        }
        guard let target = target(for: figure, from: source),
              let closeness = closeness(of: figure, to: target.value) else { return nil }
        return max(target.relation, closeness)
    }

    /// The source's value in the answer's terms: the answer's unit, percent form and scale.
    func target(for figure: Figure, from source: Figure) -> Target? {
        var value = source.value
        var relation = Relation.exact
        if let unit = figure.unit, let other = source.unit, unit != other {
            guard unit.family == other.family, policy.allowsConversion else { return nil }
            value = value * other.factor / unit.factor
            relation = .converted
        }
        if figure.isPercent != source.isPercent {
            let carriesUnit = figure.isPercent ? source.unit != nil : figure.unit != nil
            guard policy.allowsRescaling, !carriesUnit else { return nil }
            value = figure.isPercent ? value * 100 : value / 100
            relation = max(relation, .rescaled)
        } else if figure.scale != source.scale {
            guard policy.allowsRescaling else { return nil }
            relation = max(relation, .rescaled)
        }
        return Target(value: value, relation: relation)
    }

    /// Equal, rounded to the figure's last digit, or inside its qualifier. A derived value needs
    /// three significant digits before rounding is allowed, because two-digit coincidences are cheap.
    func closeness(of figure: Figure, to target: Double, derived: Bool = false) -> Relation? {
        let slack = 1e-9 * max(1, abs(target))
        let difference = abs(figure.value - target)
        if difference <= slack { return .exact }
        if derived && figure.significantDigits < 3 { return nil }
        let half = roundingStep(for: figure) / 2
        if policy.allowsRounding, difference <= half + slack { return .rounded }
        switch figure.qualifier {
        case .approximately?:
            return difference <= policy.approximateTolerance * abs(target) + slack ? .approximate : nil
        case .atLeast? where !derived:
            let reach = figure.value + abs(figure.value) * policy.boundSlack + half
            return target >= figure.value - half - slack && target <= reach ? .withinBound : nil
        case .atMost? where !derived:
            let reach = figure.value - abs(figure.value) * policy.boundSlack - half
            return target <= figure.value + half + slack && target >= reach ? .withinBound : nil
        default:
            return nil
        }
    }

    func roundingStep(for figure: Figure) -> Double {
        guard policy.roundsAtTrailingZeros, figure.trailingZeros >= 2 else { return figure.step }
        return figure.step * pow10(figure.trailingZeros)
    }

    func pow10(_ exponent: Int) -> Double {
        (0..<exponent).reduce(1) { value, _ in value * 10 }
    }

    /// A time of day matches a time of day: the same, or the source cut to the figure's precision
    /// (`14:30` of `14:30:45`, since clocks are shown truncated, not rounded).
    func clockRelation(_ figure: Figure, _ source: Figure) -> Relation? {
        guard figure.role == .clock, source.role == .clock else { return nil }
        if figure.value == source.value { return .exact }
        let shown = (source.value / figure.step).rounded(.down) * figure.step
        return policy.allowsRounding && shown == figure.value ? .rounded : nil
    }

    /// Whether two figures measure the same kind of thing, so a different value is a contradiction.
    func comparable(_ figure: Figure, _ source: Figure) -> Bool {
        guard (figure.role == .clock) == (source.role == .clock) else { return false }
        if figure.isPercent != source.isPercent {
            let fraction = figure.isPercent ? source : figure
            return fraction.unit == nil && abs(fraction.value) <= 1
        }
        guard let unit = figure.unit, let other = source.unit else { return true }
        return unit.family == other.family
    }
}
