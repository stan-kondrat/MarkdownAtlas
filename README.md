# MarkdownAtlas

A lightweight macOS markdown viewer built with native Cocoa.

## Features

- Browse and view markdown files in folders
- File tree navigation with sidebar
- Live markdown rendering with basic syntax support
- Zero dependencies - pure Cocoa/Objective-C

## Build

```bash
make
```

## Run

```bash
./MarkdownAtlas
```

or

```bash
make run
```

With a specific folder:

```bash
./MarkdownAtlas ./path/to/folder
```

## Install (Optional)

Create a symlink for global access:

```bash
ln -s $(pwd)/MarkdownAtlas /Users/user/.local/bin/mda
```

Then use it from anywhere:

```bash
mda ./docs
mda ~/projects/markdown-files
```

## Requirements

- macOS
- gcc with Cocoa framework
- C2x standard support

## Technical

- **Language**: Objective-C
- **Framework**: Native Cocoa (AppKit)
- **Dependencies**: None - zero external libraries
- **Build**: Simple Makefile with gcc
- **Coded with**: Claude Code

## Supported Markdown

- Headings (# through ######)
- Bold (**text** or __text__)
- Italic (*text* or _text_)
- Inline code (`code`)
- Code blocks (```)
- Blockquotes (>)
- Lists (- or *)
- Horizontal rules (---)

## License

JSON License - see [LICENSE.txt](LICENSE.txt)
