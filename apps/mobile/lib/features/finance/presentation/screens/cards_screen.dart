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
  final _openingP = TextEditingController();
  final _openingF = TextEditingController();
  final _openingCash = TextEditingController(text: '47030');
  var _from = isoDate();
  var _to = isoDate();
  var _moveDate = isoDate();
  var _openingDate = isoDate();
  var _cashOpeningDate = '2026-10-04';
  ({String asOf, double pAmount, double fAmount, String cashAsOf, double cashAmount})? _opening;
  var _card = 'p';
  var _kind = 'transfer_to_cash';
  CardBalances? _ledger;
  List<CashMoveRow> _moves = [];
  var _error = '';
  var _loading = true;
  var _saving = false;
  var _savingOpening = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    _openingP.dispose();
    _openingF.dispose();
    _openingCash.dispose();
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
      final opening = await api.cardOpening();
      final ledgerTo = opening != null && opening.asOf.compareTo(_to) > 0 ? opening.asOf : _to;
      final moveFrom = opening != null && opening.asOf.compareTo(_from) < 0 ? opening.asOf : _from;
      final moves = await api.cashMoves(moveFrom, ledgerTo);
      if (!mounted) {
        return;
      }
      setState(() {
        _opening = opening;
        if (opening != null) {
          _openingDate = opening.asOf;
          _openingP.text = opening.pAmount.toString();
          _openingF.text = opening.fAmount.toString();
          _cashOpeningDate = opening.cashAsOf;
          _openingCash.text = opening.cashAmount.toString();
        }
        _moves = moves.where((move) => move.occurredOn.compareTo(_from) >= 0 && move.occurredOn.compareTo(_to) <= 0).toList();
        _ledger = CardBalances.from(ipvs, moves, _from, _to, opening);
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

  Future<void> _saveOpening() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }
    setState(() {
      _savingOpening = true;
      _error = '';
    });
    try {
      await ref.read(wawaClientProvider).saveCardOpening(
        asOf: _openingDate,
        pAmount: parseMoney(_openingP.text),
        fAmount: parseMoney(_openingF.text),
        cashAsOf: _cashOpeningDate,
        cashAmount: parseMoney(_openingCash.text),
        updatedBy: auth.user.id,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _savingOpening = false);
      }
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
        kind: _kind,
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
          const SizedBox(height: 8),
          const Text(
            'No se parte el recaudo viejo. Anota lo que hay hoy en cada tarjeta; desde esa fecha el IPV P/F y las extracciones nuevas sí cuentan.',
            style: TextStyle(color: AppColors.muted),
          ),
          ErrorBanner(_error),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!_loading && ledger != null) ...[
            const SizedBox(height: 16),
            const Text('Saldo Que Hay Ahora', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desde *'),
              subtitle: Text(formatDateOnly(_openingDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse('${_openingDate}T00:00:00'),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2032),
                );
                if (picked != null) {
                  setState(() => _openingDate = isoDate(picked));
                }
              },
            ),
            LabeledField(label: 'Tarjeta P *', controller: _openingP, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            LabeledField(label: 'Tarjeta F *', controller: _openingF, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            const Text('Efectivo En Caja', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Lo de antes de esta fecha no cuenta. El importe es lo que había en el cajón ese día, ya aparte ganancia, gastos e impuesto.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Caja Desde *'),
              subtitle: Text(formatDateOnly(_cashOpeningDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse('${_cashOpeningDate}T00:00:00'),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2032),
                );
                if (picked != null) {
                  setState(() => _cashOpeningDate = isoDate(picked));
                }
              },
            ),
            LabeledField(label: 'Efectivo *', controller: _openingCash, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Guardar Saldo Inicial', loading: _savingOpening, onPressed: _saveOpening),
            const SizedBox(height: 16),
            _BankFace(name: 'Tarjeta P', letter: 'P', slice: ledger.p),
            const SizedBox(height: 12),
            _BankFace(name: 'Tarjeta F', letter: 'F', slice: ledger.f),
            const SizedBox(height: 16),
            StatCard(
              label: 'Total En Ambas',
              value: formatMoney(ledger.p.balance + ledger.f.balance),
              tone: moneyColor(ledger.p.balance + ledger.f.balance),
            ),
            const SizedBox(height: 24),
            const Text('Registrar Extracción O Depósito', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
                DropdownMenuItem(value: 'p', child: Text('Tarjeta P')),
                DropdownMenuItem(value: 'f', child: Text('Tarjeta F')),
              ],
              onChanged: (value) => setState(() => _card = value ?? 'p'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _kind,
              decoration: const InputDecoration(labelText: 'Tipo *'),
              items: const [
                DropdownMenuItem(value: 'transfer_to_cash', child: Text('Extracción A Efectivo')),
                DropdownMenuItem(value: 'cash_to_transfer', child: Text('Depósito Desde Efectivo')),
              ],
              onChanged: (value) => setState(() => _kind = value ?? 'transfer_to_cash'),
            ),
            const SizedBox(height: 8),
            LabeledField(label: 'Importe *', controller: _amount, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            LabeledField(label: 'Notas', controller: _notes),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Registrar', loading: _saving, onPressed: _save),
            const SizedBox(height: 24),
            const Text('Movimientos', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
                  '${formatDateOnly(move.occurredOn)} · ${formatMoney(move.amount)}${move.notes.isEmpty ? '' : '\n${move.notes}'}${_opening != null && move.occurredOn.compareTo(_opening!.asOf) < 0 ? '\nNo entra en el saldo' : ''}',
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
              style: TextStyle(
                color: slice.balance < 0 ? AppColors.accent : Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('Saldo', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Mini(label: 'Inicial', value: slice.opening)),
              Expanded(child: _Mini(label: 'Recibido', value: slice.received)),
              Expanded(child: _Mini(label: 'Extraído', value: slice.withdrawn)),
              Expanded(child: _Mini(label: 'Depositado', value: slice.deposited)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(formatMoney(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}
