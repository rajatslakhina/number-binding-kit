import XCTest
@testable import NumberBindingKit

final class ReportTests: XCTestCase {
    let binder = NumberBinder()
    let tool = NumberSource.tool("analytics", output: #"{"conversion_rate":0.057,"orders":2748}"#)

    func testVerdictsAndFractions() {
        let empty = binder.bind(answer: "No numbers here.", sources: [tool])
        XCTAssertEqual(empty.verdict, .nothingToCheck)
        XCTAssertNil(empty.boundFraction)
        XCTAssertNil(empty.note)
        XCTAssertFalse(empty.needsAttention)
        XCTAssertEqual(empty.summary, "nothingToCheck: checked 0, bound 0")
        let bound = binder.bind(answer: "2,748 orders", sources: [tool])
        XCTAssertEqual(bound.verdict, .allBound)
        XCTAssertEqual(bound.boundFraction, 1)
        XCTAssertEqual(bound.summary, "allBound: checked 1, bound 1 [exact 1]")
        let unverified = binder.bind(answer: "2,748 orders and 4,100 visits", sources: [tool])
        XCTAssertEqual(unverified.verdict, .unverified)
        XCTAssertEqual(unverified.boundFraction, 0.5)
    }

    func testNoteAndSummaryCarryEveryKindOfProblem() {
        let earlier = NumberSource.earlierAnswer("The fee is 2.9%.", index: 1)
        let report = binder.bind(
            answer: "Conversion rate 6.7%, 2,748 orders, fee 2.9%, 4,100 visits, 5,200 sessions, step 3.",
            sources: [tool, earlier]
        )
        XCTAssertEqual(report.verdict, .contradicted)
        XCTAssertEqual(report.note, "Checked 5 numbers against what this turn returned. "
            + "Doesn't match: 6.7% (analytics says 0.057). Nothing this turn returned backs 4,100 and 5,200. "
            + "Only repeats an earlier answer: 2.9%.")
        XCTAssertEqual(report.summary, "contradicted: checked 5, bound 1 [exact 1]; contradicted 6.7% vs 0.057; "
            + "unbound 4,100, 5,200; echoed 2.9%; exempt 1")
        let single = binder.bind(answer: "4,100 visits", sources: [tool])
        XCTAssertEqual(single.note, "Checked 1 number against what this turn returned. Nothing this turn returned backs 4,100.")
        XCTAssertEqual(NumberBindingReport.list(["a", "b", "c"]), "a, b and c")
        XCTAssertEqual(NumberBindingReport.list([]), "")
    }

    func testSegmentsAndAnnotation() {
        let report = binder.bind(answer: "Rate 6.7% on 2,748 orders", sources: [tool])
        XCTAssertEqual(report.segments.count, 5)
        XCTAssertEqual(report.annotated(), "Rate 6.7% [unverified] on 2,748 orders")
        XCTAssertEqual(report.annotated(mark: "?"), "Rate 6.7%? on 2,748 orders")
        let edges = binder.bind(answer: "2,748", sources: [tool])
        XCTAssertEqual(edges.segments.count, 1)
        let exempt = binder.bind(answer: "iOS 17.", sources: [])
        XCTAssertEqual(exempt.annotated(), "iOS 17.")
    }

    func testStatusVocabulary() {
        let all: [BindingStatus] = [
            .exact, .rescaled, .converted, .rounded, .approximate, .withinBound, .derived(.sum),
            .echoed, .contradicted, .unbound, .exempt(.smallCount), .exempt(.role(.citation))
        ]
        XCTAssertEqual(all.map(\.name), [
            "exact", "rescaled", "converted", "rounded", "approximate", "withinBound", "derived",
            "echoed", "contradicted", "unbound", "exempt", "exempt"
        ])
        XCTAssertEqual(all.filter(\.isVerified).count, 7)
        XCTAssertEqual(all.filter(\.isExempt).count, 2)
    }

    func testSourceFactories() {
        XCTAssertEqual(NumberSource.user("x").label, "your message")
        XCTAssertEqual(NumberSource.document(id: "d", title: "Doc", text: "x").kind, .document)
        XCTAssertEqual(NumberSource.earlierAnswer("x", index: 2).id, "answer:2")
        XCTAssertEqual(NumberSource(id: "s", kind: .system, label: "system", text: "x").kind, .system)
        XCTAssertEqual(NumberSource.Kind.allCases.count, 5)
        XCTAssertEqual(MeasureUnit(family: "time", symbol: "s").factor, 1)
    }
}
