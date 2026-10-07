import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/ui.dart';

class TaxesScreen extends ConsumerStatefulWidget {
  const TaxesScreen({super.key});

  @override
  ConsumerState<TaxesScreen> createState() => _TaxesScreenState();
}

class _TaxesScreenState extends ConsumerState<TaxesScreen> {
  var _from = '';
  var _to = '';
  var _saleTotal = 0.0;
  var _error = '';
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final period = await ref.read(wawaClientProvider).billingPeriod();
      _from = period.from;
      _to = period.to;
      await _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final report = await ref.read(wawaClientProvider).periodReport(_from, _to);
      if (!mounted) {
        return;
      }
      setState(() {
        _saleTotal = report.saleTotal;
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

  Future<void> _shift(int direction) async {
    if (_from.isEmpty || _to.isEmpty) {
      return;
    }
    final next = shiftCalendarMonth(_from, direction);
    _from = next.from;
    _to = next.to;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final taxes = periodTaxes(_saleTotal);
    final sale = saleTaxes(_saleTotal);
    final salary = salaryTaxes();
    return Scaffold(
      appBar: AppBar(title: const Text('Impuestos')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ErrorBanner(_error),
            if (_from.isNotEmpty)
              Text('${formatDateOnly(_from)} — ${formatDateOnly(_to)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: () => _shift(-1), child: const Text('Anterior')),
                OutlinedButton(onPressed: () => _shift(1), child: const Text('Siguiente')),
                OutlinedButton(
                  onPressed: () async {
                    final live = defaultBillingPeriod();
                    _from = live.from;
                    _to = live.to;
                    await _load();
                  },
                  child: const Text('Este Mes'),
                ),
              ],
            ),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            if (!_loading) ...[
              const SizedBox(height: 20),
              Text('Venta Del Período ${formatMoney(_saleTotal)}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              StatCard(label: '0114022 · 10%', value: formatMoney(sale.tribute0114022), tone: AppColors.danger),
              const SizedBox(height: 8),
              StatCard(label: '0510122 · 5% Menos \$ 3,260.00', value: formatMoney(sale.tribute0510122), tone: AppColors.danger),
              const SizedBox(height: 16),
              const Text('Salario declarado \$ 7,000.00 al mes. Se pagan \$ 1,500.00 diarios.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              StatCard(label: '0810132 · 12.5%', value: formatMoney(salary.tribute0810132), tone: AppColors.danger),
              const SizedBox(height: 8),
              StatCard(label: '0820232 · 5%', value: formatMoney(salary.tribute0820232), tone: AppColors.danger),
              const SizedBox(height: 8),
              StatCard(label: '0520522 · 3% Menos \$ 3,740.00', value: formatMoney(salary.tribute0520522), tone: AppColors.danger),
              const SizedBox(height: 16),
              StatCard(label: 'Total A Pagar', value: formatMoney(taxes.total), tone: AppColors.danger),
            ],
          ],
        ),
      ),
    );
  }
}
