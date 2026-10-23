/// Arithmetic on two evidence figures that can back a figure no source states directly: the growth a
/// model computed from two quarters, or 15% of a total the user gave.
public enum Derivation: String, Sendable, Hashable, CaseIterable {
    case sum, difference, product, ratio, percentChange, percentOf

    /// The value this derivation makes of two evidence figures, in the answer's terms, or nil when it
    /// does not apply to them.
    func apply(_ first: Figure, _ second: Figure, answerIsPercent: Bool) -> Double? {
        switch self {
        case .sum: Self.additive(first, second, answerIsPercent).map { _ in first.value + second.value }
        case .difference: Self.additive(first, second, answerIsPercent).map { _ in first.value - second.value }
        case .product: Self.product(first, second, answerIsPercent)
        case .ratio: Self.ratio(first, second, answerIsPercent)
        case .percentChange: Self.change(first, second, answerIsPercent)
        case .percentOf: Self.share(first, second, answerIsPercent)
        }
    }

    /// Difference and percent change are reported without their sign ("fell by 165").
    var isDirectional: Bool { self == .difference || self == .percentChange }

    static func additive(_ first: Figure, _ second: Figure, _ percent: Bool) -> Bool? {
        first.isPercent == second.isPercent && first.isPercent == percent && first.unit == second.unit ? true : nil
    }

    static func product(_ first: Figure, _ second: Figure, _ percent: Bool) -> Double? {
        !percent && !first.isPercent && !second.isPercent ? first.value * second.value : nil
    }

    static func ratio(_ first: Figure, _ second: Figure, _ percent: Bool) -> Double? {
        guard first.isPercent == second.isPercent, second.value != 0 else { return nil }
        return first.value / second.value * (percent ? 100 : 1)
    }

    static func change(_ first: Figure, _ second: Figure, _ percent: Bool) -> Double? {
        guard percent, !first.isPercent, !second.isPercent, first.value != 0, first.unit == second.unit else {
            return nil
        }
        return (second.value - first.value) / first.value * 100
    }

    static func share(_ first: Figure, _ second: Figure, _ percent: Bool) -> Double? {
        !percent && !first.isPercent && second.isPercent ? first.value * second.value / 100 : nil
    }
}
