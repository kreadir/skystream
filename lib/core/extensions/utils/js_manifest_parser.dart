import 'dart:convert';
import 'package:flutter/foundation.dart';

class JsManifestParser {
  /// Extracts and parses the `getManifest()` return object from a JavaScript file content.
  /// 
  /// Handles:
  /// - Unquoted keys (e.g. `key: "value"`)
  /// - Unquoted variable values (e.g. `"baseUrl": mainUrl` -> `"baseUrl": "mainUrl"`)
  /// - Trailing commas
  static Map<String, dynamic>? parse(String content) {
    try {
      // Regex to find return { ... }; inside getManifest
      final regex = RegExp(
        r'getManifest\s*\(\s*\)\s*\{\s*return\s*(\{[\s\S]*?\});',
        multiLine: true,
      );
      final match = regex.firstMatch(content);

      if (match != null) {
        String jsonStr = match.group(1)!;

        // Quote keys (key: -> "key":)
        jsonStr = jsonStr.replaceAllMapped(
          RegExp(r'(\w+)\s*:'),
          (m) => '"${m[1]}":',
        );

        // Quote unquoted identifiers (variables/constants) as string values
        // This handles cases like "baseUrl": mainUrl -> "baseUrl": "mainUrl"
        // Ignores booleans and null
        jsonStr = jsonStr.replaceAllMapped(
          RegExp(r':\s*([a-zA-Z_$][a-zA-Z0-9_$]*)'),
          (m) {
            final val = m.group(1)!;
            if (['true', 'false', 'null'].contains(val)) return ': $val';
            return ': "$val"';
          },
        );

        // Remove trailing commas
        jsonStr = jsonStr.replaceAll(RegExp(r',\s*\}'), '}');

        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("JsManifestParser: Error parsing manifest: $e");
    }
    return null;
  }
}
