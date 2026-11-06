# Aha! copy of Saber

A personal copy of [Saber](https://github.com/saber-notes/saber) with two
additions. Everything else is standard Saber.

## What's added

| Feature | Where | Notes |
|---|---|---|
| **Convert to text** | Lasso some handwriting, then tap the **T** button on the selection bar | Runs on the tablet with Google's ML Kit (English, Australia). The language pack downloads once, then works offline. Android only. The text goes into the page's typed text, which starts at the top of the page; you can choose to remove the handwriting. |
| **Insert table** | Toolbar, table button (next to Images) | Pick rows and columns. The table is drawn as straight lines, so the standard Saber apps (including the Mac App Store version) show it. It's selected after inserting, so you can drag it into place, then write in the cells. |

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
