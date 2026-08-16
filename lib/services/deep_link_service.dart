import 'dart:async';
import 'package:flutter/services.dart';

/// Enum for supported deep link targets
enum DeepLinkTarget {
  pairingRequest,
  unknown;

  static DeepLinkTarget fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pair':
        return DeepLinkTarget.pairingRequest;
      default:
        return DeepLinkTarget.unknown;
    }
  }
}

/// Model for parsed deep link data
class DeepLink {
  final DeepLinkTarget target;
  final String? payload;
  final String rawUri;

  DeepLink({required this.target, this.payload, required this.rawUri});

  @override
  String toString() =>
      'DeepLink(target: $target, payload: $payload, uri: $rawUri)';
}

/// Service for handling deep links from native platforms
///
/// Listens for deep links from:
/// - Android: MainActivity.kt (via MethodChannel "onDeepLink")
/// - iOS: SceneDelegate.swift + AppDelegate.swift (via MethodChannel "iDiGi.deeplinks")
///
/// Supported schemes:
/// - Android: idigi, eu.fivea.idigi
/// - iOS: idigi, eu.fivea.idigi
///
/// Supported link formats:
/// - idigi://pair/<pairing-id>
/// - idigi:///pair/<pairing-id>
/// - eu.fivea.idigi://pair/<pairing-id>
class DeepLinkService {
  static const _platform = MethodChannel('iDiGi.deeplinks');
  static final DeepLinkService _instance = DeepLinkService._();

  final StreamController<DeepLink> _deepLinkController =
      StreamController<DeepLink>.broadcast();

  bool _initialized = false;

  DeepLinkService._();

  factory DeepLinkService() => _instance;

  /// Get the singleton instance
  static DeepLinkService get instance => _instance;

  /// Stream of deep links from native platforms
  Stream<DeepLink> get deepLinks => _deepLinkController.stream;

  /// Initialize the deep link service
  /// Must be called once before using the service
  Future<void> initialize() async {
    if (_initialized) return;

    // Listen for deep links from native Android/iOS
    _platform.setMethodCallHandler(_handleMethodCall);

    // Get the initial link (for cold start)
    try {
      final initialLink = await _platform.invokeMethod<String>(
        'getInitialLink',
      );
      if (initialLink != null && initialLink.isNotEmpty) {
        _handleDeepLink(initialLink);
      }
    } on PlatformException {
      // Platform not implemented (e.g., running on macOS without native support)
    }

    _initialized = true;
  }

  /// Handle incoming method calls from native platforms
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final link = call.arguments as String?;
      if (link != null) {
        _handleDeepLink(link);
      }
    }
  }

  /// Parse and process a deep link
  void _handleDeepLink(String uri) {
    final deepLink = _parseDeepLink(uri);
    _deepLinkController.add(deepLink);
  }

  /// Parse a deep link URI into a DeepLink object
  ///
  /// Supports formats:
  /// - idigi://pair/abc123
  /// - idigi:///pair/abc123
  /// - eu.fivea.idigi://pair/abc123
  /// - eu.fivea.idigi:///pair/abc123
  DeepLink _parseDeepLink(String uri) {
    try {
      final parts = uri.split('://');
      if (parts.length != 2) {
        return DeepLink(target: DeepLinkTarget.unknown, rawUri: uri);
      }

      final scheme = parts[0];
      final pathAndQuery = parts[1];

      // Validate scheme
      if (!_isSupportedScheme(scheme)) {
        return DeepLink(target: DeepLinkTarget.unknown, rawUri: uri);
      }

      // Remove leading slashes from path
      final cleanPath = pathAndQuery.replaceFirst(RegExp(r'^/+'), '');
      final pathSegments = cleanPath
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList();

      if (pathSegments.isEmpty) {
        return DeepLink(target: DeepLinkTarget.unknown, rawUri: uri);
      }

      final target = DeepLinkTarget.fromString(pathSegments[0]);
      final payload = pathSegments.length > 1 ? pathSegments[1] : null;

      return DeepLink(target: target, payload: payload, rawUri: uri);
    } catch (e) {
      return DeepLink(target: DeepLinkTarget.unknown, rawUri: uri);
    }
  }

  /// Check if a scheme is supported
  bool _isSupportedScheme(String scheme) {
    return scheme == 'idigi' || scheme == 'eu.fivea.idigi';
  }

  /// Dispose of the service
  void dispose() {
    _deepLinkController.close();
    _initialized = false;
  }
}
