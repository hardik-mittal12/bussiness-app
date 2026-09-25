import 'dart:typed_data';

class File {
  final String path;
  File(this.path);

  bool existsSync() => false;
  Future<bool> exists() async => false;
  Uint8List readAsBytesSync() => Uint8List(0);
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<String> readAsString() async => '';
  Future<void> writeAsString(String content) async {}
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<void> delete({bool recursive = false}) async {}
  Directory get parent => Directory('');
}

class Directory {
  final String path;
  Directory(this.path);

  bool existsSync() => false;
  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
  Future<void> delete({bool recursive = false}) async {}
  List<dynamic> listSync() => [];
  Stream<dynamic> list() => const Stream.empty();
}

class Platform {
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static String get resolvedExecutable => '';
  static String get pathSeparator => '/';
}

class Process {
  static Future<dynamic> run(String executable, List<String> arguments) async {
    return null;
  }
}
