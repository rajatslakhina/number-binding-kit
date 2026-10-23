import XCTest
@testable import NumberBindingKit

/// A small home-made labelled set: each answer's figures with the status a careful reader would give
/// them. It is the regression floor, not a benchmark.
final class CorpusTests: XCTestCase {
    struct Case {
        let answer: String
        let sources: [NumberSource]
        let expected: [String]
    }

    static let calculator = NumberSource.tool("calculator", output: #"{"expression":"2340*0.15","result":351}"#)
    static let clock = NumberSource.tool(
        "current_time",
        output: #"{"iso8601":"2026-10-23T14:30:05+05:30","readable":"Friday 23 October 2026 at 14:30"}"#
    )
    static let report = NumberSource.document(
        id: "q3", title: "Q3 report",
        text: "Q3 revenue was $1,234,567 and p95 latency was 1480 ms. Churn held at 4.32%. 48,210 sessions."
    )

    static let cases: [Case] = [
        Case(answer: "15% of 2,340 is 351.", sources: [.user("What is 15% of 2,340?"), calculator],
             expected: ["exact", "exact", "exact"]),
        Case(answer: "The result is 315.", sources: [calculator], expected: ["contradicted"]),
        Case(answer: "That comes to 351.0.", sources: [calculator], expected: ["exact"]),
        Case(answer: "15% of 2,340 is 351.", sources: [.user("What is 15% of 2,340?")],
             expected: ["exact", "exact", "derived"]),
        Case(answer: "It's 2:30 PM on 23 October 2026.", sources: [clock], expected: ["exact", "exact", "exact"]),
        Case(answer: "It's 14:31.", sources: [clock], expected: ["contradicted"]),
        Case(answer: "Revenue was $1.2 million.", sources: [report], expected: ["rounded"]),
        Case(answer: "Revenue was $1.3 million.", sources: [report], expected: ["contradicted"]),
        Case(answer: "Revenue was about $1.25 million.", sources: [report], expected: ["approximate"]),
        Case(answer: "Churn was 4.3%.", sources: [report], expected: ["rounded"]),
        Case(answer: "Churn was 4.4%.", sources: [report], expected: ["contradicted"]),
        Case(answer: "p95 latency was 1.48 seconds.", sources: [report], expected: ["converted"]),
        Case(answer: "p95 latency stayed under 1.6 seconds.", sources: [report], expected: ["withinBound"]),
        Case(answer: "Over 48,000 sessions.", sources: [report], expected: ["withinBound"]),
        Case(answer: "We had 51,000 sessions.", sources: [report], expected: ["contradicted"]),
        Case(answer: "Founded in 2011, it has 3 offices.", sources: [report], expected: ["unbound", "exempt"]),
        Case(answer: "See step 2 in iOS 17 [3].", sources: [], expected: ["exempt", "exempt", "exempt"])
    ]

    func testCorpus() {
        let binder = NumberBinder()
        var hits = 0
        var total = 0
        for item in Self.cases {
            let got = binder.bind(answer: item.answer, sources: item.sources).figures.map(\.status.name)
            XCTAssertEqual(got, item.expected, item.answer)
            hits += zip(got, item.expected).filter { $0 == $1 }.count
            total += item.expected.count
        }
        XCTAssertEqual(hits, total)
        XCTAssertEqual(total, 26)
    }

    /// The monotonicity PCN states for policy refinement: a stricter policy never verifies a figure a
    /// looser one does not.
    func testStricterPoliciesVerifyASubset() {
        let ladder: [BindingPolicy] = [.strict, .standard, .lenient]
        for item in Self.cases {
            let verified = ladder.map { policy in
                Set(NumberBinder(policy: policy).bind(answer: item.answer, sources: item.sources).figures.indices
                    .filter { NumberBinder(policy: policy).bind(answer: item.answer, sources: item.sources)
                        .figures[$0].status.isVerified })
            }
            XCTAssertTrue(verified[0].isSubset(of: verified[1]), item.answer)
            XCTAssertTrue(verified[1].isSubset(of: verified[2]), item.answer)
        }
    }
}
