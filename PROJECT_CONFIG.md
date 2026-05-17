# JSON Viewer — Project Config

## Tech Stack Key

`macos-swift-swiftui`

## Project Summary

A lightweight macOS app for viewing and editing JSON files visually.

| Property | Value |
|---|---|
| Platform | macOS 13+ |
| Language | Swift 5.9 |
| UI framework | SwiftUI + AppKit (NSTextView for the raw JSON editor) |
| Dependencies | None — pure Apple SDK only |
| Distribution | Manually (Releases zip, not notarized) |

## Architecture

**MVVM** — single `EditorViewModel` (@MainActor ObservableObject) backed by an immutable value-type tree (`TreeNode`).

- All tree mutations are **pure functions** in `TreeOperations`; each returns a new root, never mutates in place.
- `History<TreeNode>` stores the previous root before each commit — undo/redo is a stack swap.
- The raw-JSON text editor and the tree view are **bidirectionally synced** via `treeVersion` (tree → raw) and `updateFromRaw` (raw → tree), with a `suppressRawOnChange` flag to break the loop.

## File / Folder Map

```
JSONViewer/
├── main.swift                  SPM bootstrap — sets NSApp activation policy before SwiftUI App.main()
├── JSONViewerApp.swift         App entry point; AppState (file I/O, window title); menu commands
│
├── Models/
│   ├── JsonValue.swift         NodeType, JsonPrimitive, ParsedJson, JSONParser, serializeJson(), Color(hex:)
│   └── TreeNode.swift          TreeNode value type; find(id:), ancestorIds(of:), flatVisible(expandedIds:), toParsedJson()
│
├── Core/
│   ├── TreeBuilder.swift       Parse JSON string → TreeNode; TreeNode → JSON string; defaultChild()
│   ├── TreeOperations.swift    Pure tree mutation functions: setValue, setKey, addChild, removeNode, duplicateNode, changeType, reorderChildren
│   ├── Search.swift            Case-insensitive key+value search across the tree; returns [SearchMatch]
│   └── History.swift           Generic undo/redo stack with configurable maxSize (default 100)
│
└── Views/
    ├── ContentView.swift       AppRootView (key monitor for undo/redo); ContentView (toolbar: Open, Copy JSON)
    ├── MainEditorView.swift    HSplitView layout; left: TreeView+FormView; right: RawJsonView
    ├── TreeView.swift          Collapsible tree rows; inline key/value editing; context menu
    ├── FormView.swift          Inspector panel for selected node; ObjectFormContent, ArrayFormContent, PrimitiveFormContent
    ├── JsonTextEditor.swift    NSViewRepresentable wrapping NSTextView; disables all smart substitutions
    └── SearchBarView.swift     Search field; match counter; prev/next navigation; expand/collapse all
```

## State Flow

```
User edits raw JSON
  → RawJsonView.onChange(rawText) → viewModel.updateFromRaw()
  → rebuilds TreeNode tree, preserves expanded/selected state by path

User edits tree (key, value, type, add, remove, reorder)
  → TreeOperations.xxx() → EditorViewModel.commit()
  → treeVersion += 1 → RawJsonView syncs rawText from viewModel.serializedJson
```

## Key Design Decisions

| Decision | Reason |
|---|---|
| Custom `JSONParser` (not `JSONSerialization`) | Preserves object key ordering — Swift `Dictionary` does not guarantee insertion order |
| `ParsedJson.object` is `[(key:, value:)]` array, not `Dictionary` | Same reason — ordered keys round-trip correctly |
| `suppressRawOnChange` flag in `RawJsonView` | Prevents the tree→raw text update from triggering a second raw→tree parse (infinite loop) |
| `main.swift` sets `.regular` activation policy before `App.main()` | SPM executables launch as background processes by default — without this, no window appears |
| `NSTextView` wrapper (`JsonTextEditor`) | `TextEditor` in SwiftUI on macOS enables smart quotes / autocorrect which corrupt JSON strings |

## How to Build & Run

### Xcode (recommended)
1. Open `JSONViewer.xcodeproj`
2. Select your development team in Signing & Capabilities
3. Press `Cmd+R`

### SPM
```sh
swift build
swift run "JSON Viewer"
```
> SPM build works, but make sure `main.swift` is present — it sets the activation policy so the window appears.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+N` | New document |
| `Cmd+O` | Open file |
| `Cmd+S` | Save |
| `Cmd+Shift+S` | Save As |
| `Cmd+Z` | Undo |
| `Cmd+Shift+Z` | Redo |
| `Delete` | Delete selected node (tree focus) |

## Testing

There are currently **no automated tests** in this project. The codebase has good testability foundations:
- `TreeOperations` are pure functions — trivially unit-testable
- `History<T>` is a generic value-type stack — trivially unit-testable
- `Search.searchNodes()` is a pure function
- `JSONParser` is a stateless parser class
- `EditorViewModel` is `@MainActor` and uses value-type state — testable with `MainActor` test utilities

If adding tests, a `macos-swift-swiftui` Swift Package test target is the right approach (no Xcode UI tests required for the logic layer).
