import XCTest
@testable import NumberBindingKit

final class ReaderTests: XCTestCase {
    let reader = FigureReader()

    func figures(_ text: String) -> [Figure] { reader.figures(in: text) }

    func one(_ text: String, file: StaticString = #filePath, line: UInt = #line) -> Figure? {
        let found = figures(text)
        XCTAssertEqual(found.count, 1, "\(found.map(\.text))", file: file, line: line)
        return found.first
    }

    func testGroupingDecimalsAndExponents() throws {
        XCTAssertEqual(one("total 1,234,567")?.value, 1_234_567)
        XCTAssertEqual(one("total 12,34,567")?.value, 1_234_567)
        XCTAssertEqual(figures("1,2,3").map(\.value), [1, 2, 3])
        XCTAssertEqual(figures("10,20,30").map(\.value), [10, 20, 30])
        XCTAssertEqual(figures("12,34").map(\.value), [12, 34])
        let decimal = try XCTUnwrap(one("rate 0.057"))
        XCTAssertEqual(decimal.value, 0.057, accuracy: 1e-12)
        XCTAssertEqual(decimal.step, 0.001, accuracy: 1e-12)
        XCTAssertEqual(decimal.significantDigits, 2)
        XCTAssertEqual(one("1.5E-3")?.value ?? 0, 0.0015, accuracy: 1e-12)
        XCTAssertEqual(one("2e+4")?.value, 20_000)
        XCTAssertEqual(one("3e5")?.step, 100_000)
        XCTAssertEqual(one("3e")?.role, .identifier)
        XCTAssertEqual(one("1e5x")?.role, .identifier)
        XCTAssertEqual(one("version 1.2.3-beta is out")?.role, .identifier)
        XCTAssertEqual(one("1.2.3")?.text, "1.2.3")
        XCTAssertEqual(one("0")?.significantDigits, 1)
    }

    func testTrailingZerosAndPlainIntegers() throws {
        XCTAssertEqual(one("1,200 users")?.trailingZeros, 2)
        XCTAssertEqual(one("000")?.trailingZeros, 0)
        XCTAssertEqual(one("1.0")?.trailingZeros, 0)
        XCTAssertEqual(one("7")?.isPlainInteger, true)
        XCTAssertEqual(one("7.5")?.isPlainInteger, false)
        XCTAssertEqual(one("7%")?.isPlainInteger, false)
        XCTAssertEqual(one("7k")?.isPlainInteger, false)
    }

    func testSignsAndCurrency() throws {
        XCTAssertEqual(one("-41.5")?.value, -41.5)
        XCTAssertEqual(one("(−3)")?.value, -3)
        XCTAssertEqual(one(#"{"delta":-3}"#)?.value, -3)
        XCTAssertEqual(figures("pages 3-4 and 7").map(\.value), [3, 4, 7])
        let price = try XCTUnwrap(one("costs $1,450.50"))
        XCTAssertEqual(price.unit?.symbol, "USD")
        XCTAssertEqual(price.text, "$1,450.50")
        XCTAssertEqual(one("-$5")?.value, -5)
        XCTAssertEqual(one("₹12,34,567")?.unit?.family, "currency:INR")
    }

    func testScales() throws {
        XCTAssertEqual(one("5k users")?.value, 5_000)
        XCTAssertEqual(one("1.2M rows")?.value, 1_200_000)
        XCTAssertEqual(one("1.2M rows")?.step ?? 0, 100_000, accuracy: 1e-6)
        XCTAssertEqual(one("$5m")?.scale, .million)
        XCTAssertEqual(one("5m")?.unit?.symbol, "m")
        XCTAssertEqual(one("$2B")?.scale, .billion)
        XCTAssertEqual(one("10B")?.unit?.symbol, "B")
        XCTAssertEqual(one("₹5cr")?.scale, .crore)
        XCTAssertEqual(one("$1.2 million")?.value, 1_200_000)
        XCTAssertEqual(one("3 lakh")?.value, 300_000)
        XCTAssertEqual(one("2 billion dollars")?.unit?.symbol, "USD")
        XCTAssertEqual(one("1.2 million users")?.unit, nil)
        for scale in Scale.allCases {
            XCTAssertGreaterThanOrEqual(scale.multiplier, 1)
        }
    }

    func testPercentForms() {
        XCTAssertEqual(one("5.7%")?.isPercent, true)
        XCTAssertEqual(one("5.7 %")?.text, "5.7 %")
        XCTAssertEqual(one("5 percent")?.isPercent, true)
        XCTAssertEqual(one("5 pct")?.isPercent, true)
        XCTAssertEqual(one("5 per cent of")?.text, "5 per cent")
        XCTAssertEqual(one("1.4 percentage points")?.isPercent, true)
        XCTAssertEqual(one("5 per day")?.isPercent, false)
        XCTAssertEqual(one("5% percent")?.text, "5%")
    }

    func testUnits() {
        XCTAssertEqual(one("1480 ms")?.unit?.symbol, "ms")
        XCTAssertEqual(one("1480ms")?.unit?.symbol, "ms")
        XCTAssertEqual(one("2 Seconds")?.unit?.symbol, "s")
        XCTAssertEqual(one("5 mb")?.unit?.symbol, "MB")
        XCTAssertEqual(one("5 s")?.unit, nil)
        XCTAssertEqual(one("21°C")?.unit?.symbol, "°C")
        XCTAssertEqual(one("21°X")?.unit, nil)
        XCTAssertEqual(one("$5 USD")?.unit?.symbol, "USD")
        XCTAssertEqual(one("3 apples")?.unit, nil)
        XCTAssertEqual(one("3 x")?.unit, nil)
        XCTAssertEqual(one("10x faster")?.unit?.family, "multiple")
    }

    func testRolesAndNames() {
        XCTAssertEqual(one("the 2nd pass")?.role, .ordinal)
        XCTAssertEqual(one("the 1990s")?.role, .identifier)
        XCTAssertEqual(one("the 80s")?.role, .identifier)
        XCTAssertEqual(one("took 5s")?.unit?.symbol, "s")
        XCTAssertEqual(one("3D printing")?.role, .identifier)
        XCTAssertEqual(one("on iOS 17")?.role, .identifier)
        XCTAssertEqual(one("in 2026")?.role, .year)
        XCTAssertEqual(one("2,026 items")?.role, .quantity)
        XCTAssertEqual(one("2500")?.role, .quantity)
        XCTAssertEqual(one("0999")?.role, .quantity)
        XCTAssertTrue(figures("GPT-4o, v2, /2019/, #42, user_7, a@3, x.5").isEmpty)
    }

    func testMarkers() {
        let list = figures("1. first\n  2) second\n\t3. third\nThere were 3. Then 4.")
        XCTAssertEqual(list.map(\.role), [.listMarker, .listMarker, .listMarker, .quantity, .quantity])
        XCTAssertEqual(one("1.")?.role, .listMarker)
        XCTAssertEqual(one("as shown [4].")?.role, .citation)
        XCTAssertEqual(figures("[4, 5").map(\.role), [.quantity, .quantity])
    }

    func testClocks() throws {
        XCTAssertEqual(one("at 14:30")?.value, 52_200)
        XCTAssertEqual(one("at 14:30")?.step, 60)
        XCTAssertEqual(one("at 14:30:05")?.value, 52_205)
        XCTAssertEqual(one("at 2:30 PM")?.value, 52_200)
        XCTAssertEqual(one("at 9 a.m.")?.value, 32_400)
        XCTAssertEqual(one("at 9 a.m.")?.step, 3_600)
        XCTAssertEqual(one("12 AM")?.value, 0)
        XCTAssertEqual(one("2:30pm")?.role, .clock)
        XCTAssertEqual(one("13 PM")?.role, .quantity)
        XCTAssertEqual(figures("25:00").map(\.role), [.quantity, .quantity])
        XCTAssertEqual(figures("12:60").map(\.role), [.quantity, .quantity])
        XCTAssertEqual(figures("123:45").count, 2)
        XCTAssertEqual(figures("ratio 16:9").map(\.value), [16, 9])
        XCTAssertEqual(one("5 apples")?.role, .quantity)
        XCTAssertEqual(one("5 amps")?.role, .quantity)
        XCTAssertEqual(one("5 a.x")?.role, .quantity)
    }

    func testISOTimestamps() {
        XCTAssertEqual(figures("2026-10-23").map(\.role), [.year, .quantity, .quantity])
        XCTAssertEqual(figures("2026-10-23T14:30:05Z").map(\.value), [2026, 10, 23, 52_205])
        XCTAssertEqual(figures("2026-10-23T14:30:05.123+05:30 ok").count, 4)
        XCTAssertEqual(figures("2026-10-23 14:30+0530").count, 4)
        XCTAssertEqual(figures("2026-10-23T14:30+05").map(\.value), [2026, 10, 23, 52_200, 5])
        XCTAssertEqual(figures("2026-10-23T14:30+05:3").map(\.value), [2026, 10, 23, 52_200, 5, 3])
        XCTAssertEqual(figures("2026-10-23T9").count, 3)
        XCTAssertEqual(figures("2026-10-2").map(\.value), [2026, 10, 2])
        XCTAssertEqual(figures("2026-1").map(\.value), [2026, 1])
        XCTAssertEqual(figures("2026-10").map(\.value), [2026, 10])
        XCTAssertEqual(figures("2026-10-23T14:30-05:00 ok").count, 4)
        XCTAssertTrue(figures("v2.").isEmpty)
        XCTAssertEqual(figures("2026-10-23T14:30 ok").count, 4)
        XCTAssertEqual(RawFigure(start: 0, end: 0).value, 0)
    }

    func testQualifiers() {
        XCTAssertEqual(one("~5")?.qualifier, .approximately)
        XCTAssertEqual(one("≈ 5")?.qualifier, .approximately)
        XCTAssertEqual(one("> 1,000")?.qualifier, .atLeast)
        XCTAssertEqual(one("≤5")?.qualifier, .atMost)
        XCTAssertEqual(one("about $5")?.qualifier, .approximately)
        XCTAssertEqual(one("more than 5")?.qualifier, .atLeast)
        XCTAssertEqual(one("no more than 5")?.qualifier, .atMost)
        XCTAssertEqual(one("in excess of 5")?.qualifier, .atLeast)
        XCTAssertEqual(one("under 5")?.qualifier, .atMost)
        XCTAssertEqual(one("exactly 5")?.qualifier, nil)
        XCTAssertEqual(one("about,5")?.qualifier, nil)
        XCTAssertNil(Qualifier(precedingWords: []))
    }

    func testLabels() throws {
        let json = figures(#"{"conversion_rate":0.057,"sessions":48210}"#)
        XCTAssertEqual(json.map(\.label), [["conversion", "rate"], ["sessions"]])
        let prose = figures("Churn was 4.3%, revenue 1,265! Done? Yes; ok.\nnew {x} 7")
        XCTAssertEqual(prose[0].label, ["churn"])
        XCTAssertEqual(prose[1].label, ["revenue"])
        let neighbours = figures("1,200 users and 1,400 seats")
        XCTAssertEqual(neighbours.map(\.label), [["users"], ["seats"]])
        XCTAssertEqual(figures("1,200 in revenue and 1,400 seats").map(\.label), [["revenue"], ["revenue", "seats"]])
        XCTAssertEqual(figures("1-2").map(\.label), [[], []])
        XCTAssertEqual(one(#"say "it was 5." twice"#)?.label, ["say"])
        XCTAssertEqual(one("total 5.")?.label, ["total"])
        XCTAssertTrue(LabelIndex.endsClause(Array("a.b"), at: 1) == false)
        XCTAssertTrue(LabelIndex.endsClause(Array(","), at: 0))
        XCTAssertFalse(LabelIndex.endsClause(Array("1,2"), at: 1))
    }
}
