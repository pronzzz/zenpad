import SwiftUI

// MARK: - Code Toolbar with Format Actions

struct CodeToolbar: View {
    @Binding var text: String
    @Binding var language: SyntaxHighlighter.Language
    @Binding var enableRegex: Bool
    @Binding var caseSensitive: Bool
    @Binding var wholeWord: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Language picker
            Picker("Language", selection: $language) {
                ForEach(SyntaxHighlighter.Language.allCases, id: \.self) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            Divider()
                .frame(height: 16)
            
            // Format actions
            Menu {
                Button("Format JSON") {
                    formatJSON()
                }
                .disabled(language != .json)
                
                Button("Sort Lines") {
                    sortLines()
                }
                
                Button("Remove Duplicate Lines") {
                    removeDuplicateLines()
                }
                
                Divider()
                
                Button("Trim Whitespace") {
                    trimWhitespace()
                }
                
                Button("Convert to Uppercase") {
                    text = text.uppercased()
                }
                
                Button("Convert to Lowercase") {
                    text = text.lowercased()
                }
            } label: {
                Label("Format", systemImage: "text.alignleft")
            }
            .menuStyle(.borderlessButton)
            
            Spacer()
            
            // Search options
            Toggle("Regex", isOn: $enableRegex)
                .toggleStyle(.button)
                .controlSize(.small)
            
            Toggle("Aa", isOn: $caseSensitive)
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Case Sensitive")
            
            Toggle("\\b", isOn: $wholeWord)
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Whole Word")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Format Actions
    
    private func formatJSON() {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            if let prettyString = String(data: prettyData, encoding: .utf8) {
                text = prettyString
            }
        } catch {
            print("JSON format error: \(error)")
        }
    }
    
    private func sortLines() {
        let lines = text.components(separatedBy: .newlines)
        let sorted = lines.sorted()
        text = sorted.joined(separator: "\n")
    }
    
    private func removeDuplicateLines() {
        let lines = text.components(separatedBy: .newlines)
        var seen = Set<String>()
        var unique: [String] = []
        
        for line in lines {
            if !seen.contains(line) {
                seen.insert(line)
                unique.append(line)
            }
        }
        
        text = unique.joined(separator: "\n")
    }
    
    private func trimWhitespace() {
        let lines = text.components(separatedBy: .newlines)
        let trimmed = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        text = trimmed.joined(separator: "\n")
    }
}

// MARK: - Enhanced Search Bar with Regex Support

struct EnhancedSearchBar: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var isVisible: Bool
    @Binding var enableRegex: Bool
    @Binding var caseSensitive: Bool
    @Binding var wholeWord: Bool
    
    let matchCount: Int
    let currentMatch: Int
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onReplace: () -> Void
    let onReplaceAll: () -> Void
    
    @State private var showReplace = false
    @State private var regexError: String?
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Search field
                HStack(spacing: 4) {
                    Image(systemName: enableRegex ? "number" : "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(regexError != nil ? .red : .secondary)
                    
                    TextField(enableRegex ? "Regex pattern..." : "Find...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: enableRegex ? .monospaced : .default))
                        .focused($isSearchFocused)
                        .onSubmit { onFindNext() }
                    
                    if !searchText.isEmpty {
                        Text("\(currentMatch)/\(matchCount)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(regexError != nil ? Color.red : Color(NSColor.separatorColor), lineWidth: 1)
                        )
                )
                
                // Search options
                HStack(spacing: 4) {
                    OptionButton(label: ".*", isActive: $enableRegex, help: "Regular Expression")
                    OptionButton(label: "Aa", isActive: $caseSensitive, help: "Case Sensitive")
                    OptionButton(label: "\\b", isActive: $wholeWord, help: "Whole Word")
                }
                
                // Navigation
                HStack(spacing: 2) {
                    Button(action: onFindPrevious) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                    
                    Button(action: onFindNext) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24, height: 24)
                }
                .disabled(matchCount == 0)
                
                // Replace toggle
                Button(action: { withAnimation { showReplace.toggle() } }) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 12))
                        .foregroundColor(showReplace ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Regex error
            if let error = regexError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                    Spacer()
                }
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            
            // Replace row
            if showReplace {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        TextField("Replace with...", text: $replaceText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    )
                    
                    Button("Replace") { onReplace() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(matchCount == 0)
                    
                    Button("All") { onReplaceAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(matchCount == 0)
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .onChange(of: searchText) { _ in validateRegex() }
        .onChange(of: enableRegex) { _ in validateRegex() }
        .onAppear { isSearchFocused = true }
    }
    
    private func validateRegex() {
        guard enableRegex && !searchText.isEmpty else {
            regexError = nil
            return
        }
        
        do {
            _ = try NSRegularExpression(pattern: searchText, options: caseSensitive ? [] : .caseInsensitive)
            regexError = nil
        } catch {
            regexError = "Invalid regex pattern"
        }
    }
}

struct OptionButton: View {
    let label: String
    @Binding var isActive: Bool
    let help: String
    
    var body: some View {
        Button(action: { isActive.toggle() }) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(isActive ? .white : .secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

#Preview("Code Toolbar") {
    CodeToolbar(
        text: .constant("Test"),
        language: .constant(.json),
        enableRegex: .constant(false),
        caseSensitive: .constant(false),
        wholeWord: .constant(false)
    )
}

#Preview("Enhanced Search") {
    EnhancedSearchBar(
        searchText: .constant("test"),
        replaceText: .constant(""),
        isVisible: .constant(true),
        enableRegex: .constant(true),
        caseSensitive: .constant(false),
        wholeWord: .constant(false),
        matchCount: 5,
        currentMatch: 2,
        onFindNext: {},
        onFindPrevious: {},
        onReplace: {},
        onReplaceAll: {}
    )
}
