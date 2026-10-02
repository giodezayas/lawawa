import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'ipv_editor_screen.dart';

class IpvListScreen extends ConsumerStatefulWidget {
  const IpvListScreen({super.key});

  @override
  ConsumerState<IpvListScreen> createState() => _IpvListScreenState();
}

class _IpvListScreenState extends ConsumerState<IpvListScreen> {
  List<IpvDoc> _rows = [];
  var _from = '';
  var _to = '';
  var _error = '';
  var _loading = true;
  var _deletingId = '';

  bool get _canEditClosed {
    final auth = ref.read(authControllerProvider);
    return auth is AuthAuthenticated && auth.user.canManageStaff;
  }

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
      final api = ref.read(wawaClientProvider);
      final period = await api.billingPeriod();
      final rows = await api.ipvs();
      if (!mounted) {
        return;
      }
      setState(() {
        _from = _from.isEmpty ? period.from : _from;
        _to = _to.isEmpty ? period.to : _to;
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

  Future<void> _delete(String id) async {
    if (!await confirmAction(context, '¿Borrar este IPV? El stock del catálogo se va a recalcular.')) {
      return;
    }
    setState(() => _deletingId = id);
    try {
      await ref.read(wawaClientProvider).deleteIpv(id);
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _deletingId = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _rows.where((doc) {
      if (_from.isNotEmpty && doc.workDate.compareTo(_from) < 0) {
        return false;
      }
      if (_to.isNotEmpty && doc.workDate.compareTo(_to) > 0) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('IPV', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Un IPV por día. Al crearlo se cargan los productos con stock. Manager y admin pueden corregir uno cerrado.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Crear IPV',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const IpvEditorScreen()));
              await _load();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Desde'),
            subtitle: Text(_from.isEmpty ? '—' : formatDateOnly(_from)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse('${_from.isEmpty ? isoDate() : _from}T00:00:00'),
                firstDate: DateTime(2024),
                lastDate: DateTime(2032),
              );
              if (picked != null) {
                setState(() => _from = isoDate(picked));
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hasta'),
            subtitle: Text(_to.isEmpty ? '—' : formatDateOnly(_to)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse('${_to.isEmpty ? isoDate() : _to}T00:00:00'),
                firstDate: DateTime(2024),
                lastDate: DateTime(2032),
              );
              if (picked != null) {
                setState(() => _to = isoDate(picked));
              }
            },
          ),
          ErrorBanner(_error),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!_loading)
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.1),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1),
                6: FlexColumnWidth(1.2),
                7: FlexColumnWidth(1.4),
              },
              children: [
                const TableRow(
                  children: [
                    _H('Fecha'),
                    _H('Estado'),
                    _H('Venta', align: TextAlign.right),
                    _H('Efectivo', align: TextAlign.right),
                    _H('P', align: TextAlign.right),
                    _H('F', align: TextAlign.right),
                    _H('Gan.', align: TextAlign.right),
                    _H(''),
                  ],
                ),
                if (filtered.isEmpty)
                  TableRow(
                    children: List.generate(
                      8,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: index == 0
                            ? Text(
                                _rows.isEmpty ? 'No hay IPV todavía. Crea el del día.' : 'No hay IPV en esas fechas.',
                                style: const TextStyle(color: AppColors.muted, fontSize: 12),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ...filtered.map((doc) {
                  final sale = doc.lines.isEmpty ? '—' : formatMoney(doc.saleTotal);
                  final profit = doc.lines.isEmpty ? '—' : formatMoney(doc.grossProfit);
                  return TableRow(
                    children: [
                      _C(formatDateOnly(doc.workDate)),
                      _C(doc.isOpen ? 'Abierto' : 'Cerrado'),
                      _C(sale, align: TextAlign.right),
                      _C(formatMoney(doc.cashCollected), align: TextAlign.right),
                      _C(formatMoney(doc.transferPCollected), align: TextAlign.right),
                      _C(formatMoney(doc.transferFCollected), align: TextAlign.right),
                      _C(
                        profit,
                        align: TextAlign.right,
                        color: doc.lines.isEmpty ? null : moneyColor(doc.grossProfit),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(builder: (_) => IpvEditorScreen(ipvId: doc.id)),
                                );
                                await _load();
                              },
                              child: Text(doc.isOpen || _canEditClosed ? 'Abrir' : 'Ver'),
                            ),
                            TextButton(
                              onPressed: _deletingId == doc.id ? null : () => _delete(doc.id),
                              child: Text(
                                _deletingId == doc.id ? '...' : 'Borrar',
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text, {this.align = TextAlign.left});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(text, textAlign: align, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _C extends StatelessWidget {
  const _C(this.text, {this.align = TextAlign.left, this.color});

  final String text;
  final TextAlign align;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(
        text,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}
