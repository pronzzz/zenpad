import CryptoKit
import XCTest
@testable import ZenPad

final class MarkdownRendererTests: XCTestCase {
    func testHeadingsGetAnchors() {
        let html = MarkdownRenderer.html(from: "# Hello World\n\n## Hello World")
        XCTAssertTrue(html.contains("<h1 id=\"hello-world\""))
        XCTAssertTrue(html.contains("<h2 id=\"hello-world-1\""))
    }

    func testInlineFormatting() {
        let html = MarkdownRenderer.html(from: "**bold** _italic_ ~~gone~~ `code`")
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
        XCTAssertTrue(html.contains("<del>gone</del>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
    }

    func testTaskListsCarryLineNumbers() {
        let html = MarkdownRenderer.html(from: "Intro\n\n- [ ] open\n- [x] done")
        XCTAssertTrue(html.contains("<ul class=\"tasks\""))
        XCTAssertTrue(html.contains("data-line=\"3\">"))
        XCTAssertTrue(html.contains("type=\"checkbox\" data-line=\"4\" checked"))
    }

    func testTablesWithAlignment() {
        let html = MarkdownRenderer.html(from: "| a | b |\n| :- | -: |\n| 1 | 2 |")
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th style=\"text-align:left\">a</th>"))
        XCTAssertTrue(html.contains("<td style=\"text-align:right\">2</td>"))
    }

    func testFencedCodeIsHighlighted() {
        let html = MarkdownRenderer.html(from: "```swift\nlet x = 1 // note\n```")
        XCTAssertTrue(html.contains("class=\"language-swift\""))
        XCTAssertTrue(html.contains("<span class=\"tok-k\">let</span>"))
        XCTAssertTrue(html.contains("<span class=\"tok-c\">// note</span>"))
    }

    func testAlerts() {
        let html = MarkdownRenderer.html(from: "> [!WARNING]\n> Careful now")
        XCTAssertTrue(html.contains("class=\"alert alert-warning\""))
        XCTAssertTrue(html.contains("Careful now"))
        XCTAssertFalse(html.contains("[!WARNING]"))
    }

    func testFootnotes() {
        let html = MarkdownRenderer.html(from: "Claim.[^a]\n\n[^a]: Source here.")
        XCTAssertTrue(html.contains("href=\"#fn-a\""))
        XCTAssertTrue(html.contains("<li id=\"fn-a\">Source here."))
    }

    func testScriptsAreStripped() {
        let html = MarkdownRenderer.html(from: "<script>alert(1)</script>\n\n<img src=x onerror=\"alert(1)\">\n\n[x](javascript:alert(1))")
        XCTAssertFalse(html.contains("<script"))
        XCTAssertFalse(html.contains("onerror"))
        XCTAssertFalse(html.contains("javascript:"))
    }
}

final class MarkdownEditingTests: XCTestCase {
    func testBulletContinues() {
        let text = "- one" as NSString
        let edit = MarkdownEditing.newline(in: text, selection: NSRange(location: 5, length: 0))
        XCTAssertEqual(edit?.replacement, "\n- ")
    }

    func testNumberedListIncrements() {
        let text = "9. nine" as NSString
        XCTAssertEqual(MarkdownEditing.newline(in: text, selection: NSRange(location: 7, length: 0))?.replacement, "\n10. ")
    }

    func testTaskContinuesUnchecked() {
        let text = "- [x] done" as NSString
        XCTAssertEqual(MarkdownEditing.newline(in: text, selection: NSRange(location: 10, length: 0))?.replacement, "\n- [ ] ")
    }

    func testEmptyItemEndsList() {
        let text = "- one\n- " as NSString
        let edit = MarkdownEditing.newline(in: text, selection: NSRange(location: 8, length: 0))
        XCTAssertEqual(edit?.replacement, "")
        XCTAssertEqual(edit?.range, NSRange(location: 6, length: 2))
    }

    func testPlainLineDoesNothing() {
        XCTAssertNil(MarkdownEditing.newline(in: "hello" as NSString, selection: NSRange(location: 5, length: 0)))
    }

    func testToggleBoldWrapsAndUnwraps() {
        let text = "make this bold" as NSString
        let wrapped = MarkdownEditing.toggleWrap(in: text, selection: NSRange(location: 10, length: 4), marker: "**")
        XCTAssertEqual(wrapped.replacement, "**bold**")
        let after = text.replacingCharacters(in: wrapped.range, with: wrapped.replacement) as NSString
        let unwrapped = MarkdownEditing.toggleWrap(in: after, selection: wrapped.selection, marker: "**")
        XCTAssertEqual(after.replacingCharacters(in: unwrapped.range, with: unwrapped.replacement), "make this bold")
    }

    func testHeadingToggle() {
        let text = "Title" as NSString
        let edit = MarkdownEditing.setLineStyle(in: text, selection: NSRange(location: 0, length: 0), style: .heading(2))
        XCTAssertEqual(edit.replacement, "## Title")
        let again = MarkdownEditing.setLineStyle(in: "## Title" as NSString, selection: NSRange(location: 3, length: 0), style: .heading(2))
        XCTAssertEqual(again.replacement, "Title")
    }

    func testToggleTaskByLine() {
        XCTAssertEqual(MarkdownEditing.toggleTask(in: "a\n- [ ] b", line: 2), "a\n- [x] b")
        XCTAssertEqual(MarkdownEditing.toggleTask(in: "- [X] b", line: 1), "- [ ] b")
    }

    func testOutlineSkipsCode() {
        let headings = MarkdownEditing.headings(in: "# One\n```\n# not\n```\n## Two")
        XCTAssertEqual(headings.map(\.title), ["One", "Two"])
        XCTAssertEqual(headings.map(\.line), [1, 5])
    }
}

final class LibraryTests: XCTestCase {
    func testTitleFromFirstLine() {
        XCTAssertEqual(Library.title(from: "\n\n# **Big** idea\nbody", fallback: "x"), "Big idea")
        XCTAssertEqual(Library.title(from: "---\ntitle: x\n---\nReal title", fallback: "x"), "Real title")
        XCTAssertEqual(Library.title(from: "   ", fallback: "Untitled"), "Untitled")
    }

    func testFileNamesAreSafe() {
        XCTAssertEqual(Library.fileName(for: "a/b: c?"), "a b c")
        XCTAssertEqual(Library.fileName(for: "..hidden"), "hidden")
    }

    func testStats() {
        let stats = TextStats("Hello, world! It's ZenPad.")
        XCTAssertEqual(stats.words, 4)
    }
}

final class UpdaterTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(Updater.isNewer("2.0.1", than: "2.0.0"))
        XCTAssertTrue(Updater.isNewer("v2.1", than: "2.0.9"))
        XCTAssertTrue(Updater.isNewer("2.0.0", than: "2.0.0-beta.2"))
        XCTAssertTrue(Updater.isNewer("2.0.0-beta.10", than: "2.0.0-beta.2"))
        XCTAssertFalse(Updater.isNewer("2.0.0", than: "2.0.0"))
        XCTAssertFalse(Updater.isNewer("1.9.9", than: "2.0.0"))
    }

    func testBundledPublicKeyIsValid() throws {
        let encoded = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "ZPUpdatePublicKey") as? String)
        let data = try XCTUnwrap(Data(base64Encoded: encoded))
        XCTAssertNoThrow(try Curve25519.Signing.PublicKey(rawRepresentation: data))
    }
}

final class TemplateTests: XCTestCase {
    func testPlaceholdersExpand() {
        let template = NoteTemplate(id: "t", name: "t", symbol: "doc", summary: "", body: "{{date}} {{weekday}}")
        XCTAssertFalse(template.expanded().contains("{{"))
    }
}
