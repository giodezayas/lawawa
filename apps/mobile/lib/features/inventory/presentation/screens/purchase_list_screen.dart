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
      final rows = await ref.read(wawaClientProvider).purchases();
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
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
            ErrorBanner(_error),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ..._rows.map(
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
