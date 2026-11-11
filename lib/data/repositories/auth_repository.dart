import '../../core/errors/app_failure.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';

enum SessionStatus { guest, signedIn }

class SessionState {
  const SessionState.guest() : status = SessionStatus.guest, displayName = null, email = null;

  const SessionState.signedIn({required this.displayName, required this.email}) : status = SessionStatus.signedIn;

  final SessionStatus status;
  final String? displayName;
  final String? email;

  bool get isSignedIn => status == SessionStatus.signedIn;
}

/// Account sessions. MWB accounts depend on the redesigned backend, so the
/// default implementation keeps the user in an on-device guest session.
abstract interface class AuthRepository {
  /// Whether account sign-in is offered by this build.
  bool get accountsAvailable;

  Future<SessionState> currentSession();
  Future<SessionState> signIn({required String email, required String password});
  Future<void> signOut();
}

/// Foundation V1: personal data stays on the device; there is no account
/// server. Sign-in reports that accounts are not yet available.
class DeviceOnlyAuthRepository implements AuthRepository {
  DeviceOnlyAuthRepository(this._tokens);

  final TokenStorage _tokens;

  @override
  bool get accountsAvailable => false;

  @override
  Future<SessionState> currentSession() async => const SessionState.guest();

  @override
  Future<SessionState> signIn({required String email, required String password}) async {
    throw const FeatureUnavailableFailure(
      'MWB accounts are not available yet. Your preferences and library are saved on this device.',
    );
  }

  @override
  Future<void> signOut() => _tokens.clear();
}

/// Scaffold for the future API-backed session. Endpoints are intentionally
/// not implemented until the new backend contract exists.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api, this._tokens);

  // ignore: unused_field
  final ApiClient _api;
  final TokenStorage _tokens;

  @override
  bool get accountsAvailable => false;

  @override
  Future<SessionState> currentSession() async {
    final tokens = await _tokens.read();
    if (tokens == null) return const SessionState.guest();
    // Future: GET the authenticated profile from the MWB API.
    return const SessionState.guest();
  }

  @override
  Future<SessionState> signIn({required String email, required String password}) async {
    throw const FeatureUnavailableFailure('Account sign-in will be enabled with the MWB backend.');
  }

  @override
  Future<void> signOut() => _tokens.clear();
}
