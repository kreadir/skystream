import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import '../../storage/extension_repository.dart';
import '../../network/cloudflare_bypass.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;

import '../../network/dio_client_provider.dart';

class JsPluginException implements Exception {
  final String code;
  final String message;
  final String? pluginId;

  JsPluginException(this.code, this.message, {this.pluginId});

  @override
  String toString() => "JsPluginException[$code]: $message";
}

final jsEngineProvider = Provider.autoDispose<JsEngineService>((ref) {
  final storage = ref.read(extensionRepositoryProvider);
  final dio = ref.read(dioClientProvider);
  final service = JsEngineService(storage, dio);
  ref.onDispose(() => service.dispose());
  return service;
});

class JsEngineService {
  late JavascriptRuntime _runtime;
  final Dio _dio;
  final CookieJar _cookieJar = CookieJar(); // RAM-based cookie jar
  final ExtensionRepository _storage;

  // Persistent callback registry to prevent memory leaks from dynamic listeners
  final Map<String, Completer<dynamic>> _pendingCallbacks = {};

  JsEngineService(this._storage, this._dio) {
    final bool hasCookieManager = _dio.interceptors.any(
      (i) => i is CookieManager,
    );
    if (!hasCookieManager) {
      _dio.interceptors.add(CookieManager(_cookieJar));
    }
    // DohInterceptor is provided globally by dioClientProvider
    _runtime = getJavascriptRuntime();
    // Defer polyfill injection to avoid blocking the UI thread
    Future.microtask(() => _initPolyfills());
  }

  void _initPolyfills() {
    // 1. Persistent Callback Dispatcher (Receiver)
    _runtime.onMessage('js_dispatch_callback', (dynamic args) {
      try {
        Map<String, dynamic> data;
        if (args is Map) {
          data = Map<String, dynamic>.from(args);
        } else {
          data = jsonDecode(args);
        }

        final String? id = data['callbackId'];
        final dynamic result = data['result'];
        final dynamic error = data['error'];

        if (id != null) {
          final completer = _pendingCallbacks.remove(id);
          if (completer != null && !completer.isCompleted) {
            if (error != null) {
              completer.completeError(error);
            } else {
              completer.complete(result);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint("[JS Dispatch Error] $e");
      }
    });

    // 2. Async Timer Bridge (Receiver)
    _runtime.onMessage('js_set_timeout', (dynamic args) {
      try {
        final Map<String, dynamic> data = args is Map
            ? Map<String, dynamic>.from(args)
            : jsonDecode(args);
        final id = data['id'];
        final delay = data['delay'] ?? 0;

        Future.delayed(Duration(milliseconds: delay), () {
          _runtime.evaluate(
            "if (globalThis.timeout_registry['$id']) { globalThis.timeout_registry['$id'](); }",
          );
        });
      } catch (e) {
        if (kDebugMode) debugPrint("[JS Timer Bridge Error] $e");
      }
    });

    // Console Polyfill
    _runtime.onMessage('console_log', (dynamic args) {
      if (kDebugMode) debugPrint("[JS] ${_sanitizeLog(args)}");
    });
    _runtime.onMessage('console_error', (dynamic args) {
      if (kDebugMode) debugPrint("[JS ERROR] ${_sanitizeLog(args)}");
    });

    _runtime.evaluate("""
      var global = globalThis;
      var console = {
        log: function(msg) { sendMessage('console_log', JSON.stringify(msg)); },
        error: function(msg) { sendMessage('console_error', JSON.stringify(msg)); },
        warn: function(msg) { sendMessage('console_log', "WARN: " + JSON.stringify(msg)); }
      };
      
      // Legacy log function
      function log(msg) { console.log(msg); }

      // 1. Persistent Callback Dispatcher (JS Sender)
      globalThis.executeCallback = function(id, result, error) {
        sendMessage('js_dispatch_callback', JSON.stringify({
          callbackId: id,
          result: result,
          error: error
        }));
      };
    """);

    // HTTP Polyfill (Dio Bridge)
    _runtime.onMessage('http_request', (dynamic args) async {
      return await _handleHttp(args);
    });

    // Storage Bridge
    _runtime.onMessage('set_storage', (dynamic args) async {
      return await _handleStorage(args, true);
    });
    _runtime.onMessage('get_storage', (dynamic args) {
      return _handleStorage(args, false);
    });

    // Crypto Bridge
    _runtime.onMessage('crypto_decrypt_aes', (dynamic args) async {
      try {
        Map<String, dynamic> req;
        if (args is Map) {
          req = Map<String, dynamic>.from(args);
        } else {
          req = jsonDecode(args);
        }

        String normalizeB64(String input) {
          String cleaned = input.replaceAll(RegExp(r'\s+'), '');
          while (cleaned.length % 4 != 0) {
            cleaned += '=';
          }
          return cleaned;
        }

        final String encryptedB64 = normalizeB64(req['data']);
        final String keyB64 = normalizeB64(req['key']);
        final String ivB64 = normalizeB64(req['iv']);

        final key = encrypt_lib.Key.fromBase64(keyB64);
        final iv = encrypt_lib.IV.fromBase64(ivB64);
        final encrypter = encrypt_lib.Encrypter(
          encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
        );
        final decrypted = encrypter.decrypt64(encryptedB64, iv: iv);

        return decrypted;
      } catch (e) {
        if (kDebugMode) debugPrint("[JS Crypto Error] ${e.toString()}");
        return "";
      }
    });

    _runtime.evaluate("""
      async function _dartHttp(method, url, headers, body) {
         try {
            return await sendMessage('http_request', JSON.stringify({
              method: method,
              url: url,
              headers: headers,
              body: body
            }));
         } catch(e) {
            console.error("HTTP Bridge Error: " + e);
            throw e;
         }
      }

      function http_get(url, headers, cb) {
         var promise = _dartHttp('GET', url, headers, null);
         if (cb && typeof cb === 'function') {
            promise.then(cb).catch(function(err) { cb({status: 0, body: ""}); });
         }
         return promise;
      }
      
      async function _fetch(url) {
          var res = await http_get(url, {});
          if (res.statusCode >= 200 && res.statusCode < 300) {
              return res.body; 
          } else {
              throw "HTTP Error " + res.statusCode + " fetching " + url;
          }
      }
      
      function http_post(url, headers, body, cb) {
         var promise = _dartHttp('POST', url, headers, body);
         if (cb && typeof cb === 'function') {
            promise.then(cb).catch(function(err) { cb({status: 0, body: ""}); });
         }
         return promise;
      }
    """);

    // 2. Timer Polyfill (Bridged)
    _runtime.evaluate("""
      globalThis.timeout_registry = {};

    function setTimeout(callback, delay) {
      var id = "t_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
      globalThis.timeout_registry[id] = function() {
        if (!globalThis.timeout_registry[id]) return;
        delete globalThis.timeout_registry[id];
        try { callback(); } catch (e) { console.error('Timeout error:', e); }
      };
      sendMessage('js_set_timeout', JSON.stringify({ id: id, delay: delay || 0 }));
      return id;
    }

    function clearTimeout(id) {
      if (id) delete globalThis.timeout_registry[id];
    }

    function setInterval(cb, d) {
      var id = "i_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
      var wrapper = function() {
        if (!globalThis.timeout_registry[id]) return;
        try { cb(); } catch (e) { console.error('Interval error:', e); }
        if (globalThis.timeout_registry[id]) {
          sendMessage('js_set_timeout', JSON.stringify({ id: id, delay: d || 0 }));
        }
      };
      globalThis.timeout_registry[id] = wrapper;
      sendMessage('js_set_timeout', JSON.stringify({ id: id, delay: d || 0 }));
      return id;
    }

    function clearInterval(id) {
      clearTimeout(id);
    }

      // Storage Polyfill
      function setPreference(key, value) {
          sendMessage('set_storage', JSON.stringify({ key: key, value: value }));
      }
      async function getPreference(key) {
          return await sendMessage('get_storage', JSON.stringify({ key: key }));
      }
    """);

    // Standard Entities
    _runtime.evaluate("""
      class MultimediaItem {
        constructor({ title, url, posterUrl, type, bannerUrl, description, episodes, headers, provider }) {
          this.title = title;
          this.url = url;
          this.posterUrl = posterUrl;
          this.type = type || 'movie';
          this.bannerUrl = bannerUrl;
          this.description = description;
          this.episodes = episodes;
          this.headers = headers;
          this.provider = provider;
        }
      }

      class Episode {
        constructor({ name, url, season, episode, description, posterUrl, headers }) {
          this.name = name;
          this.url = url;
          this.season = season || 0;
          this.episode = episode || 0;
          this.description = description;
          this.posterUrl = posterUrl;
          this.headers = headers;
        }
      }

      class StreamResult {
        constructor({ url, quality, headers, subtitles, drmKid, drmKey, licenseUrl }) {
          this.url = url;
          this.quality = quality || 'Auto';
          this.headers = headers;
          this.subtitles = subtitles;
          this.drmKid = drmKid;
          this.drmKey = drmKey;
          this.licenseUrl = licenseUrl;
        }
      }

      globalThis.MultimediaItem = MultimediaItem;
      globalThis.Episode = Episode;
      globalThis.StreamResult = StreamResult;

      var CloudStream = {
         getLanguage: function() { return "en"; },
         getRegion: function() { return "US"; }
      };
      var source = {
         baseUrl: "",
         getStreamUrl: function() { return ""; }
      };
    """);
  }

  Future<Map<String, dynamic>> _handleHttp(dynamic args) async {
    final requestId =
        "req_${DateTime.now().microsecondsSinceEpoch.toString().substring(10)}";
    try {
      Map<String, dynamic> req;
      if (args is Map) {
        req = Map<String, dynamic>.from(args);
      } else {
        req = jsonDecode(args);
      }

      final String method = req['method'] ?? 'GET';
      final String url = req['url'];
      final Map<String, dynamic>? headers = req['headers'] != null
          ? Map<String, dynamic>.from(req['headers'])
          : null;
      final dynamic body = req['body'];

      debugPrint("[JS HTTP] $method $url ($requestId)");

      final response = await _dio.request(
        url,
        data: body,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );

      debugPrint("[JS HTTP] Back $url ($requestId) -> ${response.statusCode}");

      final responseHeaders = response.headers.map.map(
        (k, v) => MapEntry(k, v.join(',')),
      );
      final responseBody = response.data.toString();

      if (CloudflareBypass.instance.isCloudflareChallenge(
        response.statusCode,
        responseHeaders,
        responseBody,
      )) {
        final cfResult = await CloudflareBypass.instance.solveAndFetch(url);
        if (cfResult != null) {
          return {
            'code': cfResult.statusCode,
            'statusCode': cfResult.statusCode,
            'status': cfResult.statusCode,
            'body': cfResult.body,
            'headers': <String, String>{},
            'finalUrl': cfResult.finalUrl,
          };
        }
      }

      return {
        'code': response.statusCode,
        'statusCode': response.statusCode,
        'status': response.statusCode,
        'body': responseBody,
        'headers': responseHeaders,
        'finalUrl': response.realUri.toString(),
      };
    } catch (e) {
      if (kDebugMode) debugPrint("[JS HTTP ERROR] $requestId: $e");
      return {
        'code': 0,
        'statusCode': 0,
        'status': 0,
        'body': '',
        'error': e.toString(),
      };
    }
  }

  Future<dynamic> _handleStorage(dynamic args, bool isSet) async {
    try {
      Map<String, dynamic> data;
      if (args is Map) {
        data = Map<String, dynamic>.from(args);
      } else {
        data = jsonDecode(args);
      }
      final key = data['key'];

      if (isSet) {
        final value = data['value'];
        await _storage.setExtensionData(key, value);
        return "OK";
      } else {
        return _storage.getExtensionData(key);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("JS eval error: $e");
      return null;
    }
  }

  Future<void> loadScript(String script) async {
    final res = _runtime.evaluate(script);
    if (res.isError) {
      throw Exception("JS Load Error: ${res.stringResult}");
    }
  }

  Future<dynamic> invokeAsync(
    String functionName, [
    List<dynamic>? args,
  ]) async {
    String argsStr = "";
    if (args != null && args.isNotEmpty) {
      argsStr = args.map((e) => jsonEncode(e)).join(', ');
    }

    final callbackId = "cb_${DateTime.now().microsecondsSinceEpoch}";
    final completer = Completer<dynamic>();
    _pendingCallbacks[callbackId] = completer;

    final evalWrapper =
        """
       (function() {
          try {
             var dart_cb = function(res) {
                 executeCallback('$callbackId', res !== undefined ? res : "__dart_void__", null);
             };
             
             var fn = globalThis['$functionName'];
             if (typeof fn !== 'function') {
                 var parts = '$functionName'.split('.');
                 var target = globalThis;
                 for(var i=0; i<parts.length; i++) {
                    target = target[parts[i]];
                 }
                 fn = target;
             }
             
             if (typeof fn !== 'function') throw "Function $functionName not found";

             var args = [$argsStr];
             args.push(dart_cb);
             
             var res = fn.apply(null, args);
             
             if (res && (typeof res.then === 'function' || res instanceof Promise)) {
                res.then(dart_cb).catch(function(err) {
                   executeCallback('$callbackId', null, err.toString());
                });
             } else if (res !== undefined) {
                dart_cb(res);
             }
          } catch(e) {
             executeCallback('$callbackId', null, e.toString());
          }
       })();
     """;

    _runtime.evaluate(evalWrapper);

    Timer? pumpTimer;
    pumpTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (completer.isCompleted) {
        pumpTimer?.cancel();
        return;
      }
      _runtime.executePendingJob();
    });

    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _pendingCallbacks.remove(callbackId);
          throw TimeoutException('Timeout executing $functionName');
        },
      );

      // --- Post-processing (Success) ---
      final bool isManifestRequest = functionName.endsWith("getManifest");
      dynamic unwrapped;

      if (result is String) {
        if (result == "__dart_void__") {
          unwrapped = null;
        } else {
          try {
            unwrapped = jsonDecode(result);
          } catch (e) {
            unwrapped = result;
          }
        }
      } else {
        unwrapped = result;
      }

      if (!isManifestRequest && unwrapped is Map) {
        final success = unwrapped['success'] ?? false;
        if (!success) {
          final code = unwrapped['errorCode'] ?? 'UNKNOWN_ERROR';
          final message =
              unwrapped['message'] ?? 'An unexpected plugin error occurred';
          throw JsPluginException(code, message);
        }
        return unwrapped['data'];
      } else {
        return unwrapped;
      }
    } finally {
      pumpTimer.cancel();
    }
  }

  Future<dynamic> callFunction(String name, [List<dynamic>? args]) async {
    return invokeAsync(name, args);
  }

  void dispose() {
    _runtime.dispose();
    _pendingCallbacks.clear();
  }

  String _sanitizeLog(dynamic args) {
    final String msg = args.toString();
    if (msg.length > 500 &&
        (msg.toLowerCase().contains("<!doctype html>") ||
            msg.toLowerCase().contains("<html") ||
            msg.contains("</div>"))) {
      return "[HTML Content Omitted - Length: ${msg.length}]";
    }
    if (msg.length > 3000) {
      return "${msg.substring(0, 3000)}... [Truncated]";
    }
    return msg;
  }
}
