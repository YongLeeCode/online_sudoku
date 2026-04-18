class RoomSettingsModel {
  final String roomId;
  final int difficulty;
  final int penaltySeconds;
  final int itemInterval;
  final List<String> allowedItems;
  final Map<String, int> hintCounts;

  const RoomSettingsModel({
    required this.roomId,
    this.difficulty = 5,
    this.penaltySeconds = 5,
    this.itemInterval = 10,
    this.allowedItems = const ['hint', 'blind', 'hint_cut', 'freeze'],
    this.hintCounts = const {},
  });

  factory RoomSettingsModel.fromJson(Map<String, dynamic> json) {
    return RoomSettingsModel(
      roomId: json['room_id'] as String,
      difficulty: json['difficulty'] as int,
      penaltySeconds: json['penalty_seconds'] as int,
      itemInterval: json['item_interval'] as int,
      allowedItems: (json['allowed_items'] as List).cast<String>(),
      hintCounts: Map<String, int>.from(json['hint_counts'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
        'room_id': roomId,
        'difficulty': difficulty,
        'penalty_seconds': penaltySeconds,
        'item_interval': itemInterval,
        'allowed_items': allowedItems,
        'hint_counts': hintCounts,
      };
}
