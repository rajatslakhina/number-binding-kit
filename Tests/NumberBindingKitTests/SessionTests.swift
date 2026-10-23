import XCTest
@testable import NumberBindingKit

final class SessionTests: XCTestCase {
    func testSessionRemembersAnswersAndTotals() async {
        let session = BindingSession()
        let empty = await session.totals
        XCTAssertNil(empty.verifiedFraction)
        let first = await session.review(answer: "The fee is 2.9% plus 30 cents.", evidence: [])
        XCTAssertEqual(first.unbound.count, 2)
        let second = await session.review(
            answer: "At 2.9% on 1,000 payments of $50 ($50,000), that is $1,450.",
            evidence: [.user("And for 1,000 payments of $50 each?")]
        )
        XCTAssertEqual(second.figures.map(\.status.name), ["echoed", "exact", "exact", "derived", "unbound"])
        let totals = await session.totals
        XCTAssertEqual(totals.turns, 2)
        XCTAssertEqual(totals.checked, 7)
        XCTAssertEqual(totals.verified, 3)
        XCTAssertEqual(totals.contradicted, 0)
        XCTAssertEqual(totals.unverified, 4)
        XCTAssertEqual(totals.verifiedFraction ?? 0, 3.0 / 7.0, accuracy: 1e-12)
        XCTAssertEqual(session.binder.policy, .standard)
    }
}
