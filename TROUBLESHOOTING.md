# ZenPad - Troubleshooting Guide

## Common Issues and Solutions

### 1. AI Features Not Working

**Symptoms:**
- Connection refused errors on port 11434
- AI panel shows "Offline" status

**Solution:**
Start Ollama before using AI features:
```bash
# Terminal 1: Start Ollama server
ollama serve

# Terminal 2: Pull the model (first time only)
ollama pull llama3.2
```

**Verify AI is working:**
```bash
curl http://localhost:11434/api/tags
```

---

### 2. Markdown Preview Issues (Fixed)

**Previous Symptoms:**
- WebKit sandbox errors
- "Connection invalid" errors from WebContent process
- Pasteboard access denied

**Solution:**
Updated `ZenPad.entitlements` with WebKit permissions:
- `com.apple.security.cs.allow-jit`
- `com.apple.security.cs.allow-unsigned-executable-memory`  
- `com.apple.security.cs.disable-library-validation`

Rebuild the project after the fix.

---

### 3. iCloud Sync Not Working

**Solution:**
1. Sign in to iCloud in System Settings
2. Enable iCloud sync in ZenPad Settings → Cloud tab
3. Grant ZenPad permission to access iCloud when prompted

---

### 4. Global Hotkey (⌃⇧N) Not Working

**Solution:**
1. Open System Settings → Privacy & Security → Accessibility
2. Add ZenPad to the list of allowed apps
3. Restart ZenPad

---

## Performance Tips

1. **Disable features you don't use:**
   - iCloud Sync (if working offline)
   - AI Assistant (saves memory)
   - Markdown Preview (for plain text editing)

2. **For large documents:**
   - Disable syntax highlighting
   - Turn off line numbers
   - Use Focus Mode for distraction-free writing

---

## Logs Location

View detailed logs in Console.app:
1. Open Console.app
2. Search for "ZenPad"
3. Filter by your application

---

## Need Help?

Check the [main README](file:///Users/pranavdwivedi/Public/Coding%20Projects/text/ZenPad/README.md) or review the [walkthrough](file:///Users/pranavdwivedi/.gemini/antigravity/brain/970d84d9-dae8-4874-9490-16bc544dbe39/walkthrough.md).
