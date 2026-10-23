/// The declared rules a figure is matched under. A policy is the contract: a number shown as verified
/// is verified *under this policy*, and a stricter policy never verifies a number a looser one would
/// not (tested over the labelled corpus).
public struct BindingPolicy: Sendable, Hashable {
    /// `1.2 million` may match `1,200,000`, and `5.7%` may match `0.057`.
    public var allowsRescaling: Bool
    /// `1.5 s` may match `1500 ms`, within one unit family. Currencies never convert.
    public var allowsConversion: Bool
    /// `5.7%` may match `5.74%`: the source rounded to the answer's last written digit.
    public var allowsRounding: Bool
    /// An integer's trailing zeros count as its rounding place: `1,200` may match `1,234`.
    public var roundsAtTrailingZeros: Bool
    /// Relative difference allowed when the answer says "about" or "roughly". 0 turns it off.
    public var approximateTolerance: Double
    /// How far past an "over" or "under" figure the source may sit, relative to it. 0 turns it off.
    public var boundSlack: Double
    /// Arithmetic on two evidence figures that may back an answer's figure.
    public var derivations: Set<Derivation>
    /// Derivations are not tried over more evidence figures than this: the more there are, the
    /// likelier a coincidence.
    public var maxDerivationOperands: Int
    /// Unmatched plain integers up to this are counts in passing ("2 options"), not claims.
    public var smallCountLimit: Int?
    /// Roles never checked, in the answer or as evidence.
    public var exemptRoles: Set<FigureRole>

    public init(
        allowsRescaling: Bool = true,
        allowsConversion: Bool = true,
        allowsRounding: Bool = true,
        roundsAtTrailingZeros: Bool = false,
        approximateTolerance: Double = 0.05,
        boundSlack: Double = 0.25,
        derivations: Set<Derivation> = Set(Derivation.allCases),
        maxDerivationOperands: Int = 16,
        smallCountLimit: Int? = 10,
        exemptRoles: Set<FigureRole> = [.ordinal, .listMarker, .citation, .identifier]
    ) {
        self.allowsRescaling = allowsRescaling
        self.allowsConversion = allowsConversion
        self.allowsRounding = allowsRounding
        self.roundsAtTrailingZeros = roundsAtTrailingZeros
        self.approximateTolerance = max(approximateTolerance, 0)
        self.boundSlack = max(boundSlack, 0)
        self.derivations = derivations
        self.maxDerivationOperands = max(maxDerivationOperands, 0)
        self.smallCountLimit = smallCountLimit
        self.exemptRoles = exemptRoles
    }

    /// Only the same value written the same way.
    public static let strict = BindingPolicy(
        allowsRescaling: false, allowsConversion: false, allowsRounding: false, approximateTolerance: 0,
        boundSlack: 0, derivations: [], smallCountLimit: nil
    )
    public static let standard = BindingPolicy()
    public static let lenient = BindingPolicy(
        roundsAtTrailingZeros: true, approximateTolerance: 0.1, boundSlack: 0.5, maxDerivationOperands: 24
    )
}
