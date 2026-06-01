class PlayerModel {
  final String id;
  final String roomId;
  final String nickname;
  final bool isHost;
  final bool isReady;
  final bool isConnected;
  final DateTime joinedAt;
  final DateTime? lastSeenAt;

  const PlayerModel({
    required this.id,
    required this.roomId,
    required this.nickname,
    required this.isHost,
    required this.isReady,
    required this.isConnected,
    required this.joinedAt,
    this.lastSeenAt,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      nickname: json['nickname'] as String,
      isHost: json['is_host'] as bool,
      isReady: json['is_ready'] as bool,
      isConnected: json['is_connected'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'room_id': roomId,
        'nickname': nickname,
        'is_host': isHost,
        'is_ready': isReady,
        'is_connected': isConnected,
      };
}
