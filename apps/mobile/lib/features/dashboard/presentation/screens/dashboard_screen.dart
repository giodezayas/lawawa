import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../finance/presentation/screens/cards_screen.dart';
import '../../../inventory/presentation/screens/products_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  PeriodReport? _period;
  IpvDoc? _lastIpv;
  List<ExpenseRow> _expenses = [];
  CardBalances? _cards;
  List<ProductRow> _lowStock = [];
  var _error = '';
  var _loading = true;
  var _from = isoDate();
  var _to = isoDate();
  var _savingPeriod = false;

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
      final period = await api.billingPeriod();
      _from = period.from;
      _to = period.to;
      final products = await api.products();
      final report = await api.periodReport(period.from, period.to);
      final ipvs = await api.ipvs();
      final expenses = await api.expenses();
      final moves = await api.cashMoves(period.from, period.to);
      if (!mounted) {
        return;
      }
      var cardF = 0.0;
      for (final doc in ipvs) {
        if (doc.workDate.compareTo(period.from) >= 0 && doc.workDate.compareTo(period.to) <= 0) {
          cardF += doc.transferFCollected;
        }
      }
      final tax = periodTaxes(declaredBilling(cardF)).total;
      setState(() {
        _period = PeriodReport(
          from: report.from,
          to: report.to,
          saleTotal: report.saleTotal,
          purchaseTotal: report.purchaseTotal,
          grossProfit: report.grossProfit,
          taxableGrossProfit: report.taxableGrossProfit,
          expenseTotal: report.expenseTotal,
          utilidad: report.utilidad,
          tax: tax,
          net: ((report.utilidad - tax) * 100).round() / 100,
          closed: report.closed,
          lines: report.lines,
        );
        _lastIpv = _latestIpv(ipvs);
        _expenses = expenses;
        _cards = CardBalances.from(ipvs, moves, period.from, period.to, null);
        _lowStock = products.where((product) => product.isLowStock).take(5).toList();
        _from = period.from;
        _to = period.to;
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

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = DateTime.parse('${isFrom ? _from : _to}T00:00:00');
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _from = isoDate(picked);
      } else {
        _to = isoDate(picked);
      }
    });
  }

  Future<void> _savePeriod({String? from, String? to}) async {
    setState(() {
      _savingPeriod = true;
      _error = '';
    });
    try {
      await ref.read(wawaClientProvider).setBillingPeriod(from ?? _from, to ?? _to);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _savingPeriod = false);
      }
    }
  }

  Future<void> _applyPreset(({String from, String to}) period) async {
    setState(() {
      _from = period.from;
      _to = period.to;
    });
    await _savePeriod(from: period.from, to: period.to);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final period = _period;
    final lastIpv = _lastIpv;
    final lastCut = lastIpv == null
        ? null
        : IpvDayCut.compute(
            grossProfit: lastIpv.grossProfit,
            otherExpenses: otherExpensesOnDate(_expenses, lastIpv.workDate),
          );
    final auth = ref.watch(authControllerProvider);
    final canManage = auth is AuthAuthenticated && auth.user.canManageStaff;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Hoy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const Text('Inicio', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ErrorBanner(_error),
          const Text('Período De Trabajo', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Desde *'),
            subtitle: Text(formatDateOnly(_from)),
            onTap: canManage ? () => _pickDate(isFrom: true) : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hasta *'),
            subtitle: Text(formatDateOnly(_to)),
            onTap: canManage ? () => _pickDate(isFrom: false) : null,
          ),
          if (canManage) ...[
            PrimaryButton(label: 'Guardar Período', loading: _savingPeriod, onPressed: _savePeriod),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _savingPeriod ? null : () => _applyPreset(defaultBillingPeriod()),
              child: const Text('Este Mes'),
            ),
            OutlinedButton(
              onPressed: _savingPeriod ? null : () => _applyPreset(previousCalendarMonth()),
              child: const Text('Mes Anterior'),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            lastIpv == null ? 'Último IPV' : 'Último IPV · ${formatDateOnly(lastIpv.workDate)}',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          StatCard(label: 'Venta', value: formatMoney(lastIpv?.saleTotal ?? 0)),
          const SizedBox(height: 8),
          StatCard(
            label: 'Ganancia Bruta',
            value: formatMoney(lastCut?.utilidad ?? 0),
            tone: moneyColor(lastCut?.utilidad ?? 0),
          ),
          const Text(
            'Después De Salario Y Gastos. Sin Impuesto.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          StatCard(label: 'Estado', value: ipvTodayLabel(lastIpv?.status ?? '')),
          if (lastCut != null) ...[
            const SizedBox(height: 8),
            StatCard(label: 'Salario', value: formatMoney(lastCut.salary), tone: AppColors.danger),
            const SizedBox(height: 8),
            StatCard(label: 'Gastos', value: formatMoney(lastCut.otherExpenses), tone: AppColors.danger),
            const SizedBox(height: 8),
            StatCard(label: 'Ganancias Brutas', value: formatMoney(lastCut.utilidad), tone: moneyColor(lastCut.utilidad)),
            const Text(
              'Después De Salario Y Gastos. Sin Impuesto.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            StatCard(label: 'Cada Dueño', value: formatMoney(lastCut.ownerShare), tone: moneyColor(lastCut.ownerShare)),
          ],
          const SizedBox(height: 20),
          RecaudoCards(
            title: 'Última Caja',
            cash: lastIpv?.cashCollected ?? 0,
            transfer: lastIpv?.transferCollected ?? 0,
          ),
          if (_cards != null) ...[
            const SizedBox(height: 20),
            const Text('Tarjetas', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            StatCard(label: 'Cuenta Personal', value: formatMoney(_cards!.p.balance)),
            const SizedBox(height: 8),
            StatCard(label: 'Cuenta Fiscal', value: formatMoney(_cards!.f.balance)),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Manejar Tarjetas',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CardsScreen()));
                await _load();
              },
            ),
          ],
          if (period != null) ...[
            const SizedBox(height: 20),
            Text(
              'Este Período · ${formatDateOnly(period.from)} — ${formatDateOnly(period.to)}',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            StatCard(label: 'Impuestos A Pagar', value: formatMoney(period.tax), tone: AppColors.danger),
            const SizedBox(height: 8),
            StatCard(label: 'Te Quedas', value: formatMoney(period.net), tone: moneyColor(period.net)),
            const SizedBox(height: 8),
            StatCard(label: 'Venta Del Período', value: formatMoney(period.saleTotal)),
            const SizedBox(height: 8),
            StatCard(label: 'Invertido', value: formatMoney(period.purchaseTotal), tone: AppColors.danger),
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

IpvDoc? _latestIpv(List<IpvDoc> documents) {
  IpvDoc? best;
  for (final row in documents) {
    if (best == null ||
        row.workDate.compareTo(best.workDate) > 0 ||
        (row.workDate == best.workDate && row.id.compareTo(best.id) > 0)) {
      best = row;
    }
  }
  return best;
}

