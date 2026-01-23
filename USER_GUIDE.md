# ZenPad User Guide

**Version 1.0** • **macOS 13.0+**

Welcome to ZenPad! This comprehensive guide will help you master all features of your new AI-powered text editor.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Basic Operations](#basic-operations)
3. [AI Assistant](#ai-assistant)
4. [Developer Mode](#developer-mode)
5. [Templates & Snippets](#templates--snippets)
6. [Export Options](#export-options)
7. [macOS Integration](#macos-integration)
8. [Preferences](#preferences)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

---

## Getting Started

### First Launch

1. **Open ZenPad** from your Applications folder or build from source
2. **Grant Permissions**: 
   - Allow access to Documents folder when prompted
   - Enable iCloud sync if you want cross-device access
3. **Setup AI** (Optional): Install Ollama for AI features
   ```bash
   brew install ollama
   ollama serve
   ollama pull llama3.2
   ```

### The Interface

ZenPad's interface is minimal and focused:

- **Editor Area**: The main writing space (center)
- **Tab Bar**: Switch between open documents (top)
- **Status Bar**: View statistics and document info (bottom)
- **Toolbar**: Quick access to common actions (customizable)
- **Sidebar**: Templates, snippets, and outline (toggle with `⌘⌥S`)

---

## Basic Operations

### Creating Documents

**New Blank Document**
- Click **File > New** or press `⌘N`
- Start typing immediately

**New from Template**
- Press `⇧⌘N` or click **File > New from Template**
- Choose from: Meeting Notes, Blog Post, Code Snippet, Essay, Letter
- Fill in the template placeholders

### Opening Documents

**Open File**
- Press `⌘O` or click **File > Open**
- Browse to your file (.txt, .md, supported)
- Recently opened files appear in **File > Open Recent**

**Quick Open**
- Press `⌘⇧O` for quick file search
- Type filename to filter
- Press `Enter` to open

### Saving Documents

**Auto-Save**
- ZenPad automatically saves your work every 30 seconds
- No need to manually save in most cases

**Manual Save**
- `⌘S`: Save current document
- `⇧⌘S`: Save As (choose new location/name)

**Version History**
- Click **File > Revert To > Browse All Versions**
- Navigate through auto-saved versions
- Restore any previous version

### Working with Tabs

**Multiple Documents**
- Open multiple files to see them as tabs
- `⌘{` / `⌘}`: Switch between tabs
- `⌘W`: Close current tab
- Drag tabs to reorder

**Split View**
- `⌃⌘D`: Split horizontally
- `⌥⌘D`: Split vertically
- Great for comparing documents or reference material
- Drag the divider to resize panes

---

## AI Assistant

### Prerequisites

Ensure Ollama is installed and running:
```bash
ollama serve  # Keep this running in a terminal
```

### Using AI Features

#### Quick AI Access
1. **Select text** you want to improve
2. Press `⇧⌘A` or click the **✨ icon** in the toolbar
3. The AI Assistant panel appears on the right

#### AI Actions

**Rewrite**
- Improves clarity and readability
- Maintains your original meaning
- Best for: rough drafts, complex sentences

**Summarize**
- Creates concise summaries
- Configurable length: Brief, Medium, Detailed
- Best for: long articles, meeting notes, research

**Change Tone**
- **Formal**: Professional, business communication
- **Casual**: Friendly, conversational style
- **Concise**: Brief, to-the-point writing

**Expand**
- Adds detail and context
- Elaborates on ideas
- Best for: outlines, bullet points

#### AI Workflow

1. Write your initial draft
2. Select the paragraph/section to improve
3. Press `⇧⌘A` and choose an action
4. Review the AI suggestion in the right panel
5. Click **Apply** to replace, or **Insert Below** to keep both
6. Click **Discard** if you don't like the result

#### Tips for Best Results

- **Be specific**: Select complete thoughts/paragraphs
- **Iterative**: Use AI multiple times on different sections
- **Review carefully**: AI is a tool, not a replacement for your judgment
- **Context matters**: AI works best with clear, complete sentences

---

## Developer Mode

### Activating Developer Mode

Developer mode activates automatically when you:
- Open a code file (.js, .py, .swift, .json, etc.)
- Enable it manually: **View > Developer Mode** or `⌃⌘M`

### Syntax Highlighting

Supported languages:
- JavaScript/TypeScript
- Python
- Swift
- HTML/CSS
- JSON
- YAML
- Markdown
- Shell/Bash

Colors automatically adjust based on your system's Dark/Light mode.

### Code Features

**Line Numbers**
- Toggle: **View > Show Line Numbers** or `⌘L`
- Click a line number to select the entire line

**Bracket Matching**
- Place cursor next to a bracket: `( ) [ ] { }`
- Matching bracket highlights automatically
- Double-click a bracket to select all content inside

**Auto-Close Pairs**
- Type opening bracket → closing bracket auto-inserts
- Works for: `()`, `[]`, `{}`, `""`, `''`, `` `` ``

**Code Formatting**
- **Format JSON**: Select JSON text → **Edit > Format > JSON Prettify**
- **Sort Lines**: Select lines → **Edit > Format > Sort Lines**
- **Trim Whitespace**: **Edit > Format > Trim Trailing Whitespace**

### Regex Search

1. Press `⌥⌘F` for Find & Replace
2. Check **"Use Regex"** checkbox
3. Enter pattern, e.g., `\d{3}-\d{3}-\d{4}` for phone numbers
4. Use capture groups in replacement: `$1`, `$2`, etc.

**Examples:**
- Find emails: `[\w\.-]+@[\w\.-]+\.\w+`
- Find URLs: `https?://[^\s]+`
- Find variables: `var \w+ =`

---

## Templates & Snippets

### Templates

Templates are full document starters with predefined structure.

**Using Templates**
1. Press `⇧⌘N` (New from Template)
2. Select a template from the list
3. Template loads with placeholders like `{{Title}}`, `{{Date}}`
4. Fill in the placeholders
5. Delete any sections you don't need

**Built-in Templates**
- **Meeting Notes**: Agenda, attendees, action items
- **Blog Post**: Title, intro, body, conclusion, meta
- **Code Snippet**: Title, language, code, explanation
- **Project Plan**: Goals, tasks, timeline
- **Daily Journal**: Date, mood, entries

**Creating Custom Templates**
1. Create a document with your structure
2. Save to: `~/Library/Application Support/ZenPad/Templates/`
3. Use `{{VARIABLE}}` for placeholders
4. Template appears in the New from Template menu

### Snippets

Snippets are reusable text blocks for quick insertion.

**Using Snippets**
1. Open **Edit > Snippets > Manage Snippets**
2. Click **"+"** to create new snippet
3. Give it a **Trigger** (e.g., `sig`) and **Content**
4. Type the trigger and press `Tab` to expand

**Built-in Snippets**
- `date` → Current date (2026-01-23)
- `time` → Current time (17:14)
- `datetime` → Full timestamp
- `lorem` → Lorem ipsum paragraph

**Snippet Variables**
- `{DATE}`: Current date (YYYY-MM-DD)
- `{TIME}`: Current time (HH:MM)
- `{CURSOR}`: Where cursor should land after expansion
- `{CLIPBOARD}`: Paste clipboard content

**Example Snippet**
```
Trigger: email
Content:
Hi {CURSOR},

Hope you're doing well!

Best regards,
Pranav Dwivedi
```

Type `email` + `Tab` → Full signature with cursor positioned after "Hi "

---

## Export Options

### Export to PDF

1. **File > Export > PDF** or `⌘P`
2. Choose options:
   - Include header/footer
   - Page numbers
   - Font size
3. Click **Export**
4. Choose save location

**PDF Features**
- Preserves formatting (bold, italic)
- Respects dark/light mode colors
- Includes metadata (title, author)

### Export to HTML

1. **File > Export > HTML**
2. Options:
   - Standalone HTML (includes CSS)
   - Fragment only (for embedding)
   - Include syntax highlighting
3. Click **Export**

**Use Cases**
- Blog posts (copy HTML into CMS)
- Email newsletters
- Website content

### Publish to GitHub Gist

1. **File > Export > Publish Gist**
2. Enter Gist details:
   - Title
   - Description
   - Public or Secret
3. Click **Publish**
4. Link automatically copied to clipboard

**Requirements**
- GitHub account
- GitHub Personal Access Token (first time only)
  - Get token: https://github.com/settings/tokens
  - Required scope: `gist`
  - Paste into ZenPad when prompted

---

## macOS Integration

### iCloud Sync

**Setup**
1. **Preferences > General > iCloud**
2. Check **"Store documents in iCloud"**
3. Documents automatically sync across devices

**Access on Other Devices**
- **Mac**: Open ZenPad → iCloud documents appear
- **iPhone/iPad**: Files app → iCloud Drive → ZenPad folder
- **Web**: iCloud.com → iCloud Drive

**Conflict Resolution**
- If edits occur on multiple devices simultaneously
- ZenPad shows **"Resolve Conflict"** dialog
- Choose which version to keep, or merge manually

### Quick Note (Menu Bar)

**Setup**
1. ZenPad adds a menu bar icon (✏️) automatically
2. Access **Preferences > Quick Note** to customize
3. Set global hotkey (default: `⌃⇧N`)

**Using Quick Note**
1. Press `⌃⇧N` from anywhere in macOS
2. Small window appears
3. Type your note
4. Press `Esc` or click outside to auto-save
5. Note saved to: `Quick Notes/` in iCloud

**Customization**
- Change hotkey
- Set default save location
- Auto-paste clipboard on open
- Timestamp new notes

### Handoff

**Requirements**
- Same Apple ID on all devices
- Bluetooth and Wi-Fi enabled
- Devices nearby

**Using Handoff**
1. Edit document on Mac
2. Look for ZenPad icon on iPhone/iPad dock
3. Tap to continue editing on mobile device

Works with: iPhone, iPad running iOS 16+

### Services Integration

ZenPad appears in macOS Services menu:

**"Open in ZenPad"**
- Right-click text in any app
- Services > Open in ZenPad
- Selected text opens in new ZenPad document

**"Append to ZenPad Note"**
- Right-click text in any app
- Services > Append to ZenPad Note
- Choose which note to append to

---

## Preferences

Access: **ZenPad > Preferences** or `⌘,`

### General

- **Theme**: System, Light, Dark
- **Launch behavior**: New document, Reopen last, Empty
- **Auto-save interval**: 10s to 5min
- **Enable version history**: On/Off
- **iCloud sync**: On/Off

### Editor

- **Font**: Family and size (9-48pt)
- **Line height**: 1.0 - 2.5
- **Tab width**: 2, 4, or 8 spaces
- **Show line numbers**: On/Off
- **Wrap lines**: On/Off
- **Spell check**: On/Off
- **Auto-correct**: On/Off

### AI

- **Ollama URL**: Default `http://localhost:11434`
- **AI Model**: llama3.2 (or installed model)
- **Max response length**: Tokens limit
- **Temperature**: Creativity level (0.0 - 1.0)

### Templates & Snippets

- **Template folder**: Custom location
- **Snippet expansion**: Tab or Space
- **Show snippet suggestions**: On/Off

### Advanced

- **Developer mode auto-detect**: On/Off
- **Regex search by default**: On/Off
- **Backup location**: Local folder path
- **Debug logging**: For troubleshooting

---

## Troubleshooting

### AI Assistant Not Working

**Problem**: AI panel shows "Not connected" or "Error"

**Solutions**:
1. Check Ollama is running:
   ```bash
   ps aux | grep ollama
   ```
2. Start Ollama if not running:
   ```bash
   ollama serve
   ```
3. Verify model is downloaded:
   ```bash
   ollama list
   ollama pull llama3.2  # if not listed
   ```
4. Check Ollama URL in Preferences > AI
5. Test Ollama directly:
   ```bash
   curl http://localhost:11434/api/tags
   ```

### Build Errors

**Problem**: Xcode build fails

**Solutions**:
1. Clean build folder: `⇧⌘K` in Xcode
2. Regenerate project:
   ```bash
   xcodegen generate
   rm -rf DerivedData/
   ```
3. Update dependencies:
   ```bash
   swift package update
   ```
4. Check macOS version (requires 13.0+)
5. Check Xcode version (requires 15.0+)

### iCloud Sync Issues

**Problem**: Documents not syncing

**Solutions**:
1. Check iCloud status: **System Settings > Apple ID > iCloud**
2. Ensure iCloud Drive is enabled
3. Check storage: iCloud might be full
4. Sign out and back into iCloud (last resort)
5. Force sync:
   - Quit ZenPad
   - Open Finder > iCloud Drive > ZenPad
   - Right-click folder > Download Now
   - Relaunch ZenPad

### Performance Issues

**Problem**: ZenPad is slow or laggy

**Solutions**:
1. Disable AI if not needed (large documents)
2. Turn off syntax highlighting for very large files
3. Reduce auto-save frequency (Preferences > General)
4. Close unused tabs
5. Check Activity Monitor for high CPU usage
6. Restart ZenPad

### Quick Note Hotkey Not Working

**Problem**: Global hotkey `⌃⇧N` doesn't trigger Quick Note

**Solutions**:
1. Grant Accessibility permissions:
   - **System Settings > Privacy & Security > Accessibility**
   - Add ZenPad to the list
2. Check for conflicting shortcuts in other apps
3. Choose different hotkey in Preferences > Quick Note
4. Relaunch ZenPad after changing permissions

---

## FAQ

### General

**Q: Is my data private?**
A: Yes! All AI processing happens locally via Ollama. Your documents never leave your Mac.

**Q: Does ZenPad work offline?**
A: Yes, completely. AI features require Ollama running locally (no internet needed). iCloud sync requires internet but is optional.

**Q: What file formats are supported?**
A: `.txt`, `.md`, `.markdown`, and most plain text formats. Code files with syntax highlighting support.

**Q: Can I use ZenPad on iOS/iPadOS?**
A: Not yet. Currently macOS only, but iOS version is planned.

### Features

**Q: How do I disable AI if I don't want it?**
A: Preferences > AI > Uncheck "Enable AI Assistant". The ✨ icon will disappear.

**Q: Can I create my own templates?**
A: Yes! Save documents to `~/Library/Application Support/ZenPad/Templates/` with `.template` extension.

**Q: What's the file size limit?**
A: No hard limit, but performance may degrade with files over 10MB. For large files, consider disabling syntax highlighting.

**Q: Can I customize keyboard shortcuts?**
A: Yes, through **System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts**. Add ZenPad-specific shortcuts there.

### Technical

**Q: What AI models can I use?**
A: Any model supported by Ollama. Recommended: `llama3.2`, `mistral`, `phi`. Configure in Preferences > AI.

**Q: Does ZenPad collect analytics?**
A: No. Zero telemetry, zero tracking. It's completely private.

**Q: Can I contribute to development?**
A: Absolutely! Visit https://github.com/pronzzz/zenpad to contribute.

**Q: How do I report bugs?**
A: Open an issue on GitHub: https://github.com/pronzzz/zenpad/issues

### Licensing

**Q: Is ZenPad free?**
A: Yes, it's free and open-source under MIT License.

**Q: Can I use ZenPad commercially?**
A: Yes, the MIT License allows commercial use.

**Q: Can I modify and redistribute ZenPad?**
A: Yes, per the MIT License. Just include the original license and copyright notice.

---

## Need More Help?

- **GitHub Issues**: https://github.com/pronzzz/zenpad/issues
- **Discussions**: https://github.com/pronzzz/zenpad/discussions
- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

*Last updated: January 2026 • ZenPad v1.0*
