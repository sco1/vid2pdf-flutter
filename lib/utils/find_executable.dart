import 'dart:io';

import 'package:vid2pdf/main.dart';

/// BFS for [exeName] within [root], descending at most [maxDepth] levels.
///
/// Returns the shallowest match, or `null` if none is found. Directories that can't be listed (e.g.
/// access denied) are skipped, and directory symlinks aren't followed to avoid cycles.
///
/// NOTE: Links are accepted as valid matches, e.g. Homebrew's bin/ffmpeg symlinks into its Cellar
///
/// NOTE: To avoid behavior changes based on OS differences in case sensitivity in paths, comparison
/// between [exeName] and match candidates is accomplished by normalizing both to lowercase. Any
/// matched file is returned in its original casing.
Future<String?> findExecutable(Directory root, String exeName, {required int maxDepth}) async {
  final String target = exeName.toLowerCase();

  var level = [root];
  for (var depth = 0; depth <= maxDepth && level.isNotEmpty; depth++) {
    final next = <Directory>[];
    for (final dir in level) {
      final List<FileSystemEntity> entries;
      try {
        entries = await dir.list(followLinks: false).toList()
          ..sort((a, b) => a.path.compareTo(b.path));
      } on FileSystemException {
        continue;
      }

      for (final entry in entries) {
        final bool isMatch = baseContext.basename(entry.path).toLowerCase() == target;
        if ((entry is File || entry is Link) && isMatch) {
          return entry.path;
        }
        if (entry is Directory) {
          next.add(entry);
        }
      }
    }
    level = next;
  }

  return null;
}
