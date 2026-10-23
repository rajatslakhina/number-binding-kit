import NumberBindingKit

func heading(_ number: Int, _ title: String) {
    print("")
    print("── \(number). \(title)")
}

func show(_ report: NumberBindingReport) {
    print("   answer: \(report.answer.replacingOccurrences(of: "\n", with: " / "))")
    for bound in report.figures {
        let text = bound.figure.text.padding(toLength: 14, withPad: " ", startingAt: 0)
        let status = describe(bound.status).padding(toLength: 22, withPad: " ", startingAt: 0)
        let support = bound.support.map { "\($0.sourceLabel): \($0.figure.text)" }.joined(separator: " , ")
        print("   \(text)\(status)\(support.isEmpty ? "" : "<- " + support)")
    }
    print("   verdict: \(report.verdict.rawValue)  bound \(report.verified.count)/\(report.checked.count)")
    if let note = report.note { print("   note: \(note)") }
}

func describe(_ status: BindingStatus) -> String {
    switch status {
    case let .derived(derivation): "derived(\(derivation.rawValue))"
    case let .exempt(.role(role)): "exempt(\(role.rawValue))"
    case .exempt(.smallCount): "exempt(smallCount)"
    default: status.name
    }
}
