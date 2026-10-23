import NumberBindingKit

let binder = NumberBinder()

func calculatorRoundTrip() {
    heading(1, "Calculator round trip: every number has a source")
    let report = binder.bind(
        answer: "15% of 2,340 is **351**.",
        sources: [
            .user("What is 15% of 2,340?"),
            .tool("calculator", output: #"{"expression":"2340*0.15","result":351}"#)
        ]
    )
    show(report)
}

func restatedWrong() {
    heading(2, "A tool result restated wrong")
    let report = binder.bind(
        answer: "Your conversion rate was 6.7% across 48,210 sessions, from 2,748 orders.",
        sources: [.tool("analytics", output: #"{"conversion_rate":0.057,"sessions":48210,"orders":2748}"#)]
    )
    show(report)
}

func roundingScaleUnits() {
    heading(3, "Rounding, scale words and units")
    let report = binder.bind(
        answer: "Revenue came in at $1.2 million, churn was 4.3% and p95 latency was 1.48 seconds.",
        sources: [
            .document(
                id: "q3", title: "Q3 report",
                text: "Q3 revenue was $1,234,567 and p95 latency was 1480 ms. Churn held at 4.32%."
            )
        ]
    )
    show(report)
}

func computedGrowth() {
    heading(4, "Numbers the model computed from two sources")
    let report = binder.bind(
        answer: "Orders grew 15% quarter on quarter, an increase of 165. At that pace Q4 reaches 1,500.",
        sources: [.document(id: "ops", title: "ops sheet", text: "Q2 orders: 1,100. Q3 orders: 1,265.")]
    )
    show(report)
}

func clockTool() {
    heading(5, "A clock tool, read back right and wrong")
    let output = #"{"timeZone":"Asia/Kolkata","iso8601":"2026-10-23T14:30:05+05:30","#
        + #""readable":"Friday 23 October 2026 at 14:30","unixSeconds":1792745405}"#
    let clock = NumberSource.tool("current_time", output: output)
    show(binder.bind(answer: "It's 2:30 PM in Kolkata on Friday, 23 October 2026.", sources: [clock]))
    show(binder.bind(answer: "It's 3:30 PM in Kolkata on Friday, 23 October 2026.", sources: [clock]))
}

func namesAndCounts() {
    heading(6, "Names, markers and counts are not claims")
    let report = binder.bind(
        answer: "1. Update to iOS 17 and Swift 6.\n2. Re-run step 3 [4] for the 2nd time; it has 2 options.",
        sources: []
    )
    show(report)
}

func echoAcrossTurns() async {
    heading(7, "A number that only repeats an earlier answer")
    let session = BindingSession()
    show(await session.review(answer: "The standard card fee is 2.9% plus 30 cents.", evidence: []))
    let second = await session.review(
        answer: "At 2.9% on 1,000 payments of $50 ($50,000), that is $1,450 in percentage fees.",
        evidence: [.user("And for 1,000 payments of $50 each?")]
    )
    show(second)
    let totals = await session.totals
    let bound = "\(totals.verified)/\(totals.checked) bound"
    print("   session: \(totals.turns) turns, \(bound), \(totals.unverified) unverified")
}

func policyLadder() {
    heading(8, "One answer under three policies")
    let answer = "Over 1,200 users, $1.23M in revenue and roughly 1,400 active seats."
    let sources: [NumberSource] = [
        .tool("accounts", output: #"{"users":1234,"active_seats":1296}"#),
        .document(id: "fin", title: "finance", text: "Revenue: $1,234,567.")
    ]
    for (name, policy) in [("strict", BindingPolicy.strict), ("standard", .standard), ("lenient", .lenient)] {
        let report = NumberBinder(policy: policy).bind(answer: answer, sources: sources)
        let statuses = report.figures.map { "\($0.figure.text)=\(describe($0.status))" }.joined(separator: "  ")
        print("   \(name.padding(toLength: 9, withPad: " ", startingAt: 0)) \(report.verified.count)/3  \(statuses)")
    }
}
