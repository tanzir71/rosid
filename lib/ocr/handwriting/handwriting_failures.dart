abstract class RecoverableHandwritingException implements Exception {
  const RecoverableHandwritingException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class HandwritingModelUnavailableException
    extends RecoverableHandwritingException {
  const HandwritingModelUnavailableException(super.message);
}

final class HandwritingModelIntegrityException
    extends RecoverableHandwritingException {
  const HandwritingModelIntegrityException(super.message);
}

final class HandwritingModelLoadException
    extends RecoverableHandwritingException {
  const HandwritingModelLoadException(super.message);
}

final class HandwritingInferenceException
    extends RecoverableHandwritingException {
  const HandwritingInferenceException(super.message);
}

final class HandwritingInferenceTimeoutException
    extends RecoverableHandwritingException {
  const HandwritingInferenceTimeoutException(super.message);
}

final class InvalidHandwritingOutputException
    extends RecoverableHandwritingException {
  const InvalidHandwritingOutputException(super.message);
}
