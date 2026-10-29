import Foundation

/// A starting point for a new note. Built-ins plus any .md file in the Templates folder.
struct NoteTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let summary: String
    let body: String

    /// Fills in {{date}}, {{time}}, {{weekday}} and {{datetime}}.
    func expanded(now: Date = Date()) -> String {
        let date = now.formatted(date: .long, time: .omitted)
        let time = now.formatted(date: .omitted, time: .shortened)
        let weekday = now.formatted(.dateTime.weekday(.wide))
        return body
            .replacingOccurrences(of: "{{date}}", with: date)
            .replacingOccurrences(of: "{{time}}", with: time)
            .replacingOccurrences(of: "{{weekday}}", with: weekday)
            .replacingOccurrences(of: "{{datetime}}", with: "\(date), \(time)")
    }
}

enum Templates {
    static var folder: URL {
        let dir = Runtime.supportDirectory.appendingPathComponent("Templates", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var all: [NoteTemplate] { builtIn + custom }

    static var custom: [NoteTemplate] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension.lowercased() == "md" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { url in
            guard let body = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            return NoteTemplate(id: "custom:\(name)", name: name, symbol: "doc.badge.plus", summary: "Your template", body: body)
        }
    }

    static let builtIn: [NoteTemplate] = [
        NoteTemplate(id: "blank", name: "Blank", symbol: "doc", summary: "An empty page", body: ""),
        NoteTemplate(id: "journal", name: "Daily Journal", symbol: "sun.max", summary: "Gratitude, focus and reflection", body: """
        # {{weekday}}, {{date}}

        ## Grateful for
        -

        ## Today's focus
        - [ ]

        ## Notes


        ## Reflection

        """),
        NoteTemplate(id: "meeting", name: "Meeting Notes", symbol: "person.2", summary: "Agenda, decisions and action items", body: """
        # Meeting — {{date}}

        **Attendees:**

        ## Agenda
        1.

        ## Notes


        ## Decisions
        -

        ## Action items
        - [ ]
        """),
        NoteTemplate(id: "todo", name: "To-do List", symbol: "checklist", summary: "A simple checklist", body: """
        # To do

        - [ ]
        """),
        NoteTemplate(id: "blog", name: "Blog Post", symbol: "text.quote", summary: "Title, hook, sections and a wrap-up", body: """
        ---
        title:
        date: {{date}}
        tags: []
        ---

        # Title

        > A one-sentence hook.

        ## Introduction


        ## Main points


        ## Conclusion

        """),
        NoteTemplate(id: "project", name: "Project Plan", symbol: "flag", summary: "Goals, milestones and risks", body: """
        # Project:

        ## Goal


        ## Milestones
        | Milestone | Owner | Due |
        | --------- | ----- | --- |
        |           |       |     |

        ## Risks
        > [!WARNING]
        >

        ## Next steps
        - [ ]
        """),
        NoteTemplate(id: "readme", name: "README", symbol: "book.closed", summary: "For a code project", body: """
        # Project name

        One line about what this does.

        ## Install

        ```sh

        ```

        ## Usage

        ```sh

        ```

        ## License

        MIT
        """),
    ]
}
