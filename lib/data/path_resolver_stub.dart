Future<String> getCustomDatabasePath(String name) {
  throw UnsupportedError('Cannot get custom database path on this platform');
}

Future<String> getAppStorageDirectoryPath() async => '';
Future<String> getTempDirectoryPath() async => '';
