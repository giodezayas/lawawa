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
  var _from = isoDate();
  var _to = isoDate();
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
      final flow = await ref.read(wawaClientProvider).cashFlow(_from, _to);
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final canManage = auth is AuthAuthenticated && auth.user.canManageStaff;
    final report = _report;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Resultados', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text(
          'Por defecto es el día 1 de este mes hasta hoy.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        ErrorBanner(_error),
        Row(
          children: [
            TextButton(
              onPressed: () {
                  final next = shiftCalendarMonth(_from, -1);
                setState(() {
                  _from = next.from;
                  _to = next.to;
                });
                _load();
              },
              child: const Text('Anterior'),
            ),
            Expanded(
              child: Text(
                '${formatDateOnly(_from)} — ${formatDateOnly(_to)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () {
                  final next = shiftCalendarMonth(_from, 1);
                setState(() {
                  _from = next.from;
                  _to = next.to;
                });
                _load();
              },
              child: const Text('Siguiente'),
            ),
            TextButton(
              onPressed: () {
                final live = defaultBillingPeriod();
                setState(() {
                  _from = live.from;
                  _to = live.to;
                });
                _load();
              },
              child: const Text('Este Mes'),
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
                await ref.read(wawaClientProvider).closeBillingPeriod(_from, _to);
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
          StatCard(label: 'Invertido', value: formatMoney(report.purchaseTotal), tone: AppColors.danger),
          const SizedBox(height: 8),
          StatCard(label: 'Ganancia Bruta', value: formatMoney(report.utilidad), tone: moneyColor(report.utilidad)),
          const Text(
            'Después De Salario Y Gastos. Sin Impuesto.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          StatCard(label: 'Gastos', value: formatMoney(report.expenseTotal)),
          const SizedBox(height: 8),
          StatCard(label: 'Impuestos A Pagar', value: formatMoney(report.tax), tone: AppColors.danger),
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
