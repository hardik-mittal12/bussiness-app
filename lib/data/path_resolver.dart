export 'path_resolver_stub.dart'
    if (dart.library.js_interop) 'path_resolver_web.dart'
    if (dart.library.io) 'path_resolver_native.dart';
