import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import 'product_editor_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  List<ProductRow> _rows = [];
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
      final rows = await ref.read(wawaClientProvider).products();
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
      appBar: AppBar(title: const Text('Productos')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PrimaryButton(
              label: 'Nuevo Producto',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductEditorScreen()));
                await _load();
              },
            ),
            const SizedBox(height: 16),
            ErrorBanner(_error),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ..._rows.map(
              (product) => Card(
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    'Stock ${product.stockQty} · Venta ${formatMoney(product.salePrice)}${product.countsForTax ? '' : ' · No tributa'}${product.isLowStock ? ' · Bajo Stock' : ''}',
                    style: TextStyle(color: product.isLowStock ? AppColors.danger : AppColors.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => ProductEditorScreen(productId: product.id)),
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
