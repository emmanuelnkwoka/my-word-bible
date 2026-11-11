/// Standard failure type surfaced to presentation code.
///
/// Repositories translate transport and storage errors into an [AppFailure]
/// so screens can render consistent, human-readable error states.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Human-readable, user-safe message.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'You appear to be offline. Check your connection and try again.']);
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.message = 'The request took too long. Please try again.']);
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.message = 'Your session has ended. Please sign in again.']);
}

class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([super.message = 'You do not have access to this content.']);
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'We could not find what you were looking for.']);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});
  final Map<String, String> fieldErrors;
}

class ServerFailure extends AppFailure {
  const ServerFailure([super.message = 'Something went wrong on our side. Please try again later.', this.statusCode]);
  final int? statusCode;
}

/// A capability that exists in the interface but depends on a service that is
/// not part of Foundation V1 (e.g. accounts, media hosting).
class FeatureUnavailableFailure extends AppFailure {
  const FeatureUnavailableFailure(super.message);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Something unexpected happened. Please try again.']);
}
