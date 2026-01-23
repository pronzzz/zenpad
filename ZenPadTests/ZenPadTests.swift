import XCTest
@testable import ZenPad

final class TextStatisticsTests: XCTestCase {
    
    func testEmptyText() {
        let stats = TextStatistics(text: "")
        XCTAssertEqual(stats.wordCount, 0)
        XCTAssertEqual(stats.characterCount, 0)
        XCTAssertEqual(stats.lineCount, 0)
        XCTAssertEqual(stats.paragraphCount, 0)
    }
    
    func testSingleWord() {
        let stats = TextStatistics(text: "Hello")
        XCTAssertEqual(stats.wordCount, 1)
        XCTAssertEqual(stats.characterCount, 5)
        XCTAssertEqual(stats.characterCountWithoutSpaces, 5)
    }
    
    func testSentence() {
        let stats = TextStatistics(text: "Hello, world!")
        XCTAssertEqual(stats.wordCount, 2)
        XCTAssertEqual(stats.characterCount, 13)
    }
    
    func testMultipleLines() {
        let stats = TextStatistics(text: "Line 1\nLine 2\nLine 3")
        XCTAssertEqual(stats.lineCount, 3)
        XCTAssertEqual(stats.wordCount, 6)
    }
    
    func testParagraphs() {
        let stats = TextStatistics(text: "Paragraph one.\n\nParagraph two.\n\nParagraph three.")
        XCTAssertEqual(stats.paragraphCount, 3)
    }
    
    func testReadingTime() {
        // 200 words = 1 minute
        let words = Array(repeating: "word", count: 200).joined(separator: " ")
        let stats = TextStatistics(text: words)
        XCTAssertEqual(stats.readingTime, "1m")
    }
    
    func testReadingTimeShort() {
        let stats = TextStatistics(text: "Just a few words here")
        XCTAssertTrue(stats.readingTime.hasSuffix("s"))
    }
}

final class DocumentTests: XCTestCase {
    
    func testDefaultDocument() {
        let doc = Document()
        XCTAssertEqual(doc.title, "Untitled")
        XCTAssertEqual(doc.content, "")
        XCTAssertNil(doc.filePath)
        XCTAssertFalse(doc.isModified)
        XCTAssertEqual(doc.fileType, .plainText)
    }
    
    func testFileTypeDetection() {
        let txtURL = URL(fileURLWithPath: "/test/file.txt")
        let mdURL = URL(fileURLWithPath: "/test/file.md")
        
        XCTAssertEqual(Document.detectFileType(from: txtURL), .plainText)
        XCTAssertEqual(Document.detectFileType(from: mdURL), .markdown)
    }
    
    func testDisplayTitleModified() {
        var doc = Document(title: "Test")
        XCTAssertEqual(doc.displayTitle, "Test")
        
        doc.isModified = true
        XCTAssertEqual(doc.displayTitle, "• Test")
    }
    
    func testDocumentEquality() {
        let id = UUID()
        let doc1 = Document(id: id, title: "Test 1")
        let doc2 = Document(id: id, title: "Test 2")
        
        XCTAssertEqual(doc1, doc2) // Same ID means equal
    }
}
