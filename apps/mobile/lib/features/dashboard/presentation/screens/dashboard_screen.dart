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
  ({double cash, double transfer}) _periodRecaudo = (cash: 0, transfer: 0);
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
      final purchases = await api.purchases();
      final expenses = await api.expenses();
      final opening = await api.cardOpening();
      final ledgerTo = opening != null && opening.asOf.compareTo(period.to) > 0 ? opening.asOf : period.to;
      final moveFrom = opening != null && opening.asOf.compareTo(period.from) < 0 ? opening.asOf : period.from;
      final moves = await api.cashMoves(moveFrom, ledgerTo);
      if (!mounted) {
        return;
      }
      setState(() {
        _period = report;
        _lastIpv = _latestIpv(ipvs);
        _periodRecaudo = _cajaInRange(ipvs, purchases, expenses, period.from, period.to, opening);
        _cards = CardBalances.from(ipvs, moves, period.from, period.to, opening);
        _lowStock = products.where((product) => product.isLowStock).toList();
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
            value: formatMoney(lastIpv?.grossProfit ?? 0),
            tone: moneyColor(lastIpv?.grossProfit ?? 0),
          ),
          const SizedBox(height: 8),
          StatCard(label: 'Estado', value: ipvTodayLabel(lastIpv?.status ?? '')),
          const SizedBox(height: 20),
          RecaudoCards(
            title: 'Última Caja',
            cash: lastIpv?.cashCollected ?? 0,
            transfer: lastIpv?.transferCollected ?? 0,
          ),
          const SizedBox(height: 20),
          RecaudoCards(
            title: period == null
                ? 'Caja Del Período'
                : 'Caja Del Período · ${formatDateOnly(period.from)} — ${formatDateOnly(period.to)}',
            cash: _periodRecaudo.cash,
            transfer: _periodRecaudo.transfer,
          ),
          if (_cards != null) ...[
            const SizedBox(height: 20),
            const Text('Tarjetas', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            StatCard(label: 'Tarjeta P', value: formatMoney(_cards!.p.balance), tone: moneyColor(_cards!.p.balance)),
            const SizedBox(height: 4),
            Text(
              'Inicial ${formatMoney(_cards!.p.opening)} · Recibido ${formatMoney(_cards!.p.received)} · Extraído ${formatMoney(_cards!.p.withdrawn)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            StatCard(label: 'Tarjeta F', value: formatMoney(_cards!.f.balance), tone: moneyColor(_cards!.f.balance)),
            const SizedBox(height: 4),
            Text(
              'Inicial ${formatMoney(_cards!.f.opening)} · Recibido ${formatMoney(_cards!.f.received)} · Extraído ${formatMoney(_cards!.f.withdrawn)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
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
              'Este Período · ${formatDateOnly(period.from)} — ${formatDateOnly(period.to)} · Impuesto 25%',
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

({double cash, double transfer}) _cajaInRange(
  List<IpvDoc> documents,
  List<PurchaseDoc> purchases,
  List<ExpenseRow> expenses,
  String from,
  String to,
  ({String asOf, double pAmount, double fAmount, String cashAsOf, double cashAmount})? opening,
) {
  String cashFrom = from;
  var cash = 0.0;
  if (opening != null && to.compareTo(opening.cashAsOf) >= 0) {
    cashFrom = isoDate(DateTime.parse('${opening.cashAsOf}T00:00:00').add(const Duration(days: 1)));
    cash = opening.cashAmount;
  }
  var transfer = 0.0;
  for (final row in documents) {
    if (row.workDate.compareTo(from) >= 0 && row.workDate.compareTo(to) <= 0) {
      transfer += row.transferCollected;
    }
    if (cashFrom.compareTo(to) <= 0 && row.workDate.compareTo(cashFrom) >= 0 && row.workDate.compareTo(to) <= 0) {
      cash += row.cashCollected;
    }
  }
  for (final purchase in purchases) {
    if (purchase.purchasedOn.compareTo(from) >= 0 &&
        purchase.purchasedOn.compareTo(to) <= 0 &&
        purchase.paymentMethod == 'transfer') {
      transfer -= purchase.total;
    }
    if (cashFrom.compareTo(to) <= 0 &&
        purchase.purchasedOn.compareTo(cashFrom) >= 0 &&
        purchase.purchasedOn.compareTo(to) <= 0 &&
        purchase.paymentMethod != 'transfer') {
      cash -= purchase.total;
    }
  }
  if (cashFrom.compareTo(to) <= 0) {
    for (final expense in expenses) {
      if (expense.occurredOn.compareTo(cashFrom) < 0 || expense.occurredOn.compareTo(to) > 0) {
        continue;
      }
      cash -= expense.amount;
    }
  }
  return (cash: (cash * 100).round() / 100, transfer: (transfer * 100).round() / 100);
}

