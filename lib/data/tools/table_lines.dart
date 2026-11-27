import 'dart:ui';

/// The straight lines that draw a table grid.
///
/// Tables are inserted as ordinary straight-line strokes (the same shape
/// the shape pen makes for a line), so notes stay readable by the standard
/// Saber apps, including the Mac App Store version.
abstract final class TableLines {
  static const minRows = 1, maxRows = 20;
  static const minColumns = 1, maxColumns = 10;

  /// Returns the start and end of each line in a [rows] × [columns] grid
  /// filling [rect]: the horizontal lines top to bottom, then the vertical
  /// lines left to right.
  static List<(Offset, Offset)> build(Rect rect, int rows, int columns) {
    assert(rows >= minRows && rows <= maxRows);
    assert(columns >= minColumns && columns <= maxColumns);
    final rowHeight = rect.height / rows;
    final columnWidth = rect.width / columns;
    return [
      for (var r = 0; r <= rows; r++)
        (
          Offset(rect.left, rect.top + rowHeight * r),
          Offset(rect.right, rect.top + rowHeight * r),
        ),
      for (var c = 0; c <= columns; c++)
        (
          Offset(rect.left + columnWidth * c, rect.top),
          Offset(rect.left + columnWidth * c, rect.bottom),
        ),
    ];
  }

  /// Where a new table goes on a page of [pageSize]: 80% of the page wide,
  /// centred, with rows tall enough to write in, and never taller than
  /// 80% of the page.
  static Rect placement(Size pageSize, int rows) {
    final width = pageSize.width * 0.8;
    final rowHeight = pageSize.width * 0.06;
    final height = (rowHeight * rows).clamp(0.0, pageSize.height * 0.8);
    return Rect.fromCenter(
      center: pageSize.center(Offset.zero),
      width: width,
      height: height,
    );
  }
}
