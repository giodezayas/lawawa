import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  var _from = isoDate();
  var _to = isoDate();
  var _moveDate = isoDate();
  var _card = 'p';
  CardBalances? _ledger;
  List<CashMoveRow> _moves = [];
  var _error = '';
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
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
      final api = ref.read(wawaClientProvider);
      final ipvs = await api.ipvs();
      final moves = await api.cashMoves(_from, _to);
      if (!mounted) {
        return;
      }
      setState(() {
        _moves = moves.where((move) => move.isWithdrawal).toList();
        _ledger = CardBalances.from(ipvs, moves, _from, _to, null);
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

  Future<void> _save() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await ref.read(wawaClientProvider).createCashMove(
        occurredOn: _moveDate,
        kind: 'transfer_to_cash',
        card: _card,
        amount: parseMoney(_amount.text),
        notes: _notes.text.trim(),
        createdBy: auth.user.id,
      );
      _amount.clear();
      _notes.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete(String id) async {
    if (!await confirmAction(context, '¿Borrar este movimiento?')) {
      return;
    }
    try {
      await ref.read(wawaClientProvider).deleteCashMove(id);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('Tarjetas')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${formatDateOnly(_from)} — ${formatDateOnly(_to)}',
            style: const TextStyle(color: AppColors.muted),
          ),
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
              const Spacer(),
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
            ],
          ),
          ErrorBanner(_error),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!_loading && ledger != null) ...[
            const SizedBox(height: 16),
            _BankFace(name: 'Cuenta Personal', letter: 'P', slice: ledger.p),
            const SizedBox(height: 12),
            _BankFace(name: 'Cuenta Fiscal', letter: 'F', slice: ledger.f),
            const SizedBox(height: 16),
            StatCard(label: 'Total', value: formatMoney(ledger.p.balance + ledger.f.balance)),
            const SizedBox(height: 24),
            const Text('Registrar Extracción', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha *'),
              subtitle: Text(formatDateOnly(_moveDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse('${_moveDate}T00:00:00'),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2032),
                );
                if (picked != null) {
                  setState(() => _moveDate = isoDate(picked));
                }
              },
            ),
            DropdownButtonFormField<String>(
              value: _card,
              decoration: const InputDecoration(labelText: 'Tarjeta *'),
              items: const [
                DropdownMenuItem(value: 'p', child: Text('Cuenta Personal')),
                DropdownMenuItem(value: 'f', child: Text('Cuenta Fiscal')),
              ],
              onChanged: (value) => setState(() => _card = value ?? 'p'),
            ),
            const SizedBox(height: 8),
            LabeledField(label: 'Importe *', controller: _amount, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            LabeledField(label: 'Notas', controller: _notes),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Registrar', loading: _saving, onPressed: _save),
            const SizedBox(height: 24),
            const Text('Extracciones', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            if (_moves.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Todavía no hay extracciones en este período.', style: TextStyle(color: AppColors.muted)),
              ),
            ..._moves.map(
              (move) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${move.cardLabel} · ${move.kindLabel}'),
                subtitle: Text(
                  '${formatDateOnly(move.occurredOn)} · ${formatMoney(move.amount)}${move.notes.isEmpty ? '' : '\n${move.notes}'}',
                ),
                isThreeLine: move.notes.isNotEmpty,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _delete(move.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BankFace extends StatelessWidget {
  const _BankFace({required this.name, required this.letter, required this.slice});

  final String name;
  final String letter;
  final CardSlice slice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.ink],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('LA WAWA', style: TextStyle(color: AppColors.accent, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white12,
                ),
                child: Text(letter, style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatMoney(slice.balance),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('Queda', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
