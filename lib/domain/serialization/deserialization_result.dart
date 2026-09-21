import '../models/game_state.dart';

/// Structured reason a serialized payload could not become a [GameState].
enum DeserializationFailureReason {
  /// The payload declares a schemaVersion this build does not support.
  unsupportedSchemaVersion,

  /// The payload is not structurally valid JSON for a game state.
  malformed,

  /// The board configuration is invalid (size/wallsPerPlayer).
  invalidConfig,

  /// The payload is well-formed but breaks a state invariant (R-STATE-01..05).
  invariantViolation,
}

/// Structured outcome of decoding a [GameState] from JSON.
///
/// Never thrown: every failure is returned as a [DeserializationFailure].
sealed class DeserializationResult {
  const DeserializationResult._();

  /// Successful decode.
  factory DeserializationResult.success(GameState state) =
      DeserializationSuccess;

  /// Failed decode with a [reason] and human-readable [detail].
  factory DeserializationResult.failure(
    DeserializationFailureReason reason,
    String detail,
  ) = DeserializationFailure;

  /// The decoded state when successful, otherwise `null`.
  GameState? get stateOrNull => switch (this) {
    DeserializationSuccess(:final state) => state,
    DeserializationFailure() => null,
  };
}

/// Successful decode.
class DeserializationSuccess extends DeserializationResult {
  /// Creates a successful decode result.
  const DeserializationSuccess(this.state) : super._();

  /// The decoded state.
  final GameState state;
}

/// Failed decode.
class DeserializationFailure extends DeserializationResult {
  /// Creates a failed decode result.
  const DeserializationFailure(this.reason, this.detail) : super._();

  /// Machine-readable failure category.
  final DeserializationFailureReason reason;

  /// Human-readable explanation.
  final String detail;

  @override
  String toString() => 'DeserializationFailure(${reason.name}: $detail)';
}
