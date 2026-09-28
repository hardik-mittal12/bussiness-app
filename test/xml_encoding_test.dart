import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tally_ledger_desktop/core/data_exchange_service.dart';

void main() {
  group('decodeXmlBytes', () {
    test('decodes UTF-8 XML with a BOM', () {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('<ROOT>café</ROOT>')];

      expect(decodeXmlBytes(bytes), '<ROOT>café</ROOT>');
    });

    test('decodes Windows-1252 XML', () {
      final prefix = ascii.encode('<?xml version="1.0" encoding="windows-1252"?><ROOT>price ');
      final suffix = ascii.encode('</ROOT>');
      final bytes = <int>[...prefix, 0x80, ...suffix];

      expect(decodeXmlBytes(bytes), '<?xml version="1.0" encoding="windows-1252"?><ROOT>price €</ROOT>');
    });

    test('decodes UTF-16 little-endian XML with a BOM', () {
      final content = '<ROOT>stock</ROOT>'.codeUnits;
      final bytes = <int>[0xFF, 0xFE];
      for (final unit in content) {
        bytes
          ..add(unit & 0xFF)
          ..add(unit >> 8);
      }

      expect(decodeXmlBytes(bytes), '<ROOT>stock</ROOT>');
    });

    test('falls back to Windows-1252 when legacy XML has no declaration', () {
      final bytes = <int>[...utf8.encode('<ROOT>'), 0x80, ...utf8.encode('</ROOT>')];

      expect(decodeXmlBytes(bytes), '<ROOT>€</ROOT>');
    });
  });
}