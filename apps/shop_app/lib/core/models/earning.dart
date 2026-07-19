class Earning {
  final String id;
  final String shopId;
  final String orderId;
  final double amount;
  final double commission;
  final double netAmount;
  final String status;
  final DateTime? settledAt;
  final DateTime createdAt;

  Earning({
    required this.id,
    required this.shopId,
    required this.orderId,
    required this.amount,
    required this.commission,
    required this.netAmount,
    required this.status,
    this.settledAt,
    required this.createdAt,
  });

  factory Earning.fromJson(Map<String, dynamic> json) {
    return Earning(
      id: json['id'] ?? '',
      shopId: json['shop_id'] ?? '',
      orderId: json['order_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'pending',
      settledAt: json['settled_at'] != null ? DateTime.tryParse(json['settled_at'] ?? '') ?? DateTime.now() : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class EarningSummary {
  final double today;
  final double thisWeek;
  final double thisMonth;
  final double totalPending;
  final double totalSettled;

  EarningSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.totalPending,
    required this.totalSettled,
  });

  factory EarningSummary.fromJson(Map<String, dynamic> json) {
    return EarningSummary(
      today: (json['today'] as num?)?.toDouble() ?? 0,
      thisWeek: (json['this_week'] as num?)?.toDouble() ?? 0,
      thisMonth: (json['this_month'] as num?)?.toDouble() ?? 0,
      totalPending: (json['total_pending'] as num?)?.toDouble() ?? 0,
      totalSettled: (json['total_settled'] as num?)?.toDouble() ?? 0,
    );
  }
}
