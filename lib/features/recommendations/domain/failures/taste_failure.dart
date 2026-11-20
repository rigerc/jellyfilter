/// Why taste data could not be read from the server.
enum TasteFailureReason { unreachable, unauthorized, server, incompatible }

final class TasteFailure implements Exception {
  const TasteFailure(this.reason);

  final TasteFailureReason reason;

  @override
  String toString() => 'TasteFailure(${reason.name})';
}
