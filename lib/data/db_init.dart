// Выбирает нужную реализацию SQLite для текущей платформы:
// Android/iOS — обычный sqflite, Windows/Linux — FFI, браузер — WebAssembly.
export 'db_init_stub.dart'
    if (dart.library.io) 'db_init_io.dart'
    if (dart.library.js_interop) 'db_init_web.dart';
