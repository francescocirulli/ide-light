# Code Light

Code Light is an ultra-lightweight native macOS app for reading source code. It is intentionally closer to a fast project browser than a full IDE: open a folder, jump between files, search inside the current file, and read code with line numbers and lightweight syntax highlighting.

The goal is speed and calm. Code Light avoids editing workflows, project indexing daemons, language servers, terminals, and heavyweight extensions so it can open quickly and stay responsive while browsing codebases.

## Features

- Native AppKit UI with a compact reader-focused layout.
- Custom macOS app icon.
- Lazy folder tree for fast large-repo browsing.
- Read-only code viewer with line numbers.
- Lightweight syntax highlighting for common languages.
- Current-file Find with match count, previous/next navigation, and active-match highlighting.
- `Command-P` quick open with fuzzy filename/path search.
- Recently opened file chips with close controls.
- Sidebar file filtering.
- File metadata header with language, line count, size, path, and copy-path action.
- Agent-friendly file references, selected-code context copy, CLI entry point, and URL scheme.

## Run

Requirements:

- macOS 13 or newer.
- Xcode command line tools or Xcode with Swift 6-compatible toolchain.

```sh
swift run CodeLightIDE
```

You can also open a folder or file directly:

```sh
swift run CodeLightIDE .
swift run CodeLightIDE Sources/CodeLightIDE/CodeViewerController.swift
```

To create a normal macOS app bundle:

```sh
scripts/build-app.sh
open "dist/Code Light.app"
```

To install the app and register it with Finder's Open With list:

```sh
scripts/install-app.sh
```

The installer also creates a `code-light` command in `/usr/local/bin` when writable, otherwise in `~/.local/bin`.

```sh
code-light .
code-light Sources/CodeLightIDE/CodeViewerController.swift:42
open 'code-light://open?file=/absolute/path/to/File.swift&root=/absolute/path/to/repo&line=42'
```

For file paths, the CLI sends the nearest Git repository root as workspace context when one exists.

## Design Goals

- Native AppKit UI for low startup overhead.
- Lazy folder loading so large repositories remain responsive.
- Read-only text view to avoid editor complexity.
- Async file loading with memory-mapped reads where possible.
- Quick file switching without a background indexing service.
- Syntax highlighting capped at 2 MB per file; larger files are shown as plain text.
- Hard skip at 30 MB so the app does not freeze on huge logs or generated artifacts.

## Shortcuts

- `Command-O`: open a folder.
- `Command-P`: quick open a file by fuzzy path search.
- `Command-R`: reload the selected file or folder.
- `Command-F`: focus search in the current file.
- `Enter` / `Shift-Enter` in Find: next or previous match.
- `Esc` in Find: clear search and return to the code view.
- `Command-.`: show or hide hidden/vendor folders.
- `Command-Option-C`: copy the current file reference as `path:line`.
- `Command-Shift-C`: copy the current selection as Markdown agent context.
- `Command-Shift-Option-C`: copy a compact workspace context summary.

## Reader Features

- Find shows match count and active match position.
- The header shows file path, language, line count, size, and a copy-path button.
- Recently opened files appear as closeable compact chips above the code.
- Sidebar filtering keeps folder context while narrowing visible files.

## Agent Workflows

Code Light is designed to sit beside coding agents and heavy editors:

- Agents can open a specific file or line with `code-light path/to/file.swift:42`.
- Agents can use the `code-light://open?file=...&line=...` URL scheme from scripts or local tools.
- Humans can copy exact `path:line` references from the app for prompts, issues, or reviews.
- Humans can copy selected code as fenced Markdown with source metadata, ready to paste into an agent.
- Workspace context copy gives an agent the project root and a compact file list without indexing or background services.

## Repository

GitHub: <https://github.com/francescocirulli/ide-light>

## License

MIT
