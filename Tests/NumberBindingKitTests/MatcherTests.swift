import XCTest
@testable import NumberBindingKit

final class MatcherTests: XCTestCase {
    let reader = FigureReader()

    func figure(_ text: String) -> Figure { reader.figures(in: text)[0] }

    func relation(_ answer: String, _ source: String, _ policy: BindingPolicy = .standard) -> Relation? {
        Matcher(policy: policy).relation(of: figure(answer), to: figure(source))
    }

    func testDirectRelations() {
        XCTAssertEqual(relation("351", "351"), .exact)
        XCTAssertEqual(relation("$1.2M", "$1.2M"), .exact)
        XCTAssertEqual(relation("1.2 million", "1,200,000"), .rescaled)
        XCTAssertEqual(relation("5.7%", "0.057"), .rescaled)
        XCTAssertEqual(relation("0.057", "5.7%"), .rescaled)
        XCTAssertEqual(relation("1.48 sec", "1480 ms"), .converted)
        XCTAssertEqual(relation("1.5 sec", "1480 ms"), .rounded)
        XCTAssertEqual(relation("$1.2 million", "$1,234,567"), .rounded)
        XCTAssertEqual(relation("6", "5.7"), .rounded)
        XCTAssertNil(relation("5.74", "5.7"))
        XCTAssertNil(relation("5 kg", "5 sec"))
        XCTAssertNil(relation("$5", "€5"))
        XCTAssertNil(relation("5.7%", "0.057 USD"))
        XCTAssertNil(relation("$0.057", "5.7%"))
        XCTAssertEqual(relation("5 ms", "5"), .exact)
        XCTAssertEqual(relation("5", "5 ms"), .exact)
    }

    func testPolicyTogglesTurnRelationsOff() {
        let none = BindingPolicy.strict
        XCTAssertNil(relation("1.2 million", "1,200,000", none))
        XCTAssertNil(relation("5.7%", "0.057", none))
        XCTAssertNil(relation("1.48 sec", "1480 ms", none))
        XCTAssertNil(relation("6", "5.7", none))
        XCTAssertNil(relation("about 1,300", "1,296", none))
    }

    func testQualifiersAndBounds() {
        XCTAssertEqual(relation("about 1,300", "1,296"), .approximate)
        XCTAssertNil(relation("about 1,400", "1,296"))
        XCTAssertEqual(relation("about 1,400", "1,296", .lenient), .approximate)
        XCTAssertEqual(relation("over 1,200", "1,234"), .withinBound)
        XCTAssertNil(relation("over 1,200", "1,600"))
        XCTAssertNil(relation("over 1,200", "1,100"))
        XCTAssertEqual(relation("under 1.6 sec", "1480 ms"), .withinBound)
        XCTAssertNil(relation("under 1.6 sec", "1700 ms"))
        XCTAssertNil(relation("under 1.6 sec", "900 ms"))
        XCTAssertEqual(relation("1,200", "1,234", .lenient), .rounded)
        XCTAssertNil(relation("1,200", "1,234"))
        XCTAssertNil(relation("50", "54", .lenient))
    }

    func testDerivedClosenessIsStricter() {
        let matcher = Matcher(policy: .standard)
        XCTAssertEqual(matcher.closeness(of: figure("15%"), to: 15, derived: true), .exact)
        XCTAssertNil(matcher.closeness(of: figure("15%"), to: 15.2, derived: true))
        XCTAssertEqual(matcher.closeness(of: figure("165"), to: 165.3, derived: true), .rounded)
        XCTAssertNil(matcher.closeness(of: figure("over 165"), to: 180, derived: true))
        XCTAssertEqual(matcher.pow10(3), 1_000)
    }

    func testClocks() {
        XCTAssertEqual(relation("14:30", "14:30"), .exact)
        XCTAssertEqual(relation("2:30 PM", "14:30:45"), .rounded)
        XCTAssertNil(relation("2:31 PM", "14:30:45"))
        XCTAssertNil(relation("14:30", "14:30:45", .strict))
        XCTAssertNil(relation("14:30", "52200"))
        XCTAssertNil(relation("52200", "14:30"))
    }

    func testComparable() {
        let matcher = Matcher(policy: .standard)
        XCTAssertTrue(matcher.comparable(figure("6.7%"), figure("0.057")))
        XCTAssertTrue(matcher.comparable(figure("0.057"), figure("6.7%")))
        XCTAssertFalse(matcher.comparable(figure("6.7%"), figure("1,000")))
        XCTAssertFalse(matcher.comparable(figure("6.7%"), figure("0.5 sec")))
        XCTAssertFalse(matcher.comparable(figure("14:30"), figure("5")))
        XCTAssertTrue(matcher.comparable(figure("$5"), figure("7")))
        XCTAssertTrue(matcher.comparable(figure("5 ms"), figure("7 sec")))
        XCTAssertFalse(matcher.comparable(figure("5 ms"), figure("7 kg")))
        XCTAssertTrue(Relation.exact < .rescaled)
        XCTAssertEqual([Relation.exact, .rescaled, .converted, .rounded, .approximate, .withinBound].map(\.status.name),
                       ["exact", "rescaled", "converted", "rounded", "approximate", "withinBound"])
    }

    func testPolicyClamps() {
        let policy = BindingPolicy(approximateTolerance: -1, boundSlack: -1, maxDerivationOperands: -3)
        XCTAssertEqual(policy.approximateTolerance, 0)
        XCTAssertEqual(policy.boundSlack, 0)
        XCTAssertEqual(policy.maxDerivationOperands, 0)
    }

    func testDerivations() {
        let (first, second) = (figure("1,100"), figure("1,265"))
        let (percent, otherPercent) = (figure("15%"), figure("4%"))
        XCTAssertEqual(Derivation.sum.apply(first, second, answerIsPercent: false), 2_365)
        XCTAssertNil(Derivation.sum.apply(first, percent, answerIsPercent: false))
        XCTAssertNil(Derivation.sum.apply(figure("5 s"), figure("5 kg"), answerIsPercent: false))
        XCTAssertEqual(Derivation.difference.apply(percent, otherPercent, answerIsPercent: true), 11)
        XCTAssertEqual(Derivation.product.apply(first, second, answerIsPercent: false), 1_391_500)
        XCTAssertNil(Derivation.product.apply(first, percent, answerIsPercent: false))
        XCTAssertEqual(Derivation.ratio.apply(second, first, answerIsPercent: false) ?? 0, 1.15, accuracy: 1e-9)
        XCTAssertEqual(Derivation.ratio.apply(second, first, answerIsPercent: true) ?? 0, 115, accuracy: 1e-9)
        XCTAssertNil(Derivation.ratio.apply(first, figure("0"), answerIsPercent: false))
        XCTAssertNil(Derivation.ratio.apply(first, percent, answerIsPercent: false))
        XCTAssertEqual(Derivation.percentChange.apply(first, second, answerIsPercent: true) ?? 0, 15, accuracy: 1e-9)
        XCTAssertNil(Derivation.percentChange.apply(first, second, answerIsPercent: false))
        XCTAssertNil(Derivation.percentChange.apply(figure("0"), second, answerIsPercent: true))
        XCTAssertEqual(Derivation.percentOf.apply(figure("2,340"), percent, answerIsPercent: false), 351)
        XCTAssertNil(Derivation.percentOf.apply(percent, figure("2,340"), answerIsPercent: false))
        XCTAssertTrue(Derivation.difference.isDirectional)
        XCTAssertFalse(Derivation.sum.isDirectional)
    }
}
