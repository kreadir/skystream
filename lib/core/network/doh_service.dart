import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// DNS over HTTPS provider options.
enum DohProvider {
  cloudflare, // https://cloudflare-dns.com/dns-query
  google, // https://dns.google/dns-query
  custom, // User-defined URL
}

/// A DNS-over-HTTPS resolver that queries Cloudflare or Google for DNS records.
///
/// Extends ChangeNotifier so the settings UI rebuilds reactively.
class DohService extends ChangeNotifier {
  DohService._();
  static final DohService instance = DohService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  // In-memory cache: domain -> (ip, expiry)
  final Map<String, _DohCacheEntry> _cache = {};

  bool _enabled = false;
  DohProvider _provider = DohProvider.cloudflare;
  String _customUrl = '';

  bool get enabled => _enabled;
  DohProvider get provider => _provider;
  String get customUrl => _customUrl;

  void setEnabled(bool value) {
    _enabled = value;
    notifyListeners();
  }

  void setProvider(DohProvider p) {
    _provider = p;
    notifyListeners();
  }

  void setCustomUrl(String url) {
    _customUrl = url;
    notifyListeners();
  }

  String get _endpoint {
    switch (_provider) {
      case DohProvider.cloudflare:
        return 'https://cloudflare-dns.com/dns-query';
      case DohProvider.google:
        return 'https://dns.google/dns-query';
      case DohProvider.custom:
        return _customUrl;
    }
  }

  /// Resolves a domain to an IP address using DNS over HTTPS.
  /// Returns null if resolution fails (caller should fall back to normal DNS).
  Future<String?> resolve(String domain) async {
    if (!_enabled) return null;

    // Check cache first
    final cached = _cache[domain];
    if (cached != null && cached.expiry.isAfter(DateTime.now())) {
      return cached.ip;
    }

    try {
      final response = await _dio.get(
        _endpoint,
        queryParameters: {
          'name': domain,
          'type': 'A', // IPv4
        },
        options: Options(
          headers: {'Accept': 'application/dns-json'},
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data;

        if (data['Status'] == 0 && data['Answer'] != null) {
          final answers = data['Answer'] as List;
          // Find A record (type 1)
          for (final answer in answers) {
            if (answer['type'] == 1) {
              final ip = answer['data'] as String;
              final ttl = answer['TTL'] as int? ?? 300;
              // Cache with TTL
              _cache[domain] = _DohCacheEntry(
                ip: ip,
                expiry: DateTime.now().add(Duration(seconds: ttl)),
              );
              if (kDebugMode) {
                debugPrint('[DoH] $domain -> $ip (TTL: ${ttl}s)');
              }
              return ip;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DoH] Failed to resolve $domain: $e');
    }

    return null; // Fall back to normal DNS
  }

  /// Clears the DNS cache.
  void clearCache() => _cache.clear();
}

class _DohCacheEntry {
  final String ip;
  final DateTime expiry;
  _DohCacheEntry({required this.ip, required this.expiry});
}

/// Dio Interceptor that resolves domains via DoH before requests go out.
///
/// It rewrites the request URL to use the resolved IP and sets the Host header,
/// so the HTTP request goes directly to the correct IP without depending on
/// the system's (potentially censored) DNS resolver.
class DohInterceptor extends Interceptor {
  final DohService _doh;

  DohInterceptor([DohService? doh]) : _doh = doh ?? DohService.instance;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_doh.enabled) {
      return handler.next(options);
    }

    final uri = options.uri;
    final host = uri.host;

    // Skip IP addresses and localhost
    if (_isIpAddress(host) || host == 'localhost') {
      return handler.next(options);
    }

    final resolvedIp = await _doh.resolve(host);
    if (resolvedIp != null) {
      // Rewrite URL with resolved IP
      final newUri = uri.replace(host: resolvedIp);
      options.path = newUri.toString();

      // Set Host header so the server knows which domain we're requesting
      options.headers['Host'] = host;

      if (kDebugMode) {
        debugPrint('[DoH Interceptor] $host -> $resolvedIp');
      }
    }

    handler.next(options);
  }

  bool _isIpAddress(String host) {
    // Simple check for IPv4
    return RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);
  }
}
