# Jot (Omarchy Plugin)

A utilitarian minimalist quick capture and interactive inbox overlay for [Omarchy](https://omarchy.org).

Quick capture — one line, straight into your inbox file:

![Jot quick capture overlay](docs/capture.png)

Interactive inbox — check off, edit, delete, filter. Colors follow the active Omarchy theme:

![Jot interactive inbox](docs/inbox.png)

---

## Features

- **Dual-Mode Overlay**:
  - **Quick Capture** (<kbd>SUPER</kbd>+<kbd>N</kbd>): Instant scratchpad to capture a thought. Press <kbd>Enter</kbd> to append to `~/notes/inbox.md`.
  - **Interactive Inbox** (<kbd>SUPER</kbd>+<kbd>ALT</kbd>+<kbd>N</kbd>): Document-style popup overlay to view, check off, edit, and delete notes.
- **Keyboard-First Controls**:
  - <kbd>j</kbd> / <kbd>k</kbd> or <kbd>↑</kbd> / <kbd>↓</kbd> — Move selection
  - <kbd>Space</kbd> or <kbd>x</kbd> — Toggle task completion (`- [ ]` ↔ `- [x]`)
  - <kbd>e</kbd> or <kbd>Enter</kbd> — Inline edit mode (<kbd>Enter</kbd> save, <kbd>Esc</kbd> cancel)
  - <kbd>d</kbd> or <kbd>Backspace</kbd> / <kbd>Delete</kbd> — Delete note
  - <kbd>a</kbd> or <kbd>Tab</kbd> — Switch between Inbox and Quick Capture
  - <kbd>/</kbd> — Filter notes
  - <kbd>Esc</kbd> — Close overlay
- **Atomic File Sync**: Reads and updates `~/notes/inbox.md` directly.

---

## Installation

```bash
# Clone and install into Omarchy plugins
omarchy plugin add https://github.com/barun-labs/jot.git --enable

# Set up keybindings
jot bind-key
```

Or manually copy to `~/.config/omarchy/plugins/lun.jot` and enable:
```bash
omarchy plugin enable lun.jot
```

---

## Configuration

Customizable via `~/.config/jot/config.json`:

```json
{
  "file": "~/notes/inbox.md",
  "template": "- [ ] %Y-%m-%d %H:%M {text}"
}
```

---

## Keybindings in Hyprland

Add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + N", "Jot Capture", "omarchy-shell shell toggle lun.jot '{\"mode\":\"capture\"}'")
o.bind("SUPER + ALT + N", "Jot Inbox", "omarchy-shell shell toggle lun.jot '{\"mode\":\"inbox\"}'")
```

---

## License

MIT
