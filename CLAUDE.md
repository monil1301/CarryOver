# CarryOver

A lightweight macOS menu bar utility that automatically carries over unfinished tasks to the next day.

## Design principles

- **Lightweight**: Minimal overhead, no bloat — this is a utility, not a full app
- **Keyboard-first**: Every action in the app is achievable via keyboard. New features must always have keyboard support.

## Architecture

MVVM with SwiftUI + AppKit bridges for keyboard handling.

```
App/             → Entry points (CarryOverApp, AppDelegate)
Models/          → TaskItem, DayBucket
ViewModels/      → PopoverViewModel (all UI state + actions)
Views/Popover/   → Main popover UI (header, input, list, rows, footer, undo toast)
Views/Settings/  → Settings window + shortcut recorder
Services/        → DailyStore (JSON persistence), StatusBarController, HotkeyPreferences
Bridges/         → NSViewRepresentable adapters for keyboard events (focus, return, space, arrow keys, text input)
Utilities/       → KeyCodes constants
```

## Key patterns

- **DailyStore** is the single source of truth for task data. It persists to JSON in `~/Library/Application Support/CarryOver/`.
- **PopoverViewModel** is `@MainActor` with manual `objectWillChange` (not `@Published`). All state vars call `sendChange()` in `didSet`.
- **Bridges** wrap AppKit `NSEvent` monitors to intercept keyboard events that SwiftUI Lists don't expose natively (Return to edit, Space to toggle, arrows to navigate).
- **Undo** uses snapshot-based `UndoAction` (captures full `DayBucket` before mutation) with a 4-second auto-dismiss toast.
- **QuickAddTextView / InlineEditTextView** are `NSTextView`-based bridges. Shift+Return inserts newline, plain Return commits. Key handling is done via `keyDown(with:)` override in custom `NSTextView` subclasses (not delegate `doCommandBy`).

## Build

Xcode project (not SPM). Open `CarryOver.xcodeproj`, build with `Cmd+B`.

## Dependencies

- **HotKey** (SPM): Global keyboard shortcut registration

## Conventions

- Swift 6, strict concurrency
- Views are small and delegate all logic to PopoverViewModel
- One ViewModel for the entire popover (no per-view VMs)
- Tasks are filtered via computed properties: `tasks`, `undoneTasks`, `doneTasks`
- DailyStore normalizes task order: undone first, then done
