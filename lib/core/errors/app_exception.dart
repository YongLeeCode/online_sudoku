class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException($code): $message';
}

class RoomFullException extends AppException {
  const RoomFullException() : super('방이 가득 찼습니다.');
}

class RoomNotFoundException extends AppException {
  const RoomNotFoundException() : super('방을 찾을 수 없습니다.');
}

class GameAlreadyStartedException extends AppException {
  const GameAlreadyStartedException() : super('이미 게임이 시작되었습니다.');
}
