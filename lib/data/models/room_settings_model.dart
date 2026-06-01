import '../../core/constants/difficulty.dart';

class RoomSettingsModel {
  final String roomId;
  final Difficulty difficulty;
  final int penaltySeconds;
  final int maxItemCount;
  final List<String> allowedItems;
  final Map<String, int> hintCounts;

  const RoomSettingsModel({
    required this.roomId,
    this.difficulty = Difficulty.normal,
    this.penaltySeconds = 5,
    this.maxItemCount = 5,
    this.allowedItems = const ['hint', 'blind', 'item_cut', 'freeze', 'shield', 'reverse', 'mystery'],
    this.hintCounts = const {},
  });

  factory RoomSettingsModel.fromJson(Map<String, dynamic> json) {
    return RoomSettingsModel(
      roomId: json['room_id'] as String,
      difficulty: Difficulty.fromDbValue(json['difficulty'] as int),
      penaltySeconds: json['penalty_seconds'] as int,
      maxItemCount: (json['item_interval'] as int? ?? 5).clamp(0, 15),
      allowedItems: (json['allowed_items'] as List).cast<String>(),
      hintCounts: Map<String, int>.from(json['hint_counts'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
        'room_id': roomId,
        'difficulty': difficulty.dbValue,
        'penalty_seconds': penaltySeconds,
        'item_interval': maxItemCount,
        'allowed_items': allowedItems,
        'hint_counts': hintCounts,
      };
}
