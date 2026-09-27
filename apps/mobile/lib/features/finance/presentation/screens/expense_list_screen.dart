import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import 'expense_editor_screen.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  List<ExpenseRow> _rows = [];
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
      final rows = await ref.read(wawaClientProvider).expenses();
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Gastos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Nuevo Gasto',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ExpenseEditorScreen()));
              await _load();
            },
          ),
          const SizedBox(height: 16),
          ErrorBanner(_error),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          ..._rows.map(
            (entry) => Card(
              child: ListTile(
                title: Text(entry.name),
                subtitle: Text('${formatDateOnly(entry.occurredOn)} · ${cadenceLabel(entry.cadence)}'),
                trailing: Text(formatMoney(entry.amount)),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => ExpenseEditorScreen(expenseId: entry.id)),
                  );
                  await _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
