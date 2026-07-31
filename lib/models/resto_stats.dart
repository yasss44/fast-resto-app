class RestoStats {
  final int periodDays;
  final DateTime start;
  final DateTime end;
  final StatsKpis kpis;
  final StatsComparison comparison;
  final List<DailyStat> daily;
  final List<PopularItemStat> popularItems;

  const RestoStats({
    required this.periodDays,
    required this.start,
    required this.end,
    required this.kpis,
    required this.comparison,
    required this.daily,
    required this.popularItems,
  });

  bool get isEmpty =>
      kpis.orders == 0 && kpis.cancelledOrders == 0 && popularItems.isEmpty;

  factory RestoStats.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? const {};
    return RestoStats(
      periodDays: (period['days'] as num?)?.toInt() ?? 7,
      start: DateTime.parse(period['start'] as String),
      end: DateTime.parse(period['end'] as String),
      kpis: StatsKpis.fromJson(
        json['kpis'] as Map<String, dynamic>? ?? const {},
      ),
      comparison: StatsComparison.fromJson(
        json['comparison'] as Map<String, dynamic>? ?? const {},
      ),
      daily: (json['daily'] as List<dynamic>? ?? const [])
          .map((item) => DailyStat.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      popularItems: (json['popularItems'] as List<dynamic>? ?? const [])
          .map((item) => PopularItemStat.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class StatsKpis {
  final double revenue;
  final double? revenueDeltaPercent;
  final int orders;
  final double averageBasket;
  final int uniqueCustomers;
  final int newCustomers;
  final int recurringCustomers;
  final double repurchaseRate;
  final double recurringCustomerRevenue;
  final int cancelledOrders;
  final double cancellationRate;

  const StatsKpis({
    required this.revenue,
    required this.revenueDeltaPercent,
    required this.orders,
    required this.averageBasket,
    required this.uniqueCustomers,
    required this.newCustomers,
    required this.recurringCustomers,
    required this.repurchaseRate,
    required this.recurringCustomerRevenue,
    required this.cancelledOrders,
    required this.cancellationRate,
  });

  factory StatsKpis.fromJson(Map<String, dynamic> json) => StatsKpis(
    revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    revenueDeltaPercent: (json['revenueDeltaPercent'] as num?)?.toDouble(),
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    averageBasket: (json['averageBasket'] as num?)?.toDouble() ?? 0,
    uniqueCustomers: (json['uniqueCustomers'] as num?)?.toInt() ?? 0,
    newCustomers: (json['newCustomers'] as num?)?.toInt() ?? 0,
    recurringCustomers: (json['recurringCustomers'] as num?)?.toInt() ?? 0,
    repurchaseRate: (json['repurchaseRate'] as num?)?.toDouble() ?? 0,
    recurringCustomerRevenue:
        (json['recurringCustomerRevenue'] as num?)?.toDouble() ?? 0,
    cancelledOrders: (json['cancelledOrders'] as num?)?.toInt() ?? 0,
    cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 0,
  );
}

class StatsComparison {
  final double? revenueDeltaPercent;
  final double? ordersDeltaPercent;
  final double cancellationRateDeltaPoints;

  const StatsComparison({
    required this.revenueDeltaPercent,
    required this.ordersDeltaPercent,
    required this.cancellationRateDeltaPoints,
  });

  factory StatsComparison.fromJson(Map<String, dynamic> json) =>
      StatsComparison(
        revenueDeltaPercent: (json['revenueDeltaPercent'] as num?)?.toDouble(),
        ordersDeltaPercent: (json['ordersDeltaPercent'] as num?)?.toDouble(),
        cancellationRateDeltaPoints:
            (json['cancellationRateDeltaPoints'] as num?)?.toDouble() ?? 0,
      );
}

class DailyStat {
  final DateTime date;
  final double revenue;
  final int orders;

  const DailyStat({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  factory DailyStat.fromJson(Map<String, dynamic> json) => DailyStat(
    date: DateTime.parse(json['date'] as String),
    revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    orders: (json['orders'] as num?)?.toInt() ?? 0,
  );
}

class PopularItemStat {
  final String id;
  final String name;
  final int totalSold;

  const PopularItemStat({
    required this.id,
    required this.name,
    required this.totalSold,
  });

  factory PopularItemStat.fromJson(Map<String, dynamic> json) =>
      PopularItemStat(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Produit',
        totalSold: (json['totalSold'] as num?)?.toInt() ?? 0,
      );
}
