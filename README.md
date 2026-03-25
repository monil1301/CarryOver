# CarryOver

<div align="center">


![Platform](https://img.shields.io/badge/platform-macOS-black)
![Status](https://img.shields.io/badge/status-active-success)
![Release](https://img.shields.io/github/v/release/monil1301/CarryOver)
![Downloads](https://img.shields.io/github/downloads/monil1301/CarryOver/total)

A lightweight macOS menu bar app for daily tasks.

**Capture quickly. Check things off. Carry unfinished tasks into today.**

[Download latest release](../../releases) · [Report a bug](../../issues/new) · [Request a feature](../../issues/new)

</div>

---

## What is CarryOver?

CarryOver is a simple daily task app that lives in your macOS menu bar.

It is built for one job: helping you quickly write down tasks, work through them today, and automatically carry unfinished tasks forward.

Most task apps are designed around projects, priorities, recurring systems, and complex organization.

CarryOver is intentionally different:
- fast to open
- fast to type into
- keyboard-first
- lightweight
- grounded in daily flow

Completed tasks stay with the day they were finished, so you can always go back and see what got done.

---

## Why I built it

I wanted something like a calendar diary for tasks:

- tasks stay attached to a day
- unfinished tasks roll over to today
- completed tasks stay in history
- adding a task should take almost no effort

There are already many full-featured task managers, but most of them felt too heavy for this job.

CarryOver is the lightweight version of that idea.

---

## Features

### Fast capture
- Lives in the macOS status bar
- Open with a global hotkey
- Input is focused immediately when the app opens
- Type and press `Return` to add a task

### Keyboard-first workflow
- `↓` from the input field moves to the first task
- `↑ / ↓` navigates tasks
- `↑` from the top task returns to the input field
- `Space` toggles complete / incomplete
- `Return` edits the selected task
- `Delete` deletes the selected task

### Editing
- Edit tasks inline
- `Return` saves
- `Esc` cancels

### Undo
Undo the last action after:
- delete
- toggle
- add
- edit

Use:
- the Undo button in the toast
- or `⌘Z`

### Completed section
- Completed tasks move into a separate section
- The section is collapsible
- Use mouse or keyboard to expand / collapse

### Paste as tasks
Paste multiple lines into the input field and CarryOver turns each line into a task.

It also cleans common list prefixes such as:
- `-`
- `*`
- `#`
- `[]`

### Day-based flow
- Unfinished tasks carry over to today
- Completed tasks stay with the day they were completed
- Browse previous days to review completed work

### Navigation
- Previous day: `⌘[`
- Next day: `⌘]`
- Today: `⌘T`
- Date picker: `⌘P`

### Settings
- Open settings: `⌘,`
- Enable **Open at Login**
- Customize the global hotkey  
  Default: `^ ⌥ Space`

---

## Screenshots

> Replace these placeholders with real screenshots or GIFs.

### Main view
![CarryOver Main View](./assets/screenshots/main.png)

### Keyboard-first workflow
![CarryOver Keyboard Navigation](./assets/screenshots/keyboard-navigation.png)

### Completed section
![CarryOver Completed Section](./assets/screenshots/completed-section.png)

### Settings
![CarryOver Settings](./assets/screenshots/settings.png)

---

## Download

Download the latest version from [GitHub Releases](../../releases).

---

## Installation

1. Download the latest release from the [Releases](../../releases) page.
2. Move `CarryOver.app` to your Applications folder.
3. Open the app.

Because CarryOver is currently unsigned, macOS may block it the first time you open it.

If that happens:

1. Try opening `CarryOver.app`.
2. If macOS shows a warning, go to **System Settings → Privacy & Security**.
3. Scroll to the **Security** section.
4. Click **Open Anyway** for CarryOver.
5. Confirm the dialog to open the app.

You can also right-click the app and choose **Open**.

---

## How it works

CarryOver is based on a simple model:

- each day has its own list
- completed tasks stay with that day
- unfinished tasks carry forward
- you can always go back and review previous days

This gives you the feeling of a daily checklist with memory, without turning the app into a full task management system.

---

## Keyboard shortcuts

| Action | Shortcut |
|---|---|
| Open app | Custom hotkey |
| Add task | `Return` |
| Move from input to tasks | `↓` |
| Navigate tasks | `↑ / ↓` |
| Return to input | `↑` from top task |
| Toggle task | `Space` |
| Edit selected task | `Return` |
| Save edit | `Return` |
| Cancel edit | `Esc` |
| Delete task | `Delete` |
| Undo last action | `⌘Z` |
| Previous day | `⌘[` |
| Next day | `⌘]` |
| Go to today | `⌘T` |
| Open date picker | `⌘P` |
| Open settings | `⌘,` |
| Quit app | `⌘Q` |

---

## Who it is for

CarryOver is for people who want:
- a lightweight daily task tool
- a menu bar workflow
- keyboard-first interaction
- unfinished tasks to follow them into today
- a simple history of what they completed

It is probably a good fit if you find most task managers too heavy for everyday personal use.

---

## What CarryOver is not

CarryOver is not trying to be:
- a project management app
- a team collaboration tool
- a reminders system
- a planner with tags, priorities, and recurring automation

The goal is to stay small, focused, and fast.

---

## Feedback

Bug reports, ideas, and suggestions are welcome.

- [Open an issue](../../issues/new)
- [Check existing issues](../../issues)

---

## Privacy

CarryOver stores all data locally on your Mac.

It does not require an account, does not use a server, and does not send any data off your device.

Nothing leaves your Mac when you use the app.

