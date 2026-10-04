import '../../account/data/ex_v2_models.dart';

final class AccountNotification {
  const AccountNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory AccountNotification.fromJson(JsonMap json) {
    final rawDate = json['createdAt'] ?? json['updatedAt'];
    return AccountNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['type'] ?? 'Thông báo').toString(),
      message: (json['message'] ?? json['body'] ?? json['description'] ?? '')
          .toString(),
      isRead: json['isRead'] == true || json['read'] == true,
      createdAt: rawDate is String ? DateTime.tryParse(rawDate)?.toUtc() : null,
    );
  }

  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
}
