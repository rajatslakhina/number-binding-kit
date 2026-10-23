/// Text a number in an answer may be bound to: a tool's output, a retrieved document, the user's own
/// message, the system prompt, or an earlier answer.
public struct NumberSource: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case tool, document, user, system
        /// An earlier answer from the model. Its figures can only make a number `echoed`, never
        /// verified: a model cannot vouch for its own numbers by repeating them.
        case assistant
    }

    public let id: String
    public let kind: Kind
    /// How a note names it: "calculator", "Q3 report", "your message".
    public let label: String
    public let text: String

    public init(id: String, kind: Kind, label: String, text: String) {
        self.id = id
        self.kind = kind
        self.label = label
        self.text = text
    }

    public static func tool(_ name: String, output: String) -> NumberSource {
        NumberSource(id: "tool:\(name)", kind: .tool, label: name, text: output)
    }

    public static func user(_ text: String) -> NumberSource {
        NumberSource(id: "user", kind: .user, label: "your message", text: text)
    }

    public static func document(id: String, title: String, text: String) -> NumberSource {
        NumberSource(id: id, kind: .document, label: title, text: text)
    }

    public static func earlierAnswer(_ text: String, index: Int) -> NumberSource {
        NumberSource(id: "answer:\(index)", kind: .assistant, label: "answer \(index)", text: text)
    }
}
