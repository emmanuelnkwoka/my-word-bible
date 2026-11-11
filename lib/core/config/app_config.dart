/// How repositories obtain their data.
enum DataSourceMode {
  /// Local sample data and on-device persistence only. Default for Foundation V1.
  mock,

  /// Future MWB (Laravel) API. Remote repositories are scaffolded but the
  /// endpoints are not yet defined by the redesigned backend.
  remote,
}

/// Central application configuration.
///
/// Values come from build-time `--dart-define` flags so no environment-specific
/// URL or secret is hardcoded in source:
///
/// ```
/// flutter run --dart-define=MWB_DATA_SOURCE=remote \
///             --dart-define=MWB_API_BASE_URL=https://api.example.com/v1
/// ```
class AppConfig {
  const AppConfig({
    required this.dataSource,
    required this.apiBaseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 30),
    this.enableNetworkLogging = false,
    this.mwbReviewMode = false,
  });

  factory AppConfig.fromEnvironment() {
    const mode = String.fromEnvironment('MWB_DATA_SOURCE', defaultValue: 'mock');
    const baseUrl = String.fromEnvironment('MWB_API_BASE_URL', defaultValue: '');
    const logging = bool.fromEnvironment('MWB_NETWORK_LOGGING', defaultValue: false);
    const reviewMode = bool.fromEnvironment('MWB_REVIEW_MODE', defaultValue: false);
    final dataSource = mode == 'remote' && baseUrl.isNotEmpty ? DataSourceMode.remote : DataSourceMode.mock;
    return AppConfig(
      dataSource: dataSource,
      apiBaseUrl: baseUrl,
      enableNetworkLogging: logging,
      mwbReviewMode: reviewMode,
    );
  }

  final DataSourceMode dataSource;

  /// Base URL of the future MWB API. Empty in mock mode.
  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final bool enableNetworkLogging;

  /// Reviewer builds only (`--dart-define=MWB_REVIEW_MODE=true`): MWB editions
  /// also preview rules that are not yet approved, clearly marked as such.
  /// Production builds show approved rules only.
  final bool mwbReviewMode;

  bool get isMock => dataSource == DataSourceMode.mock;

  static const appName = 'My Word Bible';
  static const appVersion = '1.0.0 (Foundation V1)';
}
