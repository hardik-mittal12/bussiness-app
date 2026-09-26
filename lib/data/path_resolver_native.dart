import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> getAppStorageDirectoryPath() async {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final appSupport = Directory(p.join(home, 'Library', 'Application Support', 'tally_ledger_desktop'));
    if (!appSupport.existsSync()) {
      appSupport.createSync(recursive: true);
    }
    return appSupport.path;
  }

  // Windows / Linux:
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  // Test if exeDir is writable (e.g., portable USB mode or standalone folder)
  try {
    final testFile = File(p.join(exeDir, '.perm_test_${DateTime.now().millisecondsSinceEpoch}'));
    testFile.writeAsStringSync('1');
    testFile.deleteSync();
    return exeDir;
  } catch (_) {
    // If exeDir is read-only (e.g. installed under Program Files on Windows), use APPDATA / HOME
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    final fallbackDir = Directory(p.join(appData, 'tally_ledger_desktop'));
    if (!fallbackDir.existsSync()) {
      fallbackDir.createSync(recursive: true);
    }
    return fallbackDir.path;
  }
}

Future<String> getCustomDatabasePath(String name) async {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final appSupport = Directory(p.join(home, 'Library', 'Application Support', 'tally_ledger_desktop'));
    if (!appSupport.existsSync()) {
      appSupport.createSync(recursive: true);
    }
    return p.join(appSupport.path, '$name.sqlite');
  }

  // Check if database already exists next to executable (portable USB mode)
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final localDb = File(p.join(exeDir, '$name.sqlite'));
  if (localDb.existsSync()) {
    return localDb.path;
  }

  // Otherwise, use app storage directory (which checks writability)
  final storageDir = await getAppStorageDirectoryPath();
  return p.join(storageDir, '$name.sqlite');
}

Future<String> getTempDirectoryPath() async {
  return Directory.systemTemp.path;
}
