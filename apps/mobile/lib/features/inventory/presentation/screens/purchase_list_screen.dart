import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import 'purchase_editor_screen.dart';

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  List<PurchaseDoc> _rows = [];
  CashFlow? _flow;
  var _from = isoDate();
  var _to = isoDate();
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
      final period = await api.billingPeriod();
      final rows = await api.purchases();
      final flow = await api.cashFlow(period.from, period.to);
      if (!mounted) {
        return;
      }
      setState(() {
        _from = period.from;
        _to = period.to;
        _rows = rows;
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

  Future<void> _applyRange(String from, String to) async {
    try {
      final flow = await ref.read(wawaClientProvider).cashFlow(from, to);
      if (!mounted) {
        return;
      }
      setState(() => _flow = flow);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PrimaryButton(
              label: 'Nueva Compra',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PurchaseEditorScreen()));
                await _load();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    final next = shiftCalendarMonth(_from, -1);
                    setState(() {
                      _from = next.from;
                      _to = next.to;
                    });
                    _applyRange(next.from, next.to);
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
                    _applyRange(next.from, next.to);
                  },
                  child: const Text('Siguiente'),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                final live = defaultBillingPeriod();
                setState(() {
                  _from = live.from;
                  _to = live.to;
                });
                _applyRange(live.from, live.to);
              },
              child: const Text('Este Mes'),
            ),
            if (_flow != null) CashFlowCards(flow: _flow!, title: 'Caja Del Período'),
            const SizedBox(height: 16),
            ErrorBanner(_error),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ..._rows.where((doc) => doc.purchasedOn.compareTo(_from) >= 0 && doc.purchasedOn.compareTo(_to) <= 0).map(
              (doc) => Card(
                child: ListTile(
                  title: Text(formatDateOnly(doc.purchasedOn)),
                  subtitle: Text('${paymentLabel(doc.paymentMethod)} · ${formatMoney(doc.total)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => PurchaseEditorScreen(purchaseId: doc.id)),
                    );
                    await _load();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
