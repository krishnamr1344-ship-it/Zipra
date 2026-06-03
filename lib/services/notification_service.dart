import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class NotificationModel {
  final String id;
  final String title;
  final String? message;
  final String type;
  final String? imageUrl;
  final String? link;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    this.message,
    this.type = 'offer',
    this.imageUrl,
    this.link,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'],
      type: json['type'] ?? 'offer',
      imageUrl: json['image_url'],
      link: json['link'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

class NotificationService extends ChangeNotifier {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://delivery-app-api-16t0.onrender.com',
  );

  List<NotificationModel> _notifications = [];
  bool _loading = false;
  bool _loaded = false;

  List<NotificationModel> get notifications => _notifications;
  bool get loading => _loading;
  bool get loaded => _loaded;
  int get unreadCount => _notifications.length;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      final token = await ApiService().getToken();
      if (token == null) {
        _loading = false;
        notifyListeners();
        return;
      }

      final res = await http.get(
        Uri.parse('$_baseUrl/api/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        _notifications = data.map((e) => NotificationModel.fromJson(e)).toList();
        _loaded = true;
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to load: $e');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> sendNotification(Map<String, dynamic> data) async {
    try {
      final token = await ApiService().getToken();
      if (token == null) return;

      await http.post(
        Uri.parse('$_baseUrl/api/admin/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('NotificationService: Failed to send: $e');
    }
  }
}

final notificationService = NotificationService();
