/// Reads every figure a text states.
///
/// Deterministic and lexical: no model call, no locale. English number formats only, with Western
/// (`1,234,567`) and Indian (`12,34,567`) grouping; numbers written as words are not read.
public struct FigureReader: Sendable {
    public init() {}

    public func figures(in text: String) -> [Figure] {
        let scanner = FigureScanner(text)
        let labels = LabelIndex(scanner.chars)
        let raws = scanner.scan()
        return raws.indices.map { index in
            let raw = raws[index]
            let lower = index > 0 ? raws[index - 1].end : nil
            let upper = index + 1 < raws.count ? raws[index + 1].start : scanner.chars.count
            return Figure(
                text: scanner.string(raw.start, raw.end),
                value: raw.value,
                step: raw.step,
                significantDigits: raw.significantDigits,
                trailingZeros: raw.trailingZeros,
                isPercent: raw.isPercent,
                unit: raw.unit,
                scale: raw.scale,
                qualifier: raw.qualifier,
                role: raw.role,
                offset: raw.start,
                label: labels.label(start: raw.start, end: raw.end, after: lower, before: upper)
            )
        }
    }
}
