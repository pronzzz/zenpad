import AppKit

/// Builds the menu bar in code (there's no storyboard). Items target nil so they follow the
/// responder chain: Format commands reach the focused editor, app commands reach AppDelegate.
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(appMenu()))
        main.addItem(submenu(fileMenu()))
        main.addItem(submenu(editMenu()))
        main.addItem(submenu(formatMenu()))
        main.addItem(submenu(viewMenu()))
        let window = windowMenu()
        main.addItem(submenu(window))
        NSApp.windowsMenu = window
        let help = helpMenu()
        main.addItem(submenu(help))
        NSApp.helpMenu = help
        return main
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func item(_ title: String, _ action: String, _ key: String = "", _ mods: NSEvent.ModifierFlags = .command, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: Selector(action), keyEquivalent: key)
        item.keyEquivalentModifierMask = key.isEmpty ? [] : mods
        item.tag = tag
        return item
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "ZenPad")
        menu.addItem(item("About ZenPad", "showAbout:"))
        menu.addItem(item("Check for Updates…", "checkForUpdates:"))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", "showSettings:", ","))
        menu.addItem(.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        services.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        menu.addItem(services)
        menu.addItem(.separator())
        menu.addItem(item("Hide ZenPad", "hide:", "h"))
        menu.addItem(item("Hide Others", "hideOtherApplications:", "h", [.command, .option]))
        menu.addItem(item("Show All", "unhideAllApplications:"))
        menu.addItem(.separator())
        menu.addItem(item("Quit ZenPad", "terminate:", "q"))
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(item("New Note", "newNote:", "n"))
        menu.addItem(item("New from Template…", "newFromTemplate:", "n", [.command, .shift]))
        menu.addItem(item("Open…", "openDocument:", "o"))
        menu.addItem(.separator())
        menu.addItem(item("Close", "performClose:", "w"))
        menu.addItem(item("Save", "saveNote:", "s"))
        menu.addItem(item("Save As…", "saveNoteAs:", "s", [.command, .shift]))
        menu.addItem(item("Duplicate", "duplicateNote:"))
        menu.addItem(.separator())
        menu.addItem(item("Export as PDF…", "exportPDF:", "e", [.command, .shift]))
        menu.addItem(item("Export as HTML…", "exportHTML:", "e", [.command, .shift, .option]))
        menu.addItem(.separator())
        menu.addItem(item("Print…", "printNote:", "p"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(item("Undo", "undo:", "z"))
        menu.addItem(item("Redo", "redo:", "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Cut", "cut:", "x"))
        menu.addItem(item("Copy", "copy:", "c"))
        menu.addItem(item("Paste", "paste:", "v"))
        menu.addItem(item("Paste and Match Style", "pasteAsPlainText:", "v", [.command, .option, .shift]))
        menu.addItem(item("Delete", "delete:"))
        menu.addItem(item("Select All", "selectAll:", "a"))
        menu.addItem(.separator())

        let find = NSMenu(title: "Find")
        find.addItem(item("Find…", "performTextFinderAction:", "f", tag: NSTextFinder.Action.showFindInterface.rawValue))
        find.addItem(item("Find and Replace…", "performTextFinderAction:", "f", [.command, .option], tag: NSTextFinder.Action.showReplaceInterface.rawValue))
        find.addItem(item("Find Next", "performTextFinderAction:", "g", tag: NSTextFinder.Action.nextMatch.rawValue))
        find.addItem(item("Find Previous", "performTextFinderAction:", "g", [.command, .shift], tag: NSTextFinder.Action.previousMatch.rawValue))
        find.addItem(item("Use Selection for Find", "performTextFinderAction:", "e", tag: NSTextFinder.Action.setSearchString.rawValue))
        find.addItem(item("Jump to Selection", "centerSelectionInVisibleArea:", "j"))
        find.addItem(.separator())
        find.addItem(item("Search All Notes…", "searchNotes:", "l", [.command, .shift]))
        menu.addItem(submenu(find))

        let spelling = NSMenu(title: "Spelling and Grammar")
        spelling.addItem(item("Show Spelling and Grammar", "showGuessPanel:", ":"))
        spelling.addItem(item("Check Document Now", "checkSpelling:", ";"))
        spelling.addItem(item("Check Spelling While Typing", "toggleContinuousSpellChecking:"))
        menu.addItem(submenu(spelling))
        return menu
    }

    private static func formatMenu() -> NSMenu {
        let menu = NSMenu(title: "Format")
        menu.addItem(item("Bold", "toggleBoldMarkdown:", "b"))
        menu.addItem(item("Italic", "toggleItalicMarkdown:", "i"))
        menu.addItem(item("Strikethrough", "toggleStrikethroughMarkdown:", "x", [.command, .shift]))
        menu.addItem(item("Highlight", "toggleHighlightMarkdown:", "h", [.command, .shift]))
        menu.addItem(item("Inline Code", "toggleInlineCodeMarkdown:", "k", [.command, .shift]))
        menu.addItem(item("Link", "insertLinkMarkdown:", "k"))
        menu.addItem(.separator())
        menu.addItem(item("Heading 1", "heading1Markdown:", "1", [.command, .option]))
        menu.addItem(item("Heading 2", "heading2Markdown:", "2", [.command, .option]))
        menu.addItem(item("Heading 3", "heading3Markdown:", "3", [.command, .option]))
        menu.addItem(item("Body Text", "bodyTextMarkdown:", "0", [.command, .option]))
        menu.addItem(.separator())
        menu.addItem(item("Bulleted List", "toggleBulletListMarkdown:", "8", [.command, .shift]))
        menu.addItem(item("Numbered List", "toggleNumberedListMarkdown:", "7", [.command, .shift]))
        menu.addItem(item("Task", "toggleTaskMarkdown:", "t", [.command, .shift]))
        menu.addItem(item("Quote", "toggleQuoteMarkdown:", "'"))
        menu.addItem(.separator())
        menu.addItem(item("Code Block", "insertCodeBlockMarkdown:", "c", [.command, .option]))
        menu.addItem(item("Table", "insertTableMarkdown:", "t", [.command, .option]))
        menu.addItem(item("Horizontal Rule", "insertRuleMarkdown:"))
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(item("Write", "modeWrite:", "1"))
        menu.addItem(item("Split", "modeSplit:", "2"))
        menu.addItem(item("Preview", "modePreview:", "3"))
        menu.addItem(.separator())
        menu.addItem(item("Hide Sidebar", "toggleSidebarPane:", "s", [.command, .control]))
        menu.addItem(item("Focus Mode", "toggleFocusMode:", "f", [.command, .shift]))
        menu.addItem(item("Typewriter Scrolling", "toggleTypewriter:", "t", [.command, .control]))
        menu.addItem(item("Writing Assistant", "toggleAssistant:", "a", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Bigger", "fontBigger:", "+"))
        let equals = item("Bigger", "fontBigger:", "=")
        equals.isHidden = true
        equals.allowsKeyEquivalentWhenHidden = true
        menu.addItem(equals)
        menu.addItem(item("Smaller", "fontSmaller:", "-"))
        menu.addItem(item("Actual Size", "fontReset:", "0"))
        menu.addItem(.separator())
        menu.addItem(item("Enter Full Screen", "toggleFullScreen:", "f", [.command, .control]))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(item("Minimize", "performMiniaturize:", "m"))
        menu.addItem(item("Zoom", "performZoom:"))
        menu.addItem(.separator())
        menu.addItem(item("Quick Pad", "showQuickPad:"))
        menu.addItem(item("ZenPad Editor", "showEditor:"))
        menu.addItem(.separator())
        menu.addItem(item("Bring All to Front", "arrangeInFront:"))
        return menu
    }

    private static func helpMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        menu.addItem(item("ZenPad on GitHub", "openWebsite:"))
        menu.addItem(item("Release Notes", "openReleaseNotes:"))
        menu.addItem(item("Markdown Guide", "markdownGuide:"))
        menu.addItem(.separator())
        menu.addItem(item("Report an Issue…", "reportIssue:"))
        return menu
    }
}
