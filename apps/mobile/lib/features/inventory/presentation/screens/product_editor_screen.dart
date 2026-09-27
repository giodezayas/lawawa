import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';

class ProductEditorScreen extends ConsumerStatefulWidget {
  const ProductEditorScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends ConsumerState<ProductEditorScreen> {
  final _name = TextEditingController();
  final _sale = TextEditingController();
  final _purchase = TextEditingController();
  final _cost = TextEditingController();
  final _min = TextEditingController();
  final _adjust = TextEditingController();
  List<StockMove> _moves = [];
  var _active = true;
  var _stock = 0.0;
  var _error = '';
  var _loading = false;

  bool get _create => widget.productId == null;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _load(widget.productId!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sale.dispose();
    _purchase.dispose();
    _cost.dispose();
    _min.dispose();
    _adjust.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final api = ref.read(wawaClientProvider);
    final product = await api.product(id);
    final moves = await api.movements(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _name.text = product.name;
      _sale.text = product.salePrice.toString();
      _purchase.text = product.lastPurchasePrice.toString();
      _cost.text = product.replenishmentCost.toString();
      _min.text = product.minStock.toString();
      _active = product.isActive;
      _stock = product.stockQty;
      _moves = moves;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'El nombre del producto es obligatorio.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final api = ref.read(wawaClientProvider);
      if (_create) {
        await api.createProduct(
          name: _name.text.trim(),
          salePrice: parseMoney(_sale.text),
          purchasePrice: parseMoney(_purchase.text),
          replenishmentCost: parseMoney(_cost.text),
          minStock: parseMoney(_min.text),
        );
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }
      await api.updateProduct(
        id: widget.productId!,
        name: _name.text.trim(),
        salePrice: parseMoney(_sale.text),
        purchasePrice: parseMoney(_purchase.text),
        replenishmentCost: parseMoney(_cost.text),
        minStock: parseMoney(_min.text),
        isActive: _active,
      );
      await _load(widget.productId!);
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
      appBar: AppBar(title: Text(_create ? 'Nuevo Producto' : 'Producto')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ErrorBanner(_error),
          LabeledField(label: 'Nombre *', controller: _name),
          LabeledField(label: 'Precio De Venta', controller: _sale, keyboardType: TextInputType.number),
          LabeledField(label: 'Último Precio De Compra', controller: _purchase, keyboardType: TextInputType.number),
          LabeledField(label: 'Costo De Reposición', controller: _cost, keyboardType: TextInputType.number),
          LabeledField(label: 'Stock Mínimo', controller: _min, keyboardType: TextInputType.number),
          if (!_create) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            Text('Stock ${formatMoney(_stock).replaceFirst('\$ ', '')}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            LabeledField(label: 'Ajuste De Stock', controller: _adjust, keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Ajustar Stock',
              onPressed: () async {
                try {
                  await ref.read(wawaClientProvider).adjustStock(widget.productId!, parseMoney(_adjust.text));
                  _adjust.clear();
                  await _load(widget.productId!);
                } catch (error) {
                  setState(() => _error = error.toString());
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('Movimientos', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ..._moves.map(
              (move) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(movementLabel(move.kind)),
                subtitle: Text(formatDateOnly(move.occurredOn)),
                trailing: Text('${move.qty}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Guardar', loading: _loading, onPressed: _save),
          if (!_create)
            TextButton(
              onPressed: () async {
                if (!await confirmAction(context, '¿Borrar este producto?')) {
                  return;
                }
                await ref.read(wawaClientProvider).deleteProduct(widget.productId!);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Borrar Producto', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
    );
  }
}
