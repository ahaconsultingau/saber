# Aha! copy of Saber

A personal copy of [Saber](https://github.com/saber-notes/saber) with the
additions below. Everything else is standard Saber.

## What's added

| Feature | Where | Notes |
|---|---|---|
| **Convert to text** | Lasso some handwriting, then tap the **T** button on the selection bar | Runs on the tablet with Google's ML Kit (English, Australia). The language pack downloads once, then works offline. Android only. The text goes into the page's typed text, which starts at the top of the page; you can choose to remove the handwriting. |
| **Insert table** | Toolbar, table button (next to Images) | Pick rows and columns. The table is drawn as straight lines, so the standard Saber apps (including the Mac App Store version) show it. It's selected after inserting, so you can drag it into place, then write in the cells. |
| **Bookmarks (client notebooks)** | Bookmarks button beside Pages in a note's top bar | A panel floats on the right. **New meeting** adds a page at the end, bookmarked with today's date; **Bookmark this page** names and dates the current page. Tap a bookmark to jump; long-press (or the pencil) to rename, re-date or remove. Optionally writes the name and date at the top of the page, so the Mac app shows them. Stored beside the note in `<note>.sbn2.bm`, which syncs and which the standard Saber leaves alone. |
| **Palm and sleeve guards** | Settings › Writing | While the pen is near (or for 1 s after it lifts; 0.5 to 3 s) touch on the page is ignored. One finger doesn't move the page; scroll and zoom with two. Each can be switched off. Saber's single-finger pan lock (a button at the top left of the page) no longer stops two-finger scrolling, and its button is hidden while two-finger scrolling is on. The pen is tracked apart from fingers, so a wrist already resting on the page doesn't stop or scroll the stroke. Android's swipe back is ignored for 1.5 s after the pen was near (a wrist on the screen edge reads as a swipe back); the back arrow at the top always leaves. |
| **Default page design** | Settings › New pages | Line style, spacing and thickness (Saber's sliders), page colour (presets or any colour), starting pen. A note's page menu has "Make this my default for new notes". |
| **Quick note** | The **Quick note** button beside + New note | Opens a blank note straight away with Saber's dated name and your default page design. Rename it later with the pencil beside its name. |
| **New note sheet** | The solid **+ New note** button (bottom right), or **New note** in the side bar (where the Whiteboard was) | Asks for name, folder and line style. Type the name, write it straight into the box with the pen (the tablet's own handwriting, as in other apps; needs **Write in text fields** on in the keyboard's settings), or tap **Skip** for Saber's dated name. The same goes for an open note's name and bookmark names. The tablet's scratch-out and other pen gestures don't work in Saber yet (Flutter doesn't support them). The note's name is outlined with a pencil; a Saved / Saving… / Not saved yet sign sits beside it. Back (button or gesture) saves and leaves in one tap. |
| **Side bar** | Home | 220 points wide, floats over the notes, closes when you tap outside or choose something. |
| **No Whiteboard** | Side bar | The Whiteboard (a scratch page that never became a named note) is replaced by New note. Anything left on it is moved once into a note called "Whiteboard <date>" at the top of Recent notes. Import is the small button beside + New note. |
| **Colour bar** | The colour circle in a note's toolbar turns it on and off | It stays open while you write and pick colours, and is still open in the next note, until you tap the colour circle again. A small bar with six colours: black, blue, orange, green, red and grey for pens; yellow, green, pink, blue, orange and purple for the highlighter. Tap a colour to use it. Tap the one in use again (or press and hold any) to change it with the colour wheel or by typing its code; the new colour stays in that spot. Drag the bar's handle (the dots) to any edge and it snaps there; it opens wherever you last left it (the right to start with). |
| **Paint fill** | The paint-bucket button after the highlighter (the colour bar opens with it) | Tap inside a closed outline with the pen: it fills with solid colour, under the ink, so writing inside stays on top and holes in letters stay clear. One tap per shape. Gaps up to about 5 mm are closed for you; with a bigger gap nothing is filled and a message says to close it. Filling again recolours. Saved as ordinary shape-pen strokes, so the Mac app shows it; undo, lasso and eraser work on it. |
| **Import from Noteshelf** | The small Import button beside + New note; pick one or more `.nsa` files (Google Drive shows in the picker) | Each Noteshelf notebook becomes a Saber note with the same pages, its handwriting as real, editable strokes (colours, highlighter, straight lines and ovals), lined paper and its bookmarks. Typed text boxes and pictures aren't brought across (it says how many). Worked out from a real notebook exported by Noteshelf 3 on the tablet; Noteshelf doesn't publish the format, so a future Noteshelf update could change it. |
| **Brush** | Tap the pen in use; choose the paintbrush beside the fountain pen, ballpoint and shape pen | A soft brush: thick when pressed, thin when light, tapered ends; its size has its own slider (2 to 60). **Feathering** (0 to 100%, beside the size) softens the edges; the brush remembers both. Saved as a fountain-pen stroke with brush settings, so the Mac app draws it the same, except feathering: the Mac shows feathered strokes with crisp edges. |
| **Eraser size** | Choose the eraser: a slider appears above the toolbar | 3 to 80 (Saber's was fixed at 10). Remembered for next time. |
| **Drag notes into folders** | Browse | Press and hold a note, then drag it onto a folder (or onto the back-arrow card to move it up a level) and let go. If several notes are selected, dragging one of them moves them all. Press and hold without dragging still selects, as before. |
| **Password locks** | Notes: long-press a note, then the lock in the bar. Folders: long-press a folder in Browse, then the lock | A locked note (or any note in a locked folder) asks for its password before it opens, and its preview and folder contents are hidden. Everything locks again when the app has been left for 2 minutes. Inside Saber Aha only: the files aren't encrypted (the Mac's Saber still opens them), and passwords are kept on this tablet as salted hashes. A forgotten password can't be recovered in Saber Aha. |
| **Drawings (Draw mode, step 1)** | The **Draw** button between Quick note and New note, or **New drawing** in the side bar | Asks for a name (or Skip), folder, paper (plain, dots, squares or isometric) and shape (portrait, landscape or square); opens with the brush. A drawing shows a brush badge on its preview. On a drawing only, a **Draw** row above the toolbar has **Grid** (change or hide the guide grid; undo works) and **Flip view** (mirrors the page to check proportions; the drawing itself isn't changed, and the pen still lands where you touch). Any note can become a drawing, or back, from the ⋮ menu. A drawing is an ordinary note plus a small companion file (`<note>.sbn2.dw`), so the Mac's Saber opens and saves it as a note without undoing it; the isometric grid shows as plain paper there. |
| **Pages panel** | Pages button in a note's top bar | Opens on the right, in the same spot as Bookmarks (was a box in the middle). |

## Builds

- The Android app is built by GitHub Actions (**Build for Android**) on
  every push that changes the app (`lib/`, `android/`, `assets/`,
  `packages/`, `pubspec.*`) or the workflow, or by hand from the Actions tab.
- Each build is published as its own release, `v<version>-aha.<build>`
  (e.g. `v1.37.1-aha.3`), with the file `Saber-Aha.apk`. The app's version
  name matches the release, so **Obtainium** on the tablet (watching
  `https://github.com/ahaconsultingau/saber`) offers each update.
  https://github.com/ahaconsultingau/saber/releases/latest always opens the
  newest.
- A build of a commit that changes a file in `.github/workflows/` can't
  publish its release: GitHub refuses the new tag ("Not Found"). Keep
  workflow changes in their own commit; then run **Build for Android** by
  hand (Actions tab, Run workflow, this branch) to publish the app.
- It installs as a separate app, **Saber Aha** (`com.adilhanney.saber.aha`),
  so it doesn't clash with the Play Store Saber.
- Update checks are off, so it never prompts to install upstream Saber.
- The FOSS (F-Droid) build is skipped: it strips the Google library that
  handwriting recognition needs.
- The Mac uses the standard Saber from the Mac App Store.

## Code

- `lib/data/handwriting/`: line grouping (`ink_lines.dart`) and the ML Kit
  call (`handwriting_recognizer.dart`)
- `lib/data/tools/table_lines.dart`: table geometry
- `lib/data/tools/fill.dart`: paint fill (grid, flood fill, gap closing)
- `lib/data/aha/note_drawings.dart`, `lib/components/home/new_drawing_dialog.dart`, `lib/components/toolbar/draw_row.dart`: drawings (companion file, New drawing sheet, Draw row); the isometric grid is in `packages/sbn` and `_canvas_background_painter.dart`
- `lib/components/toolbar/aha_slider.dart`: the eraser-size and feathering sliders; feathering is the stroke's `aF` key, drawn as a blur in `_canvas_painter.dart`
- `lib/components/home/preview_card.dart` (`NoteDrag`), `grid_folders.dart` (drop targets), `lib/pages/home/browse.dart` (`moveNotesTo`): drag notes into folders
- `lib/data/aha/note_locks.dart`, `lib/components/aha/lock_widgets.dart`: password locks
- `lib/data/aha/noteshelf_import.dart`, `sqlite_reader.dart`: Noteshelf `.nsa` import (a small read-only SQLite reader, so no database library is added)
- `lib/components/toolbar/convert_to_text_dialog.dart`,
  `insert_table_dialog.dart`: the dialogs
- `lib/pages/editor/editor.dart`: `convertSelectionToText()`, `insertTable()`
- Tests: `test/handwriting_ink_lines_test.dart`, `test/table_lines_test.dart`,
  `test/editor_table_and_convert_test.dart`, `test/eraser_brush_folders_test.dart`, `test/draw_mode_test.dart`

## Keeping up with Saber

On GitHub, the fork's **Sync fork** button pulls in new Saber releases. If it
reports a conflict, ask Claude to merge it.
