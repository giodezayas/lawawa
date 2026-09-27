import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class PurchaseEditorScreen extends ConsumerStatefulWidget {
  const PurchaseEditorScreen({super.key, this.purchaseId});

  final String? purchaseId;

  @override
  ConsumerState<PurchaseEditorScreen> createState() => _PurchaseEditorScreenState();
}

class _PurchaseEditorScreenState extends ConsumerState<PurchaseEditorScreen> {
  final _date = TextEditingController(text: isoDate());
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  List<ProductRow> _products = [];
  List<PurchaseLineRow> _lines = [];
  String? _productId;
  var _payment = 'cash';
  var _error = '';
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _date.dispose();
    _qty.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    _products = await ref.read(wawaClientProvider).products(activeOnly: true);
    final id = widget.purchaseId;
    if (id != null) {
      final doc = await ref.read(wawaClientProvider).purchase(id);
      _date.text = doc.purchasedOn;
      _payment = doc.paymentMethod;
      _lines = List.of(doc.lines);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _addLine() {
    ProductRow? product;
    for (final item in _products) {
      if (item.id == _productId) {
        product = item;
      }
    }
    if (product == null) {
      return;
    }
    setState(() {
      _lines = [
        ..._lines,
        PurchaseLineRow(
          productId: product!.id,
          productName: product.name,
          qty: parseMoney(_qty.text),
          unitCost: parseMoney(_cost.text),
        ),
      ];
      _productId = null;
      _qty.clear();
      _cost.clear();
    });
  }

  Future<void> _save() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) {
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Agrega al menos un producto.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await ref.read(wawaClientProvider).savePurchase(
        id: widget.purchaseId,
        purchasedOn: _date.text,
        paymentMethod: _payment,
        createdBy: auth.user.id,
        lines: _lines,
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
    final total = _lines.fold<double>(0, (sum, line) => sum + line.total);
    return Scaffold(
      appBar: AppBar(title: Text(widget.purchaseId == null ? 'Nueva Compra' : 'Compra')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ErrorBanner(_error),
          LabeledField(label: 'Fecha', controller: _date, keyboardType: TextInputType.datetime),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _payment,
            decoration: const InputDecoration(labelText: 'Pago'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
              DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
            ],
            onChanged: (value) => setState(() => _payment = value ?? 'cash'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _productId,
            decoration: const InputDecoration(labelText: 'Producto'),
            items: _products.map((product) => DropdownMenuItem(value: product.id, child: Text(product.name))).toList(),
            onChanged: (value) {
              ProductRow? product;
              for (final item in _products) {
                if (item.id == value) {
                  product = item;
                }
              }
              setState(() {
                _productId = value;
                if (product != null) {
                  _cost.text = product.lastPurchasePrice.toString();
                }
              });
            },
          ),
          LabeledField(label: 'Cantidad', controller: _qty, keyboardType: TextInputType.number),
          LabeledField(label: 'Costo Unitario', controller: _cost, keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          PrimaryButton(label: 'Agregar Línea', onPressed: _addLine),
          const SizedBox(height: 16),
          ..._lines.asMap().entries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value.productName),
              subtitle: Text('${entry.value.qty} × ${formatMoney(entry.value.unitCost)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () => setState(() => _lines = [..._lines]..removeAt(entry.key)),
              ),
            ),
          ),
          StatCard(label: 'Total', value: formatMoney(total)),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Guardar Compra', loading: _loading, onPressed: _save),
          if (widget.purchaseId != null)
            TextButton(
              onPressed: () async {
                if (!await confirmAction(context, '¿Borrar esta compra?')) {
                  return;
                }
                await ref.read(wawaClientProvider).deletePurchase(widget.purchaseId!);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Borrar Compra', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
    );
  }
}
