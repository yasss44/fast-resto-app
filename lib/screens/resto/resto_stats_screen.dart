import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/resto_stats.dart';
import '../../resto_provider.dart';
import '../../services/stats_service.dart';
const _background = Color(0xFF09090B);
const _surface = Color(0xFF18181B);
const _border = Color(0xFF3F3F46);
const _primaryText = Color(0xFFFAFAFA);
const _secondaryText = Color(0xFFD4D4D8);
const _brand = Color(0xFFF59E0B);
const _positive = Color(0xFF34D399);
const _negative = Color(0xFFFB7185);

class RestoStatsScreen extends StatefulWidget {
  const RestoStatsScreen({super.key});

  @override
  State<RestoStatsScreen> createState() => _RestoStatsScreenState();
}

class _RestoStatsScreenState extends State<RestoStatsScreen> {
  final _statsService = StatsService();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<RestoProvider>();
      if (provider.stats == null && !provider.statsLoading) {
        provider.loadStats();
      }
    });
  }

  Future<void> _exportStats(int periodDays) async {
    setState(() => _exporting = true);
    try {
      final csv = await _statsService.exportStats(periodDays: periodDays);
      if (csv.isEmpty) throw Exception('Export vide');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fast-stats-$periodDays-j.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Export statistiques FAST',
        text: 'Statistiques restaurant — $periodDays jours',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export impossible: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestoProvider>();
    final stats = provider.stats;

    return ColoredBox(
      color: _background,
      child: RefreshIndicator(
        color: _brand,
        onRefresh: provider.loadStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const Text(
              'Analytics restaurant',
              style: TextStyle(
                color: _primaryText,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chiffre d’affaires basé sur les commandes payées et terminées.',
              style: TextStyle(color: _secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _PeriodSelector(
              selected: provider.statsPeriodDays,
              onSelected: (days) => provider.loadStats(periodDays: days),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _exporting
                    ? null
                    : () => _exportStats(provider.statsPeriodDays),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(_exporting ? 'Export...' : 'Exporter CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: const BorderSide(color: _brand),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (provider.statsLoading && stats != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(
                  color: _brand,
                  backgroundColor: _border,
                  minHeight: 3,
                ),
              ),
            if (provider.statsLoading && stats == null)
              const _LoadingState()
            else if (provider.statsError != null && stats == null)
              _ErrorState(
                message: provider.statsError!,
                onRetry: provider.loadStats,
              )
            else if (stats == null || stats.isEmpty)
              _EmptyState(onRetry: provider.loadStats)
            else ...[
              _OverviewSection(stats: stats),
              const SizedBox(height: 28),
              _RevenueChart(stats: stats),
              const SizedBox(height: 28),
              _LoyaltySection(kpis: stats.kpis),
              const SizedBox(height: 28),
              _OperationsSection(stats: stats),
              const SizedBox(height: 28),
              _PopularProducts(items: stats.popularItems),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _PeriodSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Période des statistiques',
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 7, label: Text('7 jours')),
          ButtonSegment(value: 30, label: Text('30 jours')),
          ButtonSegment(value: 90, label: Text('90 jours')),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (value) => onSelected(value.first),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(72, 48)),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? _background
                : _primaryText,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? _brand : _surface,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: _border)),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final RestoStats stats;

  const _OverviewSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final kpis = stats.kpis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Vue d’ensemble',
          subtitle: 'Comparaison avec la période précédente',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(
                  width: width,
                  label: 'Chiffre d’affaires',
                  value: _money(kpis.revenue),
                  icon: Icons.payments_outlined,
                  delta: kpis.revenueDeltaPercent,
                ),
                _KpiCard(
                  width: width,
                  label: 'Commandes',
                  value: kpis.orders.toString(),
                  icon: Icons.receipt_long_outlined,
                  delta: stats.comparison.ordersDeltaPercent,
                ),
                _KpiCard(
                  width: width,
                  label: 'Panier moyen',
                  value: _money(kpis.averageBasket),
                  icon: Icons.shopping_bag_outlined,
                ),
                _KpiCard(
                  width: width,
                  label: 'Clients uniques',
                  value: kpis.uniqueCustomers.toString(),
                  icon: Icons.people_alt_outlined,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final RestoStats stats;

  const _RevenueChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final points = stats.daily
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.revenue))
        .toList(growable: false);
    final highest = stats.daily.fold<double>(
      0,
      (value, day) => max(value, day.revenue),
    );
    final maxY = highest <= 0 ? 10.0 : highest * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Évolution du CA',
          subtitle: 'Montant restaurant hors frais de service',
        ),
        const SizedBox(height: 12),
        Semantics(
          label:
              'Courbe du chiffre d’affaires sur ${stats.periodDays} jours, total ${_money(stats.kpis.revenue)}.',
          image: true,
          child: _Panel(
            child: SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: max(1, points.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF27272A),
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              _money(spot.y),
                              const TextStyle(
                                color: _primaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: _border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _compactMoney(value),
                            style: const TextStyle(
                              color: _secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (!_showDateLabel(index, stats.daily.length)) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              _shortDate(stats.daily[index].date),
                              style: const TextStyle(
                                color: _secondaryText,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      color: _brand,
                      barWidth: 3,
                      isCurved: points.length <= 30,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: points.length <= 7),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _brand.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoyaltySection extends StatelessWidget {
  final StatsKpis kpis;

  const _LoyaltySection({required this.kpis});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Fidélisation',
          subtitle: 'Clients déjà connus avant cette période',
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Wrap(
            spacing: 24,
            runSpacing: 20,
            children: [
              _Metric(label: 'Nouveaux clients', value: '${kpis.newCustomers}'),
              _Metric(
                label: 'Clients récurrents',
                value: '${kpis.recurringCustomers}',
              ),
              _Metric(
                label: 'Taux de réachat',
                value: _percent(kpis.repurchaseRate),
              ),
              _Metric(
                label: 'CA clients récurrents',
                value: _money(kpis.recurringCustomerRevenue),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OperationsSection extends StatelessWidget {
  final RestoStats stats;

  const _OperationsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final kpis = stats.kpis;
    final delta = stats.comparison.cancellationRateDeltaPoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Annulations',
          subtitle: 'Commandes au statut annulé sur toutes les commandes',
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: _negative, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${kpis.cancelledOrders} commande${kpis.cancelledOrders > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: _primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_percent(kpis.cancellationRate)} · ${_signedPoints(delta)} vs période précédente',
                      style: const TextStyle(color: _secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PopularProducts extends StatelessWidget {
  final List<PopularItemStat> items;

  const _PopularProducts({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maximum = items.first.totalSold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Produits populaires',
          subtitle: 'Quantités vendues sur la période',
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _ProductRow(
                  rank: index + 1,
                  item: items[index],
                  maximum: maximum,
                ),
                if (index < items.length - 1)
                  const Divider(height: 24, color: _border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int rank;
  final PopularItemStat item;
  final int maximum;

  const _ProductRow({
    required this.rank,
    required this.item,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rank, ${item.name}, ${item.totalSold} vendus',
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: _brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: maximum == 0 ? 0 : item.totalSold / maximum,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                  color: _brand,
                  backgroundColor: _border,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${item.totalSold}',
            style: const TextStyle(
              color: _primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final double? delta;

  const _KpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final hasDelta = delta != null;
    final isPositive = (delta ?? 0) >= 0;
    final deltaColor = isPositive ? _positive : _negative;
    final deltaLabel = delta == null
        ? 'pas de référence'
        : '${isPositive ? '+' : ''}${_number(delta!)} %';

    return Semantics(
      label: '$label, $value${hasDelta ? ', évolution $deltaLabel' : ''}',
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 154),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _brand, size: 24),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(color: _secondaryText, fontSize: 13),
            ),
            if (hasDelta) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: deltaColor,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      deltaLabel,
                      style: TextStyle(
                        color: deltaColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _primaryText,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: _secondaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: _secondaryText, fontSize: 13),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Semantics(
          label: 'Chargement des statistiques',
          child: const CircularProgressIndicator(color: _brand),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.cloud_off_outlined,
      title: 'Statistiques indisponibles',
      message: message,
      actionLabel: 'Réessayer',
      onPressed: onRetry,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.query_stats_outlined,
      title: 'Pas encore de données',
      message:
          'Aucune activité n’a été enregistrée pour cette période. Essayez une période plus longue.',
      actionLabel: 'Actualiser',
      onPressed: onRetry,
    );
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(icon, color: _brand, size: 42),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _primaryText,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondaryText, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 48),
                backgroundColor: _brand,
                foregroundColor: _background,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _showDateLabel(int index, int count) {
  if (index < 0 || index >= count) return false;
  if (count <= 7) return true;
  final step = max(1, (count / 4).floor());
  return index == 0 || index == count - 1 || index % step == 0;
}

String _money(double value) => '${_number(value)} €';

String _compactMoney(double value) {
  if (value >= 1000) return '${_number(value / 1000)} k€';
  return '${value.round()} €';
}

String _percent(double value) => '${_number(value)} %';

String _number(double value) {
  final fixed = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  return fixed.replaceAll('.', ',');
}

String _signedPoints(double value) =>
    '${value > 0 ? '+' : ''}${_number(value)} pt';

String _shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
