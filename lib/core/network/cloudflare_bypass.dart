import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Cross-platform Cloudflare JS challenge bypass.
///
/// Strategy: When a CF challenge is detected, load the URL in a headless
/// WebView. The WebView's browser engine solves the challenge automatically.
/// Once solved, extract the page HTML directly from the WebView DOM.
///
/// After first solve for a host, the WebView is kept alive. Subsequent
/// requests to the same host navigate the existing WebView instead of
/// spawning a new one — avoids repeated 5s overhead per URL.
class CloudflareBypass {
  CloudflareBypass._();
  static final instance = CloudflareBypass._();

  static const _tag = '[CF Bypass]';
  static const _cfErrorCodes = [403, 503];
  static const _cfServers = ['cloudflare-nginx', 'cloudflare'];
  static const _timeout = Duration(seconds: 60);
  static const _navTimeout = Duration(seconds: 20);
  static const _pollInterval = Duration(milliseconds: 200);

  // ---------------------------------------------------------------------------
  // Detection
  // ---------------------------------------------------------------------------

  /// Returns true if the response is a Cloudflare JS challenge.
  bool isCloudflareChallenge(
    int? statusCode,
    Map<String, dynamic> headers,
    String body,
  ) {
    if (statusCode == null || !_cfErrorCodes.contains(statusCode)) return false;

    final server = _headerValue(headers, 'server');
    if (server == null ||
        !_cfServers.any((s) => server.toLowerCase().contains(s))) {
      return false;
    }

    return body.contains('Just a moment') ||
        body.contains('cf-mitigated') ||
        body.contains('_cf_chl_opt') ||
        body.contains('challenge-platform');
  }

  // ---------------------------------------------------------------------------
  // Persistent WebViews — one per CF-protected host
  // ---------------------------------------------------------------------------

  final Map<String, _HostWebView> _hostWebViews = {};

  // ---------------------------------------------------------------------------
  // Solver — returns the actual page HTML, not just cookies
  // ---------------------------------------------------------------------------

  /// Whether a fresh solve is currently in progress for a given host
  final Map<String, Completer<CfResult?>> _activeSolves = {};

  /// Solves the CF challenge and returns the actual page HTML + response info.
  ///
  /// On first call for [url]'s host: spins up a HeadlessInAppWebView, solves
  /// the challenge, then keeps the WebView alive for future calls.
  ///
  /// On subsequent calls for the same host: navigates the existing WebView to
  /// [url] directly — no new WebView spawned, ~1-2s instead of 5-60s.
  Future<CfResult?> solveAndFetch(
    String url, {
    Future<void> Function(String host)? onSolved,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host;

    // ------------------------------------------------------------------
    // Fast path: persistent WebView already exists for this host
    // ------------------------------------------------------------------
    final existingView = _hostWebViews[host];
    if (existingView != null) {
      if (kDebugMode) debugPrint('$_tag Reusing WebView for $host → $url');
      try {
        // Reset idle timer — this host is still active.
        existingView.startIdleTimer(() {
          if (kDebugMode) {
            debugPrint('$_tag Idle timeout — disposing WebView for $host');
          }
          _hostWebViews.remove(host);
          existingView.dispose();
        });
        final html = await existingView.navigate(url);
        if (html != null &&
            !html.contains('_cf_chl_opt') &&
            !html.contains('Just a moment')) {
          if (kDebugMode) {
            debugPrint(
              '$_tag Reused WebView got ${html.length} chars for $url',
            );
          }
          return CfResult(body: html, statusCode: 200, finalUrl: url);
        }
        // CF challenge recurred (cookie expired?) — fall through to full solve
        if (kDebugMode) {
          debugPrint('$_tag Reused WebView hit challenge again, re-solving');
        }
        await existingView.dispose();
        _hostWebViews.remove(host);
      } catch (e) {
        if (kDebugMode) debugPrint('$_tag Reused WebView error: $e');
        await existingView.dispose().catchError((_) {});
        _hostWebViews.remove(host);
      }
    }

    // ------------------------------------------------------------------
    // Slow path: fresh solve needed — deduplicate concurrent requests
    // ------------------------------------------------------------------
    if (_activeSolves.containsKey(host)) {
      if (kDebugMode) debugPrint('$_tag Already solving for $host, waiting…');
      return _activeSolves[host]!.future;
    }

    final completer = Completer<CfResult?>();
    _activeSolves[host] = completer;

    try {
      final result = await _fetchViaWebView(url, host);
      if (result != null) {
        if (kDebugMode) {
          debugPrint('$_tag Solved for $host, got ${result.body.length} chars');
        }
        if (onSolved != null) await onSolved(host);
      } else {
        if (kDebugMode) debugPrint('$_tag Failed to solve for $host');
      }
      completer.complete(result);
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag Error solving for $host: $e');
      completer.complete(null);
      return null;
    } finally {
      _activeSolves.remove(host);
    }
  }

  // ---------------------------------------------------------------------------
  // HeadlessInAppWebView — solve challenge & keep alive
  // ---------------------------------------------------------------------------

  Future<CfResult?> _fetchViaWebView(String url, String host) async {
    if (kDebugMode) debugPrint('$_tag Starting headless WebView for $url');

    if (!kIsWeb && Platform.isLinux) {
      if (kDebugMode) debugPrint('$_tag Linux: headless WebView not supported');
      return null;
    }

    // We use a mutable holder so the onLoadStop closure can write to it
    // after the HeadlessInAppWebView is constructed.
    final holder = _ViewHolder();

    CfResult? result;
    bool solved = false;

    InAppWebViewController? capturedController;

    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      ),
      onWebViewCreated: (controller) {
        capturedController = controller;
      },
      onLoadStop: (controller, loadedUrl) async {
        final finalUrl = loadedUrl?.toString() ?? url;
        final title = await controller.getTitle();

        if (title == 'Just a moment...' || title == null || title.isEmpty) {
          if (kDebugMode) debugPrint('$_tag Still on challenge page…');
          return;
        }

        try {
          final html = await controller.evaluateJavascript(
            source: 'document.documentElement.outerHTML',
          );
          if (html != null && html.toString().isNotEmpty) {
            final body = html.toString();
            if (!body.contains('_cf_chl_opt') &&
                !body.contains('Just a moment')) {
              // Notify the _HostWebView if it is already stored (for sequential
              // navigations after the initial solve).
              holder.hostView?.onLoaded(body);

              if (!solved) {
                result = CfResult(
                  body: body,
                  statusCode: 200,
                  finalUrl: finalUrl,
                );
                solved = true;
                if (kDebugMode) {
                  debugPrint('$_tag Page title: "$title" — extracted HTML');
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('$_tag HTML extraction error: $e');
          holder.hostView?.onLoaded(null);
        }
      },
      onReceivedError: (controller, request, error) {
        if (kDebugMode) {
          debugPrint('$_tag WebView error: ${error.description}');
        }
        holder.hostView?.onLoaded(null);
      },
    );

    try {
      await headless.run();

      final deadline = DateTime.now().add(_timeout);
      while (!solved && DateTime.now().isBefore(deadline)) {
        await Future.delayed(_pollInterval);
      }

      if (!solved) {
        if (kDebugMode) {
          debugPrint('$_tag Timed out after ${_timeout.inSeconds}s');
        }
        await headless.dispose();
        return null;
      }

      // Keep the WebView alive for future requests to this host.
      // The controller is set via onWebViewCreated; fall back to the one
      // from onLoadStop if needed.
      final hostView = _HostWebView(headless, capturedController);
      holder.hostView = hostView;
      _hostWebViews[host] = hostView;
      hostView.startIdleTimer(() {
        if (kDebugMode) {
          debugPrint('$_tag Idle timeout — disposing WebView for $host');
        }
        _hostWebViews.remove(host);
        hostView.dispose();
      });

      if (kDebugMode) debugPrint('$_tag WebView kept alive for $host');
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('$_tag HeadlessWebView error: $e');
      try {
        await headless.dispose();
      } catch (_) {}
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _headerValue(Map<String, dynamic> headers, String key) {
    final value = headers[key] ?? headers[key.toLowerCase()];
    if (value == null) return null;
    if (value is List) return value.isNotEmpty ? value.first.toString() : null;
    return value.toString();
  }
}

// ---------------------------------------------------------------------------
// Persistent WebView wrapper
// ---------------------------------------------------------------------------

/// Wraps a live [HeadlessInAppWebView] for sequential URL navigation.
///
/// Requests are serialized: if a navigation is already in progress, the next
/// call waits for it to complete before starting.
class _HostWebView {
  final HeadlessInAppWebView _headless;
  final InAppWebViewController? _controller;

  Completer<String?>? _pending;
  bool _disposed = false;
  Timer? _idleTimer;

  static const _idleTimeout = Duration(minutes: 5);

  _HostWebView(this._headless, this._controller);

  /// Start (or reset) the idle timer. [onIdle] is called when the timer fires.
  void startIdleTimer(void Function() onIdle) {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, onIdle);
  }

  /// Navigate to [url] and return the page HTML.
  Future<String?> navigate(String url) async {
    if (_disposed || _controller == null) throw StateError('WebView disposed');

    // Serialize: wait for any in-flight navigation to finish first.
    if (_pending != null && !_pending!.isCompleted) {
      await _pending!.future.catchError((_) => null);
    }

    _pending = Completer<String?>();
    await _controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));

    try {
      return await _pending!.future.timeout(CloudflareBypass._navTimeout);
    } on TimeoutException {
      // Complete the pending completer so the next navigate() call doesn't
      // wait for a future that will never resolve.
      if (!(_pending?.isCompleted ?? true)) _pending!.complete(null);
      return null;
    }
  }

  /// Called by the WebView's [onLoadStop] handler when a page finishes loading.
  void onLoaded(String? html) {
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.complete(html);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _idleTimer?.cancel();
    try {
      await _headless.dispose();
    } catch (_) {}
  }
}

/// Mutable holder so the [HeadlessInAppWebView] closure can reference
/// the [_HostWebView] created after construction.
class _ViewHolder {
  _HostWebView? hostView;
}

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// Result from a CF bypass — contains the actual page HTML.
class CfResult {
  final String body;
  final int statusCode;
  final String finalUrl;

  const CfResult({
    required this.body,
    required this.statusCode,
    required this.finalUrl,
  });
}
