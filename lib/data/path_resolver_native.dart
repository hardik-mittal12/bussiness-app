import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> getCustomDatabasePath(String name) async {
  // On native platforms, save inside the parent folder of the running executable.
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  return p.join(exeDir, '$name.sqlite');
}
