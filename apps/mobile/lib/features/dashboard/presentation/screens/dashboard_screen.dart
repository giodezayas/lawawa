import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../inventory/presentation/screens/products_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashStats? _stats;
  PeriodReport? _period;
  CashFlow? _todayFlow;
  CashFlow? _periodFlow;
  List<ProductRow> _lowStock = [];
  var _error = '';
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final api = ref.read(wawaClientProvider);
      final startDay = await api.billingStartDay();
      final period = billingPeriodContaining(isoDate(), startDay);
      final today = isoDate();
      final stats = await api.dashboardStats();
      final products = await api.products();
      final report = await api.periodReport(period.from, period.to);
      final todayFlow = await api.cashFlow(today, today);
      final periodFlow = await api.cashFlow(period.from, period.to);
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
        _period = report;
        _todayFlow = todayFlow;
        _periodFlow = periodFlow;
        _lowStock = products.where((product) => product.isLowStock).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final stats = _stats;
    final period = _period;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Hoy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const Text('Inicio', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ErrorBanner(_error),
          if (stats != null) ...[
            const Text('Operación De Hoy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            StatCard(label: 'Venta', value: formatMoney(stats.saleToday)),
            const SizedBox(height: 8),
            StatCard(label: 'Ganancia Bruta', value: formatMoney(stats.profitToday), tone: moneyColor(stats.profitToday)),
            const SizedBox(height: 8),
            StatCard(label: 'IPV', value: ipvTodayLabel(stats.ipvTodayStatus)),
            const SizedBox(height: 20),
          ],
          if (_todayFlow != null) CashFlowCards(flow: _todayFlow!, title: 'Caja De Hoy'),
          if (_periodFlow != null) ...[
            const SizedBox(height: 20),
            CashFlowCards(
              flow: _periodFlow!,
              title: period == null
                  ? 'Caja Del Período'
                  : 'Caja Del Período · ${formatDateOnly(period.from)} — ${formatDateOnly(period.to)}',
            ),
          ],
          if (period != null) ...[
            const SizedBox(height: 20),
            Text(
              'Este Período · ${formatDateOnly(period.from)} — ${formatDateOnly(period.to)} · Impuesto 25%',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            StatCard(label: 'Impuestos A Pagar', value: formatMoney(period.tax), tone: AppColors.danger),
            const SizedBox(height: 8),
            StatCard(label: 'Te Quedas', value: formatMoney(period.net), tone: moneyColor(period.net)),
            const SizedBox(height: 8),
            StatCard(label: 'Venta Del Período', value: formatMoney(period.saleTotal)),
          ],
          if (_lowStock.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Bajo Stock', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ..._lowStock.map(
              (product) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(product.name, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                subtitle: Text('Stock ${product.stockQty} · Mínimo ${product.minStock}'),
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductsScreen())),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
