import XCTest
@testable import NumberBindingKit

final class BinderTests: XCTestCase {
    let binder = NumberBinder()

    func statuses(_ answer: String, _ sources: [NumberSource], policy: BindingPolicy = .standard) -> [String] {
        NumberBinder(policy: policy).bind(answer: answer, sources: sources).figures.map(\.status.name)
    }

    func testClassificationOrder() {
        let tool = NumberSource.tool("analytics", output: #"{"conversion_rate":0.057,"orders":2748}"#)
        XCTAssertEqual(statuses("conversion rate 6.7%, orders 2,748, step 3, 2 options, 4,100 visits", [tool]),
                       ["contradicted", "exact", "exempt", "exempt", "unbound"])
        let report = binder.bind(answer: "conversion rate 6.7%", sources: [tool])
        XCTAssertEqual(report.figures[0].support.map(\.figure.text), ["0.057"])
        XCTAssertEqual(report.figures[0].support.map(\.sourceID), ["tool:analytics"])
        XCTAssertEqual(report.figures[0].support.map(\.kind), [.tool])
    }

    func testDirectBeatsDerivedAndBestRelationWins() {
        let sources: [NumberSource] = [.document(id: "a", title: "A", text: "Orders 1,100 then 1,265; 165 more; 1,234.4")]
        XCTAssertEqual(statuses("165", sources), ["exact"])
        XCTAssertEqual(statuses("1,234", sources), ["rounded"])
        let both: [NumberSource] = [.user("1,234.4"), .tool("t", output: "1,234")]
        XCTAssertEqual(binder.bind(answer: "1,234", sources: both).figures[0].support[0].sourceLabel, "t")
    }

    func testDerivationGuards() {
        let sheet: [NumberSource] = [.document(id: "s", title: "sheet", text: "Q2 orders: 1,100. Q3 orders: 1,265.")]
        XCTAssertEqual(statuses("fell 15%", sheet), ["derived"])
        XCTAssertEqual(statuses("a change of -165", sheet), ["derived"])
        XCTAssertEqual(statuses("a change of 2,365", sheet), ["derived"])
        XCTAssertEqual(statuses("9", sheet), ["exempt"])
        XCTAssertEqual(statuses("16%", sheet), ["unbound"])
        XCTAssertEqual(statuses("165", sheet, policy: BindingPolicy(maxDerivationOperands: 1)), ["unbound"])
        XCTAssertEqual(statuses("165", sheet, policy: BindingPolicy(derivations: [])), ["unbound"])
        XCTAssertEqual(statuses("165", [.user("only 1,100")]), ["unbound"])
        XCTAssertEqual(statuses("in 2026", sheet), ["unbound"])
        let percents: [NumberSource] = [.user("4.3% and 5.7%")]
        XCTAssertEqual(statuses("a 1.4% gap", percents), ["derived"])
        XCTAssertEqual(statuses("costs 12.5", [.user("5 s and 7 kg")]), ["unbound"])
    }

    func testContradictionRules() {
        let tool = NumberSource.tool("accounts", output: #"{"users":1234,"active_users":1296}"#)
        XCTAssertEqual(statuses("users 1,800", [tool]), ["contradicted"])
        let near = binder.bind(answer: "active users 1,800", sources: [tool])
        XCTAssertEqual(near.figures[0].support[0].figure.text, "1296")
        XCTAssertEqual(statuses("roughly 1,400 active users", [tool]), ["unbound"])
        XCTAssertEqual(statuses("1,800", [tool]), ["unbound"])
        XCTAssertEqual(statuses("users 1,800 kg", [.tool("t", output: #"{"users":"5 sec"}"#)]), ["unbound"])
        let clock = NumberSource.tool("current_time", output: "now 14:30")
        XCTAssertEqual(statuses("It is 3:30 PM", [clock]), ["contradicted"])
        let same = Support(.user("x"), FigureReader().figures(in: "users 9")[0])
        let rank = binder.rank(same, against: FigureReader().figures(in: "users 10")[0])
        XCTAssertEqual(rank.shared, 1)
        XCTAssertTrue(RivalRank(shared: 2, distance: 9) < RivalRank(shared: 1, distance: 0))
        XCTAssertTrue(RivalRank(shared: 1, distance: 0.1) < RivalRank(shared: 1, distance: 0.2))
    }

    func testEchoesAndExemptEvidence() {
        let earlier = NumberSource.earlierAnswer("The fee is 2.9%.", index: 1)
        XCTAssertEqual(statuses("The fee is 2.9%.", [earlier]), ["echoed"])
        XCTAssertEqual(statuses("The fee is 2.9%.", [earlier, .user("fee 2.9%")]), ["exact"])
        XCTAssertEqual(statuses("version 17", [.user("iOS 17")], policy: BindingPolicy(exemptRoles: [])), ["exact"])
        XCTAssertEqual(statuses("17", [.user("iOS 17")]), ["unbound"])
        XCTAssertEqual(statuses("3", [], policy: .strict), ["unbound"])
        let pool = EvidencePool(sources: [.user("5 and 5 and 7"), earlier], reader: FigureReader(), exempt: [])
        XCTAssertEqual(pool.operands.map(\.figure.value), [5, 7])
        XCTAssertEqual(pool.echoes.count, 1)
        XCTAssertEqual(binder.figures(in: "a 5").count, 1)
    }

    func testPolicyLadderIsMonotone() {
        let sources: [NumberSource] = [
            .tool("accounts", output: #"{"users":1234,"active_seats":1296}"#),
            .document(id: "fin", title: "finance", text: "Revenue: $1,234,567.")
        ]
        let answer = "Over 1,200 users, $1.23M in revenue and roughly 1,400 active seats."
        let counts = [BindingPolicy.strict, .standard, .lenient].map {
            NumberBinder(policy: $0).bind(answer: answer, sources: sources).verified.count
        }
        XCTAssertEqual(counts, [0, 2, 3])
    }
}
