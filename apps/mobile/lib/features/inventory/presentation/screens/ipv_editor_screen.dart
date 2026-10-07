import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'ipv_line_table_row.dart';

class IpvEditorScreen extends ConsumerStatefulWidget {
  const IpvEditorScreen({super.key, this.ipvId});

  final String? ipvId;

  @override
  ConsumerState<IpvEditorScreen> createState() => _IpvEditorScreenState();
}

class _IpvEditorScreenState extends ConsumerState<IpvEditorScreen> {
  final _date = TextEditingController(text: isoDate());
  final _transferP = TextEditingController();
  final _transferF = TextEditingController();
  final _opening = TextEditingController();
  final _inbound = TextEditingController();
  final _outbound = TextEditingController();
  final _sold = TextEditingController();
  final _salePrice = TextEditingController();
  final _cost = TextEditingController();
  IpvDoc? _doc;
  List<ProductRow> _products = [];
  List<ExpenseRow> _expenses = [];
  String? _selectedId;
  var _addsStock = false;
  var _error = '';
  var _loading = false;
  var _addingLine = false;
  String? _savingLineId;
  String? _deletingLineId;
  var _lineNotice = '';

  bool get _create => widget.ipvId == null;
  bool get _canEditClosed {
    final auth = ref.read(authControllerProvider);
    return auth is AuthAuthenticated && auth.user.canManageStaff;
  }

  bool get _locked => _doc != null && !_doc!.isOpen && !_canEditClosed;
  bool get _isClosed => _doc != null && !_doc!.isOpen;

  @override
  void initState() {
    super.initState();
    _transferP.addListener(_onTransferChanged);
    _transferF.addListener(_onTransferChanged);
    _boot();
  }

  void _onTransferChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _transferP
      ..removeListener(_onTransferChanged)
      ..dispose();
    _transferF
      ..removeListener(_onTransferChanged)
      ..dispose();
    _opening.dispose();
    _inbound.dispose();
    _outbound.dispose();
    _sold.dispose();
    _salePrice.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final api = ref.read(wawaClientProvider);
      _products = await api.products();
      _expenses = await api.expenses();
      if (widget.ipvId != null) {
        await _reload(widget.ipvId!);
      }
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _reload(String id) async {
    final doc = await ref.read(wawaClientProvider).ipv(id);
    _doc = doc;
    _transferP.text = doc.transferPCollected.toString();
    _transferF.text = doc.transferFCollected.toString();
    _expenses = await ref.read(wawaClientProvider).expenses();
    setState(() {});
  }

  void _showLineNotice(String message) {
    setState(() => _lineNotice = message);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _lineNotice = '');
      }
    });
  }

  IpvDoc _withLines(IpvDoc doc, List<IpvLineRow> lines) {
    return IpvDoc(
      id: doc.id,
      workDate: doc.workDate,
      status: doc.status,
      cashCollected: doc.cashCollected,
      transferPCollected: doc.transferPCollected,
      transferFCollected: doc.transferFCollected,
      lines: lines,
    );
  }

  void _patchLine(IpvLineRow saved) {
    final doc = _doc;
    if (doc == null) {
      return;
    }
    final exists = doc.lines.any((line) => line.id == saved.id);
    final lines = exists
        ? doc.lines.map((line) => line.id == saved.id ? saved : line).toList()
        : [...doc.lines, saved];
    setState(() => _doc = _withLines(doc, lines));
  }

  Future<void> _createIpv() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final created = await ref.read(wawaClientProvider).createIpv(_date.text, auth.user.id);
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => IpvEditorScreen(ipvId: created.id)));
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addLine() async {
    final doc = _doc;
    ProductRow? product;
    for (final item in _products) {
      if (item.id == _selectedId) {
        product = item;
      }
    }
    if (doc == null || product == null || _locked) {
      return;
    }
    var sortOrder = doc.lines.length;
    for (var i = 0; i < doc.lines.length; i++) {
      if (doc.lines[i].productId == product.id) {
        sortOrder = i;
      }
    }
    setState(() {
      _error = '';
      _addingLine = true;
    });
    try {
      final saved = await ref.read(wawaClientProvider).upsertIpvLine(
        ipvId: doc.id,
        productId: product.id,
        productName: product.name,
        openingQty: parseMoney(_opening.text),
        inboundQty: parseMoney(_inbound.text),
        outboundQty: parseMoney(_outbound.text),
        soldQty: parseMoney(_sold.text),
        salePrice: parseMoney(_salePrice.text),
        replenishmentCost: parseMoney(_cost.text),
        inboundAddsStock: _addsStock,
        sortOrder: sortOrder,
      );
      _opening.clear();
      _inbound.clear();
      _outbound.clear();
      _sold.clear();
      _salePrice.clear();
      _cost.clear();
      _selectedId = null;
      _addsStock = false;
      _patchLine(saved);
      _showLineNotice('Producto agregado.');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _addingLine = false);
      }
    }
  }

  Future<void> _saveCash() async {
    final doc = _doc;
    if (doc == null || _locked) {
      return;
    }
    try {
      await ref.read(wawaClientProvider).updateIpvCollections(
        doc.id,
        parseMoney(_transferP.text),
        parseMoney(_transferF.text),
      );
      await _reload(doc.id);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _close() async {
    final doc = _doc;
    final auth = ref.read(authControllerProvider);
    if (doc == null || auth is! AuthAuthenticated) {
      return;
    }
    try {
      await ref.read(wawaClientProvider).updateIpvCollections(
        doc.id,
        parseMoney(_transferP.text),
        parseMoney(_transferF.text),
      );
      await ref.read(wawaClientProvider).closeIpv(doc.id);
      await _reload(doc.id);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_create) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crear IPV')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ErrorBanner(_error),
            LabeledField(label: 'Fecha', controller: _date, keyboardType: TextInputType.datetime),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Crear IPV', loading: _loading, onPressed: _createIpv),
          ],
        ),
      );
    }

    final doc = _doc;
    if (doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cash = ((doc.saleTotal - parseMoney(_transferP.text) - parseMoney(_transferF.text)) * 100).round() / 100;
    final collected = cash + parseMoney(_transferP.text) + parseMoney(_transferF.text);
    final cut = IpvDayCut.compute(
      grossProfit: doc.grossProfit,
      otherExpenses: otherExpensesOnDate(_expenses, doc.workDate),
    );
    return Scaffold(
      appBar: AppBar(title: Text('IPV ${_isClosed ? 'Cerrado' : 'Abierto'}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(formatDateOnly(doc.workDate), style: const TextStyle(color: AppColors.muted)),
          ErrorBanner(_error),
          if (_lineNotice.isNotEmpty) Text(_lineNotice, style: const TextStyle(color: AppColors.primary)),
          StatCard(label: 'Total De Venta', value: formatMoney(doc.saleTotal)),
          const SizedBox(height: 8),
          StatCard(label: 'Ganancia Bruta', value: formatMoney(cut.utilidad), tone: moneyColor(cut.utilidad)),
          const Text(
            'Después De Salario Y Gastos. Sin Impuesto.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text('Si Cobramos Hoy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Salario y la parte del día de los gastos. Lo que queda son ganancias brutas. El impuesto se declara al cierre del mes.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          StatCard(label: 'Salario', value: formatMoney(cut.salary), tone: AppColors.danger),
          const SizedBox(height: 8),
          StatCard(label: 'Gastos A Reservar', value: formatMoney(cut.otherExpenses), tone: AppColors.danger),
          const SizedBox(height: 8),
          StatCard(label: 'Ganancias Brutas', value: formatMoney(cut.utilidad), tone: moneyColor(cut.utilidad)),
          const Text(
            'Después De Salario Y Gastos. Sin Impuesto.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          StatCard(label: 'Cada Dueño', value: formatMoney(cut.ownerShare), tone: moneyColor(cut.ownerShare)),
          const SizedBox(height: 16),
          const Text('Recaudo Del Día', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          StatCard(label: 'Efectivo', value: formatMoney(cash), tone: moneyColor(cash)),
          const SizedBox(height: 4),
          const Text('Venta menos tarjetas P y F.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          LabeledField(label: 'Tarjeta P', controller: _transferP, keyboardType: TextInputType.number, enabled: !_locked),
          const SizedBox(height: 8),
          LabeledField(label: 'Tarjeta F', controller: _transferF, keyboardType: TextInputType.number, enabled: !_locked),
          const SizedBox(height: 8),
          Text(
            cash < 0
                ? 'La transferencia supera la venta.'
                : 'Venta ${formatMoney(doc.saleTotal)} · Recaudado ${formatMoney(collected)} · Efectivo Luego Del Salario ${formatMoney(cash - ipvDailySalary)} · Queda En Caja ${formatMoney(cash - doc.grossProfit)}',
            style: TextStyle(color: cash < 0 ? AppColors.danger : AppColors.muted),
          ),
          if (!_locked) ...[
            const SizedBox(height: 12),
            PrimaryButton(label: 'Guardar Caja', onPressed: _saveCash),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedId,
              decoration: const InputDecoration(labelText: 'Producto'),
              items: _products
                  .where(
                    (product) =>
                        product.id == _selectedId ||
                        (product.isActive && !doc.lines.any((line) => line.productId == product.id)),
                  )
                  .map((product) => DropdownMenuItem(value: product.id, child: Text(product.name)))
                  .toList(),
              onChanged: (id) async {
                ProductRow? product;
                for (final item in _products) {
                  if (item.id == id) {
                    product = item;
                  }
                }
                setState(() {
                  _selectedId = id;
                  if (product != null) {
                    final fromSack = product.name == 'Azúcar Por Libras';
                    _opening.text = fromSack ? '0' : product.stockQty.toString();
                    _salePrice.text = product.salePrice.toString();
                    _cost.text = product.replenishmentCost.toString();
                    if (fromSack) {
                      _addsStock = false;
                    }
                  }
                });
                final current = _doc;
                if (product != null && current != null) {
                  try {
                    final defaults = await ref.read(wawaClientProvider).ipvLineDefaults(current.id, product.id);
                    if (!mounted || _selectedId != product.id) {
                      return;
                    }
                    setState(() {
                      _opening.text = defaults.openingQty.toString();
                      _salePrice.text = defaults.salePrice.toString();
                      _cost.text = defaults.replenishmentCost.toString();
                    });
                  } catch (_) {}
                }
              },
            ),
            LabeledField(label: 'Entradas', controller: _inbound, keyboardType: TextInputType.number),
            LabeledField(label: 'Salidas', controller: _outbound, keyboardType: TextInputType.number),
            LabeledField(label: 'Vendidos', controller: _sold, keyboardType: TextInputType.number),
            if (_selectedId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Inicio ${_opening.text} · Precio ${formatMoney(parseMoney(_salePrice.text))} · Costo ${formatMoney(parseMoney(_cost.text))}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            if (_products.any((product) => product.id == _selectedId && product.name == 'Azúcar Por Libras'))
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Pon en Vendidos las libras del día. Al cerrar el IPV se rebajan del saco.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('La Entrada Suma Stock'),
              subtitle: const Text(
                'Si embolsas azúcar 1 lb o 1 kg, al cerrar se descuenta del saco. Azúcar Por Libras se rebaja con Vendidos.',
              ),
              value: _addsStock,
              onChanged: (value) => setState(() => _addsStock = value),
            ),
            PrimaryButton(
              label: doc.lines.any((line) => line.productId == _selectedId) ? 'Guardar Producto' : 'Agregar Producto Al IPV',
              loading: _addingLine,
              onPressed: _addLine,
            ),
          ],
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.6),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
              5: FlexColumnWidth(1),
            },
            children: const [
              TableRow(
                children: [
                  _Head('Producto'),
                  _Head('Inicio'),
                  _Head('Ent.'),
                  _Head('Sal.'),
                  _Head('Vend.'),
                  _Head('Final'),
                ],
              ),
            ],
          ),
          ...doc.lines.map(
            (line) => IpvLineTableRow(
              key: ValueKey(line.id),
              line: line,
              locked: _locked,
              saving: _savingLineId == line.id,
              removing: _deletingLineId == line.id,
              onSave: ({
                required openingQty,
                required inboundQty,
                required outboundQty,
                required soldQty,
                required salePrice,
                required replenishmentCost,
                required inboundAddsStock,
              }) async {
                setState(() {
                  _error = '';
                  _savingLineId = line.id;
                });
                try {
                  final saved = await ref.read(wawaClientProvider).upsertIpvLine(
                    id: line.id,
                    ipvId: doc.id,
                    productId: line.productId,
                    productName: line.productName,
                    openingQty: openingQty,
                    inboundQty: inboundQty,
                    outboundQty: outboundQty,
                    soldQty: soldQty,
                    salePrice: salePrice,
                    replenishmentCost: replenishmentCost,
                    inboundAddsStock: inboundAddsStock,
                    sortOrder: doc.lines.indexWhere((item) => item.id == line.id),
                  );
                  _patchLine(saved);
                  _showLineNotice('Producto guardado.');
                } catch (error) {
                  setState(() => _error = error.toString());
                } finally {
                  if (mounted) {
                    setState(() => _savingLineId = null);
                  }
                }
              },
              onRemove: () async {
                if (!await confirmAction(context, '¿Quitar este producto del IPV?')) {
                  return;
                }
                setState(() {
                  _error = '';
                  _deletingLineId = line.id;
                });
                try {
                  await ref.read(wawaClientProvider).removeIpvLine(line.id);
                  final current = _doc;
                  if (current != null) {
                    setState(() {
                      _doc = _withLines(
                        current,
                        current.lines.where((item) => item.id != line.id).toList(),
                      );
                    });
                  }
                  _showLineNotice('Producto quitado.');
                } catch (error) {
                  setState(() => _error = error.toString());
                } finally {
                  if (mounted) {
                    setState(() => _deletingLineId = null);
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          if (!_isClosed)
            PrimaryButton(label: 'Cerrar IPV', onPressed: _close)
          else
            Text(
              _canEditClosed
                  ? 'Este IPV está cerrado. Como manager o admin puedes corregirlo.'
                  : 'Este IPV está cerrado. El stock del catálogo queda igual al stock final de cada producto.',
              style: const TextStyle(color: AppColors.muted),
            ),
          if (!_isClosed)
            Text(
              'Al cerrar se registra el salario de ${formatMoney(ipvDailySalary)} como gasto del día.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          TextButton(
            onPressed: () async {
              if (!await confirmAction(context, '¿Borrar este IPV?')) {
                return;
              }
              await ref.read(wawaClientProvider).deleteIpv(doc.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Borrar IPV', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
