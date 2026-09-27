import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  var _startDay = 1;
  var _anchor = isoDate();
  PeriodReport? _report;
  CashFlow? _flow;
  var _error = '';
  var _loading = true;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      _startDay = await ref.read(wawaClientProvider).billingStartDay();
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
      final bounds = billingPeriodContaining(_anchor, _startDay);
      final report = await ref.read(wawaClientProvider).periodReport(bounds.from, bounds.to);
      final flow = await ref.read(wawaClientProvider).cashFlow(bounds.from, bounds.to);
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
        _flow = flow;
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

  Future<void> _saveStartDay(int day) async {
    try {
      _startDay = await ref.read(wawaClientProvider).setBillingStartDay(day);
      _anchor = isoDate();
      await _load();
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final canManage = auth is AuthAuthenticated && auth.user.canManageStaff;
    final report = _report;
    final bounds = billingPeriodContaining(_anchor, _startDay);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Resultados', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        Text(
          '${billingPeriodLabel(_startDay)}. Impuesto fijo 25% sobre utilidad positiva.',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        ErrorBanner(_error),
        if (canManage)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _saveStartDay(1),
                child: Text('Día 1 Al Último', style: TextStyle(fontWeight: _startDay == 1 ? FontWeight.w800 : FontWeight.w500)),
              ),
              OutlinedButton(
                onPressed: () => _saveStartDay(20),
                child: Text('Día 20 Al 19', style: TextStyle(fontWeight: _startDay == 20 ? FontWeight.w800 : FontWeight.w500)),
              ),
            ],
          ),
        Row(
          children: [
            TextButton(
              onPressed: () {
                final next = shiftBillingPeriod(bounds.from, bounds.to, _startDay, -1);
                setState(() => _anchor = next.from);
                _load();
              },
              child: const Text('Anterior'),
            ),
            Expanded(
              child: Text(
                '${formatDateOnly(bounds.from)} — ${formatDateOnly(bounds.to)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () {
                final next = shiftBillingPeriod(bounds.from, bounds.to, _startDay, 1);
                setState(() => _anchor = next.from);
                _load();
              },
              child: const Text('Siguiente'),
            ),
          ],
        ),
        if (report?.closed == true)
          const Text('Período Cerrado', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))
        else if (canManage)
          PrimaryButton(
            label: 'Cerrar Período',
            loading: _closing,
            onPressed: () async {
              if (!await confirmAction(context, '¿Cerrar este período de facturación? No se podrán editar gastos ni IPV de esas fechas.')) {
                return;
              }
              setState(() => _closing = true);
              try {
                await ref.read(wawaClientProvider).closeBillingPeriod(bounds.from, bounds.to);
                await _load();
              } catch (error) {
                setState(() => _error = error.toString());
              } finally {
                if (mounted) {
                  setState(() => _closing = false);
                }
              }
            },
          ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (report != null && !_loading) ...[
          StatCard(label: 'Venta', value: formatMoney(report.saleTotal)),
          const SizedBox(height: 8),
          StatCard(label: 'Ganancia Bruta', value: formatMoney(report.grossProfit), tone: moneyColor(report.grossProfit)),
          const SizedBox(height: 8),
          StatCard(label: 'Gastos', value: formatMoney(report.expenseTotal)),
          const SizedBox(height: 8),
          StatCard(label: 'Utilidad', value: formatMoney(report.utilidad), tone: moneyColor(report.utilidad)),
          const SizedBox(height: 8),
          StatCard(label: 'Impuestos A Pagar (25%)', value: formatMoney(report.tax), tone: AppColors.danger),
          const SizedBox(height: 8),
          StatCard(label: 'Te Quedas', value: formatMoney(report.net), tone: moneyColor(report.net)),
          const SizedBox(height: 20),
          if (_flow != null) CashFlowCards(flow: _flow!, title: 'Caja Del Período'),
          const SizedBox(height: 20),
          const Text('Gastos Del Período', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ...report.lines.map(
            (line) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.name),
              subtitle: Text('${formatDateOnly(line.occurredOn)} · ${cadenceLabel(line.cadence)}'),
              trailing: Text(formatMoney(line.amount)),
            ),
          ),
        ],
      ],
    );
  }
}
