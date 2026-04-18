class RoomModel {
  final String id;
  final String code;
  final String hostId;
  final String status; // waiting, ready, playing, finished
  final int maxPlayers;
  final DateTime createdAt;

  const RoomModel({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    required this.maxPlayers,
    required this.createdAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      code: json['code'] as String,
      hostId: json['host_id'] as String,
      status: json['status'] as String,
      maxPlayers: json['max_players'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'host_id': hostId,
        'status': status,
        'max_players': maxPlayers,
      };
}
