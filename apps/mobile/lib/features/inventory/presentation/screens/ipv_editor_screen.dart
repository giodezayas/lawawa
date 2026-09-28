import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class IpvEditorScreen extends ConsumerStatefulWidget {
  const IpvEditorScreen({super.key, this.ipvId});

  final String? ipvId;

  @override
  ConsumerState<IpvEditorScreen> createState() => _IpvEditorScreenState();
}

class _IpvEditorScreenState extends ConsumerState<IpvEditorScreen> {
  final _date = TextEditingController(text: isoDate());
  final _cash = TextEditingController();
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
  String? _selectedId;
  var _addsStock = false;
  var _error = '';
  var _loading = false;

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
    _boot();
  }

  @override
  void dispose() {
    _date.dispose();
    _cash.dispose();
    _transferP.dispose();
    _transferF.dispose();
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
      _products = await api.products(activeOnly: true);
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
    _cash.text = doc.cashCollected.toString();
    _transferP.text = doc.transferPCollected.toString();
    _transferF.text = doc.transferFCollected.toString();
    setState(() {});
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
    setState(() => _error = '');
    try {
      await ref.read(wawaClientProvider).upsertIpvLine(
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
      await _reload(doc.id);
    } catch (error) {
      setState(() => _error = error.toString());
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
        parseMoney(_cash.text),
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
        parseMoney(_cash.text),
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

    final collected = parseMoney(_cash.text) + parseMoney(_transferP.text) + parseMoney(_transferF.text);
    return Scaffold(
      appBar: AppBar(title: Text('IPV ${_isClosed ? 'Cerrado' : 'Abierto'}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(formatDateOnly(doc.workDate), style: const TextStyle(color: AppColors.muted)),
          ErrorBanner(_error),
          StatCard(label: 'Total De Venta', value: formatMoney(doc.saleTotal)),
          const SizedBox(height: 8),
          StatCard(label: 'Ganancia Bruta', value: formatMoney(doc.grossProfit), tone: moneyColor(doc.grossProfit)),
          const SizedBox(height: 16),
          const Text('Recaudo Del Día', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          LabeledField(label: 'Efectivo', controller: _cash, keyboardType: TextInputType.number, enabled: !_locked),
          const SizedBox(height: 8),
          LabeledField(label: 'Tarjeta P', controller: _transferP, keyboardType: TextInputType.number, enabled: !_locked),
          const SizedBox(height: 8),
          LabeledField(label: 'Tarjeta F', controller: _transferF, keyboardType: TextInputType.number, enabled: !_locked),
          const SizedBox(height: 8),
          Text(
            'Venta ${formatMoney(doc.saleTotal)} · Recaudado ${formatMoney(collected)} · Diferencia ${formatMoney(collected - doc.saleTotal)}',
            style: const TextStyle(color: AppColors.muted),
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
                        product.id == _selectedId || !doc.lines.any((line) => line.productId == product.id),
                  )
                  .map((product) => DropdownMenuItem(value: product.id, child: Text(product.name)))
                  .toList(),
              onChanged: (id) {
                ProductRow? product;
                for (final item in _products) {
                  if (item.id == id) {
                    product = item;
                  }
                }
                setState(() {
                  _selectedId = id;
                  if (product != null) {
                    _opening.text = product.stockQty.toString();
                    _salePrice.text = product.salePrice.toString();
                    _cost.text = product.replenishmentCost.toString();
                  }
                });
              },
            ),
            LabeledField(label: 'Inicio De Turno', controller: _opening, keyboardType: TextInputType.number),
            LabeledField(label: 'Entradas', controller: _inbound, keyboardType: TextInputType.number),
            LabeledField(label: 'Salidas', controller: _outbound, keyboardType: TextInputType.number),
            LabeledField(label: 'Vendidos', controller: _sold, keyboardType: TextInputType.number),
            LabeledField(label: 'Precio De Venta', controller: _salePrice, keyboardType: TextInputType.number),
            LabeledField(label: 'Costo De Reposición', controller: _cost, keyboardType: TextInputType.number),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('La Entrada Suma Stock'),
              subtitle: const Text(
                'Si embolsas azúcar, al cerrar se descuenta del saco.',
              ),
              value: _addsStock,
              onChanged: (value) => setState(() => _addsStock = value),
            ),
            PrimaryButton(
              label: doc.lines.any((line) => line.productId == _selectedId) ? 'Guardar Producto' : 'Agregar Producto Al IPV',
              onPressed: _addLine,
            ),
          ],
          const SizedBox(height: 16),
          ...doc.lines.map(
            (line) => Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Vendidos ${line.soldQty} · Final ${line.closingQty} · ${formatMoney(line.saleTotal)}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (!_locked)
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedId = line.productId;
                                _opening.text = line.openingQty.toString();
                                _inbound.text = line.inboundQty.toString();
                                _outbound.text = line.outboundQty.toString();
                                _sold.text = line.soldQty.toString();
                                _salePrice.text = line.salePrice.toString();
                                _cost.text = line.replenishmentCost.toString();
                                _addsStock = line.inboundAddsStock;
                              });
                            },
                            child: const Text('Editar'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref.read(wawaClientProvider).removeIpvLine(line.id);
                              await _reload(doc.id);
                            },
                            child: const Text('Quitar', style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
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
