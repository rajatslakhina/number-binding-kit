/// One evidence figure that backs, contradicts or is echoed by an answer's figure.
public struct Support: Sendable, Hashable {
    public let sourceID: String
    public let sourceLabel: String
    public let kind: NumberSource.Kind
    public let figure: Figure

    init(_ source: NumberSource, _ figure: Figure) {
        sourceID = source.id
        sourceLabel = source.label
        kind = source.kind
        self.figure = figure
    }
}

/// Why a figure was not checked.
public enum Exemption: Sendable, Hashable {
    /// It names or numbers something: a version, a list marker, a citation, an ordinal.
    case role(FigureRole)
    /// A plain integer under the policy's small-count limit that matched nothing.
    case smallCount
}

/// What became of one figure in an answer.
public enum BindingStatus: Sendable, Hashable {
    /// The same value at the same scale.
    case exact
    /// The same value at another scale or as a percentage of a fraction: `1.2 million`, `5.7%` of `0.057`.
    case rescaled
    /// The same quantity in another unit of the same family: `1.5 s` of `1500 ms`.
    case converted
    /// The source rounded to the answer's last written digit.
    case rounded
    /// Within the policy's tolerance, and the answer said "about".
    case approximate
    /// Inside the bound the answer stated: "over 1,200" of `1,234`.
    case withinBound
    /// Arithmetic on two evidence figures gives it.
    case derived(Derivation)
    /// Matches only an earlier answer. A model repeating its own number is not evidence for it.
    case echoed
    /// An evidence figure about the same thing says something else.
    case contradicted
    /// Nothing this turn returned backs it.
    case unbound
    case exempt(Exemption)

    public var isVerified: Bool {
        switch self {
        case .exact, .rescaled, .converted, .rounded, .approximate, .withinBound, .derived: true
        case .echoed, .contradicted, .unbound, .exempt: false
        }
    }

    public var isExempt: Bool {
        if case .exempt = self { true } else { false }
    }

    /// The status without its payload, for counting.
    public var name: String {
        switch self {
        case .exact: "exact"
        case .rescaled: "rescaled"
        case .converted: "converted"
        case .rounded: "rounded"
        case .approximate: "approximate"
        case .withinBound: "withinBound"
        case .derived: "derived"
        case .echoed: "echoed"
        case .contradicted: "contradicted"
        case .unbound: "unbound"
        case .exempt: "exempt"
        }
    }
}

/// A figure from the answer, what became of it, and the evidence figures behind that.
public struct BoundFigure: Sendable, Hashable {
    public let figure: Figure
    public let status: BindingStatus
    /// The matching figure, the two operands of a derivation, the contradicting figure, or the
    /// earlier answer's figure. Empty for unbound and exempt figures.
    public let support: [Support]
}
