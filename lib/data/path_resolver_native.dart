import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> getCustomDatabasePath(String name) async {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final appSupport = Directory(p.join(home, 'Library', 'Application Support', 'tally_ledger_desktop'));
    if (!appSupport.existsSync()) {
      appSupport.createSync(recursive: true);
    }
    return p.join(appSupport.path, '$name.sqlite');
  }
  // On native desktop (Windows/Linux), save inside the parent folder of the running executable.
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return p.join(exeDir, '$name.sqlite');
}

Future<String> getAppStorageDirectoryPath() async {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final appSupport = Directory(p.join(home, 'Library', 'Application Support', 'tally_ledger_desktop'));
    if (!appSupport.existsSync()) {
      appSupport.createSync(recursive: true);
    }
    return appSupport.path;
  }
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return exeDir;
}

Future<String> getTempDirectoryPath() async {
  return Directory.systemTemp.path;
}
