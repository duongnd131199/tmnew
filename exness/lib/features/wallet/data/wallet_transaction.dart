import '../../account/data/ex_v2_models.dart';

final class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.status,
    this.amount,
    this.currency,
    this.createdAt,
  });

  factory WalletTransaction.fromJson(JsonMap json) {
    final rawAmount = json['amount'];
    final parsedAmount = rawAmount is num ? rawAmount.toDouble() : null;
    final rawDate = json['createdAt'] ?? json['createdAtUtc'];
    final rawCurrency = json['currency'];
    return WalletTransaction(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? json['transactionType'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amount: parsedAmount?.isFinite == true ? parsedAmount : null,
      currency: rawCurrency is String && rawCurrency.trim().isNotEmpty
          ? rawCurrency.trim()
          : null,
      createdAt: rawDate is String ? DateTime.tryParse(rawDate)?.toUtc() : null,
    );
  }

  final String id;
  final String type;
  final String status;
  final double? amount;
  final String? currency;
  final DateTime? createdAt;

  String get title => switch (type.toLowerCase()) {
    'deposit' => 'Nạp tiền',
    'withdrawal' || 'withdraw' => 'Rút tiền',
    'transfer' => 'Chuyển tiền',
    _ => 'Giao dịch ví',
  };

  double? get signedAmount => switch (type.toLowerCase()) {
    'deposit' => amount?.abs(),
    'withdrawal' || 'withdraw' => amount == null ? null : -amount!.abs(),
    _ => amount,
  };

  bool get hasKnownDirection => switch (type.toLowerCase()) {
    'deposit' || 'withdrawal' || 'withdraw' => true,
    _ => false,
  };
}
