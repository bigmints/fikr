import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'action_card.dart';
import 'feed_item.dart';

class Scan implements FeedItem {
  @override
  final String id;
  @override
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final String description;
  final String category; // 'product'|'food'|'news'|'book'|'place'|'other'
  final String? imagePath;
  final String? imageUrl;
  /// Local path to the compressed thumbnail used for LLM analysis.
  /// Sized to max 1024px / 75% quality. Never uploaded to GCS.
  final String? thumbPath;
  final List<ActionCard> actions;
  final bool isProcessing;
  final bool archived;

  @override
  String get bucket => category;

  Scan({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.description = '',
    this.category = 'other',
    this.imagePath,
    this.imageUrl,
    this.thumbPath,
    this.actions = const [],
    this.isProcessing = false,
    this.archived = false,
  });

  Scan copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    String? description,
    String? category,
    String? imagePath,
    String? imageUrl,
    String? thumbPath,
    List<ActionCard>? actions,
    bool? isProcessing,
    bool? archived,
  }) {
    return Scan(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbPath: thumbPath ?? this.thumbPath,
      actions: actions ?? this.actions,
      isProcessing: isProcessing ?? this.isProcessing,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'title': title,
      'description': description,
      'category': category,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'thumbPath': thumbPath,
      'actions': actions.map((a) => a.toJson()).toList(),
      'isProcessing': isProcessing,
      'archived': archived,
    };
  }

  factory Scan.fromJson(Map<String, dynamic> json) {
    return Scan(
      id: json['id'] as String? ?? const Uuid().v4(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      thumbPath: json['thumbPath'] as String?,
      actions: (json['actions'] as List<dynamic>? ?? [])
          .map((a) => ActionCard.fromJson(a as Map<String, dynamic>))
          .toList(),
      isProcessing: json['isProcessing'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
    );
  }

  static List<Scan> listFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return [];
      final items = (decoded['scans'] as List<dynamic>? ?? []);
      return items
          .whereType<Map<String, dynamic>>()
          .map((item) => Scan.fromJson(item))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static String listToJson(List<Scan> scans) {
    final data = {'scans': scans.map((s) => s.toJson()).toList()};
    return jsonEncode(data);
  }
}
