# Changelog

All notable changes to ZenPad are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [2.0.0] - 2026-10-29

ZenPad 2 is a ground-up rewrite. It is smaller, calmer and faster, lives in your menu bar, and keeps every note as a plain Markdown file you own.

### Highlights

- **Quick Pad.** Click the menu bar icon (or press `⌃⌥N` anywhere) for a small scratch pad that drops down under the icon. Jot something, press `⌘↩` to save it as a note, or expand it into the full editor. No Dock icon until you open the editor window.
- **Global shortcuts.** `⌃⌥N` shows the Quick Pad and `⌃⌥Z` opens the editor from any app. Both can be re-recorded in Settings → Shortcuts.
- **Full Markdown.** GitHub Flavored Markdown with tables, task lists, strikethrough, footnotes, `> [!NOTE]` alerts, autolinks and syntax-highlighted code blocks, rendered by Apple's `swift-markdown` parser instead of regular expressions.
- **Live styling while you type.** Headings grow, emphasis turns bold or italic, links turn blue, code gets a soft background and quotes get a margin bar, while the Markdown characters stay visible but quiet.
- **Write, Split and Preview** (`⌘1` `⌘2` `⌘3`) with a smooth animated split, scroll sync, and checkboxes you can tick right in the preview.
- **Fonts.** New York, SF Pro, SF Pro Rounded and SF Mono, plus curated families when installed (Charter, Iowan Old Style, Palatino, Avenir Next and more). Size, line height and line width are adjustable, and the preview uses the same font.
- **Automatic updates from GitHub.** ZenPad checks this repository's releases once a day, shows the release notes, and installs the new version with one click. Every update is verified with an Ed25519 signature, its bundle identifier and its code signature before it replaces the app.
- **New icon and interface.** An ink ensō icon, a translucent sidebar, a quieter header and softer spring animations throughout.

### Writing

- Notes are plain `.md` files in a folder you choose (default `~/Documents/ZenPad`). Pick a folder inside iCloud Drive to sync between Macs. Files renamed or edited elsewhere are picked up automatically.
- A note's file name follows its first line, so there's nothing to name or save.
- Smart lists: Return continues bullets, numbers and tasks; Return on an empty item ends the list; Tab and Shift-Tab indent.
- Formatting shortcuts: `⌘B` `⌘I` `⌘K` (link), `⇧⌘K` (inline code), `⌥⌘1`–`⌥⌘3` (headings), `⇧⌘T` (toggle task).
- Click a `[ ]` in the editor to tick it; `⌘`-click a link to open it.
- Focus Mode (`⇧⌘F`) hides everything but the text and dims every paragraph except the one you're writing. Typewriter scrolling is optional.
- Outline menu for jumping between headings, native Find and Replace, word count and reading time.
- Templates: Daily Journal, Meeting Notes, To-do List, Blog Post, Project Plan and README, with `{{date}}`-style placeholders. Add your own by dropping `.md` files into the templates folder.
- Writing Assistant (`⇧⌘A`) powered by [Ollama](https://ollama.com), running entirely on your Mac: improve, fix grammar, shorten, expand, summarize, continue, change tone, suggest titles, or ask anything.
- Export to PDF or HTML, copy as HTML, print, and share.

### App

- Runs as a menu bar app. The Dock icon appears only while the editor window is open.
- Choose what happens when ZenPad opens: show the Quick Pad, open the editor, or stay quietly in the menu bar. Optional launch at login.
- Light, dark or follow the system.
- Universal app for Apple silicon and Intel Macs.

### Fixed

- The preview no longer reloads and flickers on every keystroke; it updates in place.
- Opening a file no longer creates two competing document windows.
- Find, Replace and the outline now work (they were placeholders in 1.0).

### Removed

ZenPad 2 focuses on writing. These 1.0 features were removed:

- Developer mode (line numbers, code formatters, regex tools). Code blocks inside notes are still highlighted.
- Text snippets and GitHub Gist publishing.
- Tabs and multiple windows; the sidebar replaces them.
- The custom iCloud, Handoff, Spotlight and Services integrations. Choose a folder in iCloud Drive to sync instead.

### Requirements

- macOS 14 Sonoma or later.
- ZenPad is ad-hoc signed and not notarized. The first time you open it, macOS asks you to confirm in System Settings → Privacy & Security → **Open Anyway**. Later updates install from inside the app.

## [1.0.0] - 2026-01-23

- First release: SwiftUI text editor with Markdown preview, Ollama assistant, developer mode, templates, snippets, PDF/HTML export and Gist publishing.

[2.0.0]: https://github.com/pronzzz/zenpad/releases/tag/v2.0.0
[1.0.0]: https://github.com/pronzzz/zenpad/releases/tag/v1.0.0
