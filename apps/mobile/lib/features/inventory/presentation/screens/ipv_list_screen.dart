import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import 'ipv_editor_screen.dart';

class IpvListScreen extends ConsumerStatefulWidget {
  const IpvListScreen({super.key});

  @override
  ConsumerState<IpvListScreen> createState() => _IpvListScreenState();
}

class _IpvListScreenState extends ConsumerState<IpvListScreen> {
  List<IpvDoc> _rows = [];
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
      final rows = await ref.read(wawaClientProvider).ipvs();
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
          const Text('IPV', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Un IPV por día. Al crearlo se cargan los productos con stock.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Crear IPV',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const IpvEditorScreen()));
              await _load();
            },
          ),
          const SizedBox(height: 16),
          ErrorBanner(_error),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          ..._rows.map(
            (doc) => Card(
              child: ListTile(
                title: Text(formatDateOnly(doc.workDate)),
                subtitle: Text(
                  '${doc.isOpen ? 'Abierto' : 'Cerrado'} · Venta ${formatMoney(doc.saleTotal)}\nEfectivo ${formatMoney(doc.cashCollected)} · Transferencia ${formatMoney(doc.transferCollected)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => IpvEditorScreen(ipvId: doc.id)));
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
