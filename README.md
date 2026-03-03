# TakeNote

TakeNote is a markdown note-taking app for Mac, iPhone, iPad, and Apple Vision Pro. All your notes sync across devices via iCloud. AI features powered by Apple Intelligence run entirely on-device for privacy.

**Requires macOS 26, iOS 26, or visionOS 26 or later.** AI features require a device that supports [Apple Intelligence](https://www.apple.com/apple-intelligence/) with Apple Intelligence enabled.

## Notes

Notes are written in [Markdown](https://daringfireball.net/projects/markdown/). The editor provides syntax highlighting for headings, bold, italic, code blocks, links, lists, tables, blockquotes, task lists, strikethrough, and horizontal rules.

A note's title is automatically set from the first line of its content. You can also rename a note manually with **Cmd+R**.

### Preview Mode

Press **Cmd+P** to toggle between the editor and a rendered markdown preview. On Mac, the editor and preview display side by side. On iPhone and iPad, it switches between full-screen editor and full-screen preview.

### Images

You can add images to notes by:

- Pasting from the clipboard
- Dragging and dropping images from Finder or Photos
- Using the Photos picker on iPhone and iPad

Images are stored inside the app's database and sync across devices via iCloud. Large images are automatically downsampled to keep storage and sync efficient.

### Markdown Shortcut Bar

A toolbar above the editor provides quick-insert buttons for common markdown elements: headings, bullet lists, ordered lists, code fences, links, and inline code.

### Multi-Note View

When you select multiple notes in the list, they display as a stack of scattered paper cards showing rendered previews of each note.

## Folders

Organize notes into folders. Every note lives in exactly one folder.

- **Inbox** - The default folder where new notes are created. Cannot be deleted.
- **All Notes** - Shows every note across all folders (excluding Trash and Archive).
- **Starred** - Shows all starred/favorited notes.
- **Archive** - A holding area for notes you want to keep but hide from search and Magic Chat.
- **Trash** - Deleted notes go here. Empty the trash to permanently delete them.

You can create as many custom folders as you want. Each folder can have a custom color and icon chosen from SF Symbols. Folder colors and icons are set through the Edit Details option in the folder's context menu.

Drag and drop notes onto folders in the sidebar to move them. Dropping a note onto the Starred folder stars it.

## Tags

Tags provide a second layer of organization on top of folders. A note stays in its folder but can also have one tag assigned. Tags have their own section in the sidebar and can be filtered to show only notes with that tag.

Tags support custom colors. Create tags with **Cmd+T**. Assign a tag by dragging a note onto it in the sidebar, or by using the Move action on a note.

## Starring Notes

Star important notes to pin them to the top of any note list. Starred notes also appear in the dedicated Starred folder in the sidebar. Toggle a note's star with **Cmd+S**.

## Sorting

Notes can be sorted by created date or last updated date, in ascending or descending order. The sort controls are available in the note list header. The default sort is by created date, newest first.

## Search

TakeNote includes full-text search powered by SQLite FTS5. On devices that support Apple Intelligence, semantic search is also available, letting you search your notes using natural language.

Type in the search bar to search across all notes. On Mac and iPad, the app automatically switches to the All Notes view as you type so results span your entire library. Archived and trashed notes are excluded from search results.

## Note Links and Backlinks

Every note has a unique URL in the format `takenote://note/<UUID>`. You can link between notes using standard markdown links.

- **Copy a note's markdown link:** **Cmd+Opt+C**
- **View backlinks** (notes that link to the current note): **Cmd+Opt+B**

When you paste a note link into another note, TakeNote automatically tracks the relationship. The backlinks viewer shows all notes that reference the current note, with one-click navigation.

## AI Features

All AI features use Apple Intelligence and run entirely on-device. They require a supported device with Apple Intelligence enabled. If Apple Intelligence is unavailable, the app works normally without AI features.

### AI Summaries

TakeNote automatically generates a one-line summary of each note using on-device AI. Summaries appear in the note list below each note's title, providing a quick overview without opening the note. Summaries regenerate automatically when a note's content changes. You can also manually regenerate a summary from the note's context menu.

### Magic Format

**Cmd+Opt+F** - Converts the entire note from unformatted text into clean markdown using AI. Useful for quickly formatting pasted text, meeting notes, or rough drafts.

### Magic Assistant

**Cmd+Opt+A** - Select text in the editor, then invoke Magic Assistant for targeted markdown formatting suggestions on the selected passage.

### Magic Chat

**Cmd+Shift+C** - Opens a chat window where you can have a conversation about your notes. Magic Chat can:

- **Search your notes** to answer questions about their content
- **Create new notes** in your Inbox when you ask it to

Magic Chat maintains conversation history within a session, so you can ask follow-up questions. It uses tool calling to search your notes and shows you which notes it found and referenced. On Mac, Magic Chat opens in a separate window. On iPhone and iPad, it opens as a popover.

## Drag and Drop

- **Notes to folders:** Move the note to that folder
- **Notes to Starred:** Star the note
- **Notes to tags:** Assign the tag to the note
- **Text onto the note list:** Creates a new note with that text as content
- **Files onto the note list:** Imports markdown and text files as new notes
- **Images onto the editor:** Inserts the image into the note

## Cut, Copy, and Paste

On Mac, you can cut, copy, and paste notes using standard keyboard shortcuts:

- **Copy** a note and paste it into another folder to create a duplicate
- **Cut** a note and paste it into another folder to move it

## File Import and Export

### Import

Drop `.md` or `.txt` files onto the note list to import them. You can also drop an entire folder to import all markdown and text files it contains, creating a new folder in TakeNote with the same name.

### Export

Export any note as a `.md` markdown file from the note's context menu.

## Widgets

TakeNote provides home screen and lock screen widgets:

- **Inbox Widget** - Shows recent notes from your Inbox with a button to create a new note. Available in small, medium, and large sizes.
- **Starred Widget** - Shows your recently starred notes. Available in small, medium, and large sizes.

A Control Center widget is also available for quickly creating a new note.

## Keyboard Shortcuts

### File

| Shortcut | Action |
|---|---|
| Cmd+N | New Note |
| Cmd+F | New Folder |
| Cmd+T | New Tag |
| Cmd+Opt+Delete | Empty Trash |

### Edit

| Shortcut | Action |
|---|---|
| Cmd+S | Toggle Star |
| Cmd+R | Rename |
| Cmd+Delete | Delete |
| Cmd+Opt+C | Copy Markdown Link |
| Cmd+Opt+F | Magic Format |
| Cmd+Opt+A | Magic Assistant (with text selected) |

### View

| Shortcut | Action |
|---|---|
| Cmd+P | Toggle Preview |
| Cmd+Opt+B | Show Backlinks |

### Window

| Shortcut | Action |
|---|---|
| Cmd+Shift+C | Open Chat Window |
| Cmd+Shift+E | Open Editor Window |

## URL Scheme

TakeNote registers the `takenote://` URL scheme. Opening `takenote://note/<UUID>` navigates directly to that note. Note URLs can be used in other apps, bookmarks, or automation workflows.

## Technologies

- SwiftUI
- SwiftData
- CloudKit
- Apple Foundation Models

## Source Available License

TakeNote is distributed under a permissive **source-available license**.

- You are free to clone the code, build it, and run it for your **personal use**.
- You may fork the project for personal use.
- You may not distribute compiled binaries of TakeNote or any fork/derivative project, whether free or paid.

We welcome and encourage contributions! You are more than welcome to submit pull requests to add features or fix bugs. All accepted contributions are licensed back to TakeNote under the same license.
