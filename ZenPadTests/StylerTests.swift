import AppKit
import XCTest
@testable import ZenPad

final class StylerTests: XCTestCase {
    func testQuoteAndCodeGetBlockAttributes() {
        let (_, tv) = ZenTextView.makeScrollable(theme: .main(from: .shared))
        tv.setText("Intro\n\n> quoted line\n> second\n\n```\ncode\n```\n")
        let storage = tv.textStorage!
        let ns = storage.string as NSString
        let q = ns.range(of: "quoted").location
        XCTAssertEqual(storage.attribute(.zenBlock, at: q, effectiveRange: nil) as? String, "quote")
        let c = ns.range(of: "code").location
        XCTAssertEqual(storage.attribute(.zenBlock, at: c, effectiveRange: nil) as? String, "code")
    }

    func testTaskCheckboxAttribute() {
        let (_, tv) = ZenTextView.makeScrollable(theme: .main(from: .shared))
        tv.setText("- [x] done\n- [ ] todo")
        let storage = tv.textStorage!
        XCTAssertEqual(storage.attribute(.zenTask, at: 3, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(storage.attribute(.zenTask, at: 14, effectiveRange: nil) as? Bool, false)
    }
}
