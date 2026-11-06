# Aha! copy of Saber

A personal copy of [Saber](https://github.com/saber-notes/saber) with the
additions below. Everything else is standard Saber.

## What's added

| Feature | Where | Notes |
|---|---|---|
| **Convert to text** | Lasso some handwriting, then tap the **T** button on the selection bar | Runs on the tablet with Google's ML Kit (English, Australia). The language pack downloads once, then works offline. Android only. The text goes into the page's typed text, which starts at the top of the page; you can choose to remove the handwriting. |
| **Insert table** | Toolbar, table button (next to Images) | Pick rows and columns. The table is drawn as straight lines, so the standard Saber apps (including the Mac App Store version) show it. It's selected after inserting, so you can drag it into place, then write in the cells. |
| **Bookmarks (client notebooks)** | Bookmarks button beside Pages in a note's top bar | A panel floats on the right. **New meeting** adds a page at the end, bookmarked with today's date; **Bookmark this page** names and dates the current page. Tap a bookmark to jump; long-press (or the pencil) to rename, re-date or remove. Optionally writes the name and date at the top of the page, so the Mac app shows them. Stored beside the note in `<note>.sbn2.bm`, which syncs and which the standard Saber leaves alone. |
| **Palm and sleeve guards** | Settings › Writing | While the pen is near (or for 1 s after it lifts; 0.5 to 3 s) touch on the page is ignored. One finger doesn't move the page; scroll and zoom with two. Each can be switched off. Saber's single-finger pan lock (a button at the top left of the page) no longer stops two-finger scrolling, and its button is hidden while two-finger scrolling is on. |
| **Default page design** | Settings › New pages | Line style, spacing and thickness (Saber's sliders), page colour (presets or any colour), starting pen. A note's page menu has "Make this my default for new notes". |
| **Quick note** | The **Quick note** button beside + New note | Opens a blank note straight away with Saber's dated name and your default page design. Rename it later with the pencil beside its name. |
| **New note sheet** | The solid **+ New note** button (bottom right), or **New note** in the side bar (where the Whiteboard was) | Asks for name, folder and line style. Type the name, write it with the pen in the box below (read on the tablet a moment after you stop), or tap **Skip** for Saber's dated name. The bookmark dialog has the same pen box. Scribble over written words in the pen box to rub them out. Touching an open note's name with the pen opens a Rename box with the same pen box (a finger still types). The note's name is outlined with a pencil; a Saved / Saving… / Not saved yet sign sits beside it. Back (button or gesture) saves and leaves in one tap. |
| **Side bar** | Home | 220 points wide, floats over the notes, closes when you tap outside or choose something. |
| **No Whiteboard** | Side bar | The Whiteboard (a scratch page that never became a named note) is replaced by New note. Anything left on it is moved once into a note called "Whiteboard <date>" at the top of Recent notes. Import is the small button beside + New note. |
| **Colour bar** | The colour circle in a note's toolbar turns it on and off | It stays open while you write and pick colours, and is still open in the next note, until you tap the colour circle again. A small bar with six colours: black, blue, orange, green, red and grey for pens; yellow, green, pink, blue, orange and purple for the highlighter. Tap a colour to use it. Tap the one in use again (or press and hold any) to change it with the colour wheel or by typing its code; the new colour stays in that spot. Drag the bar's handle (the dots) to any edge and it snaps there; it opens wherever you last left it (the right to start with). |
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
- `lib/components/toolbar/convert_to_text_dialog.dart`,
  `insert_table_dialog.dart`: the dialogs
- `lib/pages/editor/editor.dart`: `convertSelectionToText()`, `insertTable()`
- Tests: `test/handwriting_ink_lines_test.dart`, `test/table_lines_test.dart`,
  `test/editor_table_and_convert_test.dart`

## Keeping up with Saber

On GitHub, the fork's **Sync fork** button pulls in new Saber releases. If it
reports a conflict, ask Claude to merge it.
