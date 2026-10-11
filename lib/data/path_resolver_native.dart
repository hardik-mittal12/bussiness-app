import 'dart:io';
import 'package:path/path.dart' as p;

String? _cachedStoragePath;

Future<String> getAppStorageDirectoryPath() async {
  if (_cachedStoragePath != null) {
    return _cachedStoragePath!;
  }

  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final appSupport = Directory(p.join(home, 'Library', 'Application Support', 'tally_ledger_desktop'));
    if (!appSupport.existsSync()) {
      appSupport.createSync(recursive: true);
    }
    _cachedStoragePath = appSupport.path;
    return appSupport.path;
  }

  if (Platform.isWindows) {
    // Windows standard AppData directory
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final dir = Directory(p.join(appData, 'tally_ledger_desktop'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cachedStoragePath = dir.path;
    return dir.path;
  }

  // Linux / other Unix
  final xdgData = Platform.environment['XDG_DATA_HOME'];
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  final baseDir = (xdgData != null && xdgData.isNotEmpty)
      ? xdgData
      : p.join(home, '.local', 'share');
  final dir = Directory(p.join(baseDir, 'tally_ledger_desktop'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  _cachedStoragePath = dir.path;
  return dir.path;
}

Future<String> getCustomDatabasePath(String name) async {
  // Check if database already exists next to executable (portable USB mode)
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final localDb = File(p.join(exeDir, '$name.sqlite'));
  if (localDb.existsSync()) {
    return localDb.path;
  }

  // Otherwise, use standard application storage directory
  final storageDir = await getAppStorageDirectoryPath();
  return p.join(storageDir, '$name.sqlite');
}

Future<String> getTempDirectoryPath() async {
  final temp = Directory.systemTemp;
  if (!temp.existsSync()) {
    temp.createSync(recursive: true);
  }
  return temp.path;
}
