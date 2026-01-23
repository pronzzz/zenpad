# ZenPad

<div align="center">

![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![GitHub Stars](https://img.shields.io/github/stars/pronzzz/zenpad?style=social)

**An AI-First macOS Text Editor Built for Writers and Developers**

*Distraction-free writing meets powerful development tools with privacy-first local AI*

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Documentation](USER_GUIDE.md) • [License](#-license)

</div>

---

## 📖 Overview

ZenPad is a modern, native macOS text editor that combines the simplicity of distraction-free writing with powerful developer tools and local-first AI assistance. Built with **SwiftUI** and **AppKit**, it delivers a fast, native experience while keeping your data private through local AI processing via **Ollama**.

### Why ZenPad?

- **🔒 Privacy-First**: All AI processing happens locally on your Mac - your data never leaves your device
- **⚡️ Blazing Fast**: Native SwiftUI/AppKit architecture with <200ms launch time
- **🎨 Distraction-Free**: Clean, minimal interface that gets out of your way
- **💻 Developer-Ready**: Full syntax highlighting and code editing capabilities when you need them
- **🍎 macOS Native**: Deep integration with iCloud, Handoff, Quick Note, and more

---

## ✨ Features

### 🤖 Local AI Assistant
Powered by **Ollama** for complete privacy - your data never leaves your device.

- **Rewrite**: Improve clarity, flow, and readability
- **Summarize**: Generate concise summaries of long text
- **Tone Adjustment**: Switch between Formal, Casual, or Concise styles
- **Smart Suggestions**: Context-aware writing improvements
- **Usage**: Click the ✨ icon or press `⇧⌘A`

### 💻 Developer Mode
A fully capable code editor when you need it.

- **Syntax Highlighting**: JSON, JavaScript, Python, Swift, HTML, CSS, Shell, YAML, Markdown
- **Smart Tools**: Bracket matching, auto-close pairs, regex search
- **Code Formatters**: JSON prettify, sort lines, trim whitespace
- **Line Numbers**: Toggle-able line numbering
- **Regex Search**: Powerful pattern matching

### ⚡️ Power Tools

- **Templates**: Built-in templates for Meeting Notes, Blog Posts, Code Snippets, and more
- **Text Snippets**: Reusable text blocks with variable support (`{DATE}`, `{TIME}`, `{CURSOR}`)
- **Export Options**: 
  - 📄 PDF with formatting preserved
  - 🌐 HTML export
  - 📤 Publish to GitHub Gist
- **Version History**: Auto-save with time-machine-like version tracking
- **Document Outline**: Navigate long documents with ease

### 🍎 macOS Integration

- **iCloud Sync**: Access your documents across all your Apple devices
- **Quick Note**: Menu bar app with global hotkey (`⌃⇧N`) to capture thoughts instantly
- **Handoff**: Seamlessly switch between your Mac, iPad, and iPhone
- **Services**: "Open in ZenPad" from any macOS application
- **Spotlight Integration**: Find your documents instantly
- **Dark/Light Mode**: Automatic appearance switching

### 📝 Writing Features

- **Focus Mode**: Distraction-free full-screen writing (`⌃⌘F`)
- **Markdown Support**: Live preview with `⇧⌘P`
- **Multiple Tabs**: Work on multiple documents simultaneously
- **Split View**: Side-by-side editing (Horizontal: `⌃⌘D`, Vertical: `⌥⌘D`)
- **Customizable Typography**: Font family, size, and line height settings
- **Text Statistics**: Live word count, character count, reading time

---

## 🚀 Installation

### Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later (for building from source)
- **Ollama**: Optional, for AI features ([Download](https://ollama.ai))

### Build from Source

#### Option 1: Using XcodeGen (Recommended)

```bash
# Install XcodeGen
brew install xcodegen

# Clone the repository
git clone https://github.com/pronzzz/zenpad.git
cd zenpad

# Generate Xcode project
xcodegen generate

# Open and build
open ZenPad.xcodeproj
```

Press **⌘R** in Xcode to build and run.

#### Option 2: Using Swift Package Manager

```bash
# Clone the repository
git clone https://github.com/pronzzz/zenpad.git
cd zenpad

# Build
swift build

# Run
swift run
```

### Setting Up AI Features

For AI assistant functionality, install and run Ollama:

```bash
# Install Ollama
brew install ollama

# Start the Ollama service
ollama serve

# Pull the recommended model
ollama pull llama3.2
```

---

## 💡 Usage

### Quick Start

1. **Launch ZenPad** from Applications or Xcode
2. Press **⌘N** to create a new document
3. Start writing!

### AI Assistant

1. Select text you want to improve
2. Press **⇧⌘A** or click the ✨ icon
3. Choose an action: Rewrite, Summarize, or Change Tone
4. Review and apply the suggestions

### Templates

1. Press **⇧⌘N** for "New from Template"
2. Choose from built-in templates
3. Fill in the placeholders

### Quick Note (Menu Bar)

1. Press **⌃⇧N** from anywhere in macOS
2. Type your note
3. It's automatically saved to iCloud

For detailed usage instructions, see the [User Guide](USER_GUIDE.md).

---

## ⌨️ Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New Document | `⌘N` |
| New from Template | `⇧⌘N` |
| Open | `⌘O` |
| Save | `⌘S` |
| Save As | `⇧⌘S` |
| Close Tab | `⌘W` |
| AI Assistant | `⇧⌘A` |
| Focus Mode | `⌃⌘F` |
| Markdown Preview | `⇧⌘P` |
| Quick Note | `⌃⇧N` |
| Split Horizontal | `⌃⌘D` |
| Split Vertical | `⌥⌘D` |
| Find | `⌘F` |
| Find and Replace | `⌥⌘F` |

---

## 📂 Project Structure

```
ZenPad/
├── ZenPad/
│   ├── App/
│   │   ├── ZenPadApp.swift          # App entry point
│   │   └── AppDelegate.swift        # AppKit integration
│   ├── Views/
│   │   ├── ContentView.swift        # Main layout
│   │   ├── EditorView.swift         # NSTextView wrapper
│   │   ├── AIAssistantPanel.swift   # AI interface
│   │   ├── CodeEditorView.swift     # Syntax highlighting
│   │   ├── MarkdownPreviewView.swift
│   │   ├── TabBarView.swift         # Document tabs
│   │   ├── StatusBarView.swift      # Statistics display
│   │   ├── MenuBarController.swift  # Quick Note menu bar
│   │   ├── PreferencesView.swift
│   │   ├── FocusModeView.swift
│   │   └── SearchBarView.swift
│   ├── Models/
│   │   ├── Document.swift           # Document model
│   │   └── DocumentManager.swift    # Document state management
│   ├── Services/
│   │   ├── AIService.swift          # Ollama integration
│   │   ├── AutoSaveService.swift    # Auto-save & versions
│   │   ├── CloudSyncService.swift   # iCloud integration
│   │   ├── FileService.swift        # File operations
│   │   ├── ExportService.swift      # PDF/HTML/Gist export
│   │   ├── TemplateManager.swift    # Document templates
│   │   ├── SnippetManager.swift     # Text snippets
│   │   ├── SyntaxHighlighter.swift  # Code highlighting
│   │   ├── SpotlightService.swift   # Search integration
│   │   └── SystemIntegration.swift  # Handoff & Services
│   ├── Utilities/
│   │   ├── TextStatistics.swift     # Word/char count
│   │   └── Preferences.swift        # User preferences
│   └── Resources/
│       ├── Assets.xcassets          # App icons & assets
│       └── ZenPad.entitlements      # App capabilities
├── ZenPadTests/
├── Package.swift                     # SPM manifest
├── project.yml                       # XcodeGen config
├── README.md
├── USER_GUIDE.md
├── TROUBLESHOOTING.md
└── LICENSE
```

---

## 🛠 Technologies

- **SwiftUI**: Modern declarative UI framework
- **AppKit**: Native macOS text handling (NSTextView)
- **CloudKit**: iCloud synchronization
- **Ollama**: Local AI inference
- **XcodeGen**: Project generation
- **Swift Package Manager**: Dependency management

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines

- Follow Swift style conventions
- Add tests for new features
- Update documentation as needed
- Ensure builds succeed before submitting PR

---

## 🐛 Troubleshooting

Having issues? Check the [Troubleshooting Guide](TROUBLESHOOTING.md) or [open an issue](https://github.com/pronzzz/zenpad/issues).

Common issues:
- **AI not working?** Ensure Ollama is running: `ollama serve`
- **Build errors?** Try cleaning: `xcodegen generate && rm -rf DerivedData/`
- **iCloud sync issues?** Check Settings > Apple ID > iCloud > iCloud Drive

---

## 📄 License

MIT License

Copyright (c) 2026 Pranav Dwivedi

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

See [LICENSE](LICENSE) for full details.

---

## 🙏 Acknowledgments

- Built with [Ollama](https://ollama.ai) for privacy-first AI
- Inspired by the simplicity of great macOS apps
- Created with ❤️ by [Pranav Dwivedi](https://github.com/pronzzz)

---

<div align="center">

**[⬆ Back to Top](#zenpad)**

*ZenPad v1.0 - Your thoughts, your way.*

</div>
