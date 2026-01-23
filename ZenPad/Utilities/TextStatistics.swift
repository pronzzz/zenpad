import Foundation

struct TextStatistics {
    let text: String
    
    // Lazy computed properties for performance
    var wordCount: Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    var characterCount: Int {
        text.count
    }
    
    var characterCountWithoutSpaces: Int {
        text.filter { !$0.isWhitespace }.count
    }
    
    var lineCount: Int {
        if text.isEmpty { return 0 }
        return text.components(separatedBy: .newlines).count
    }
    
    var paragraphCount: Int {
        let paragraphs = text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return paragraphs.count
    }
    
    var readingTime: String {
        let wordsPerMinute = 200.0
        let minutes = Double(wordCount) / wordsPerMinute
        
        if minutes < 1 {
            let seconds = Int(minutes * 60)
            return "\(seconds)s"
        } else if minutes < 60 {
            return "\(Int(minutes))m"
        } else {
            let hours = Int(minutes / 60)
            let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    var speakingTime: String {
        let wordsPerMinute = 150.0
        let minutes = Double(wordCount) / wordsPerMinute
        
        if minutes < 1 {
            let seconds = Int(minutes * 60)
            return "\(seconds)s"
        } else if minutes < 60 {
            return "\(Int(minutes))m"
        } else {
            let hours = Int(minutes / 60)
            let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}
