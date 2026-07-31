class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = 'Non autorisé']) : super(message, 401);
}

class NotFoundException extends ApiException {
  NotFoundException([String message = 'Ressource non trouvée']) : super(message, 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException([String message = 'Erreur de validation', this.errors])
      : super(message, 400);
}
