---
name: code-light
description: Use Code Light as a fast macOS source-code reader from coding agents. Use when an agent should open a workspace, file, or exact line for the human, or request copied file/selection/workspace context from Code Light.
---

# Code Light

Use the installed `code-light` command to open source for the human.

## Open

```sh
code-light .
code-light path/to/file.swift
code-light path/to/file.swift:42
```

- Run from the repo root when possible.
- Prefer `path:line` for precise references.
- For file paths, the CLI opens the nearest Git repo as workspace context.

## URL

```sh
open 'code-light://open?file=/abs/path/File.swift&root=/abs/path/repo&line=42'
```

## Ask For Context

- `Cmd-Option-C`: copy current `path:line`.
- `Cmd-Shift-C`: copy selected code as Markdown context.
- `Cmd-Shift-Option-C`: copy compact workspace context.
