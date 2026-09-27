import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ExpenseEditorScreen extends ConsumerStatefulWidget {
  const ExpenseEditorScreen({super.key, this.expenseId});

  final String? expenseId;

  @override
  ConsumerState<ExpenseEditorScreen> createState() => _ExpenseEditorScreenState();
}

class _ExpenseEditorScreenState extends ConsumerState<ExpenseEditorScreen> {
  final _name = TextEditingController();
  final _date = TextEditingController(text: isoDate());
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  var _cadence = 'once';
  var _error = '';
  var _loading = false;

  @override
  void initState() {
    super.initState();
    final id = widget.expenseId;
    if (id != null) {
      ref.read(wawaClientProvider).expense(id).then((row) {
        if (!mounted) {
          return;
        }
        setState(() {
          _name.text = row.name;
          _date.text = row.occurredOn;
          _amount.text = row.amount.toString();
          _notes.text = row.notes;
          _cadence = row.cadence;
        });
      }).catchError((error) {
        if (mounted) {
          setState(() => _error = error.toString());
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _date.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await ref.read(wawaClientProvider).saveExpense(
        id: widget.expenseId,
        name: _name.text.trim(),
        occurredOn: _date.text,
        cadence: _cadence,
        amount: parseMoney(_amount.text),
        notes: _notes.text.trim(),
        createdBy: auth.user.id,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.expenseId == null ? 'Nuevo Gasto' : 'Gasto')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ErrorBanner(_error),
          LabeledField(label: 'Nombre *', controller: _name),
          LabeledField(label: _cadence == 'once' ? 'Fecha' : 'Desde', controller: _date, keyboardType: TextInputType.datetime),
          DropdownButtonFormField<String>(
            value: _cadence,
            decoration: const InputDecoration(labelText: 'Frecuencia'),
            items: const [
              DropdownMenuItem(value: 'once', child: Text('Una Vez')),
              DropdownMenuItem(value: 'daily', child: Text('Diario')),
              DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
              DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
            ],
            onChanged: (value) => setState(() => _cadence = value ?? 'once'),
          ),
          LabeledField(label: 'Importe', controller: _amount, keyboardType: TextInputType.number),
          LabeledField(label: 'Notas', controller: _notes),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Guardar', loading: _loading, onPressed: _save),
          if (widget.expenseId != null)
            TextButton(
              onPressed: () async {
                if (!await confirmAction(context, '¿Borrar este gasto?')) {
                  return;
                }
                await ref.read(wawaClientProvider).deleteExpense(widget.expenseId!);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Borrar Gasto', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
    );
  }
}
