class ServerException implements Exception {
  ServerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  NetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);

  final String message;

  @override
  String toString() => message;
}
