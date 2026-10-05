import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/ui.dart';

class IpvLineTableRow extends StatefulWidget {
  const IpvLineTableRow({
    super.key,
    required this.line,
    required this.locked,
    required this.saving,
    required this.removing,
    required this.onSave,
    required this.onRemove,
  });

  final IpvLineRow line;
  final bool locked;
  final bool saving;
  final bool removing;
  final Future<void> Function({
    required double openingQty,
    required double inboundQty,
    required double outboundQty,
    required double soldQty,
    required double salePrice,
    required double replenishmentCost,
    required bool inboundAddsStock,
  }) onSave;
  final Future<void> Function() onRemove;

  @override
  State<IpvLineTableRow> createState() => _IpvLineTableRowState();
}

class _IpvLineTableRowState extends State<IpvLineTableRow> {
  late final TextEditingController _inbound;
  late final TextEditingController _outbound;
  late final TextEditingController _sold;
  late bool _addsStock;

  @override
  void initState() {
    super.initState();
    _inbound = TextEditingController(text: widget.line.inboundQty.toString());
    _outbound = TextEditingController(text: widget.line.outboundQty.toString());
    _sold = TextEditingController(text: widget.line.soldQty.toString());
    _addsStock = widget.line.inboundAddsStock;
    _inbound.addListener(_refresh);
    _outbound.addListener(_refresh);
    _sold.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _inbound
      ..removeListener(_refresh)
      ..dispose();
    _outbound
      ..removeListener(_refresh)
      ..dispose();
    _sold
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final inbound = parseMoney(_inbound.text);
    final outbound = parseMoney(_outbound.text);
    final sold = parseMoney(_sold.text);
    final closing = line.openingQty + inbound - outbound - sold;
    final saleTotal = sold * line.salePrice;
    final profit = sold * (line.salePrice - line.replenishmentCost);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FlexColumnWidth(1),
          5: FlexColumnWidth(1),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    Text(
                      '${formatMoney(saleTotal)} · ${formatMoney(profit)}',
                      style: TextStyle(color: moneyColor(profit), fontSize: 10),
                    ),
                    Text(
                      'Inicio ${line.openingQty} · ${formatMoney(line.salePrice)} · Costo ${formatMoney(line.replenishmentCost)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              _qty(_inbound, 'Ent.'),
              _qty(_outbound, 'Sal.'),
              _qty(_sold, 'Vend.'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text('Final $closing', style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox.shrink(),
            ],
          ),
          TableRow(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: widget.locked
                    ? Text(_addsStock ? 'Suma' : 'No', style: const TextStyle(fontSize: 11))
                    : Checkbox(
                        value: _addsStock,
                        onChanged: (value) => setState(() => _addsStock = value ?? false),
                      ),
              ),
              if (widget.locked)
                const SizedBox.shrink()
              else
                TextButton(
                  onPressed: widget.saving || widget.removing
                      ? null
                      : () => widget.onSave(
                            openingQty: line.openingQty,
                            inboundQty: inbound,
                            outboundQty: outbound,
                            soldQty: sold,
                            salePrice: line.salePrice,
                            replenishmentCost: line.replenishmentCost,
                            inboundAddsStock: _addsStock,
                          ),
                  child: Text(widget.saving ? 'Guardando...' : 'Guardar'),
                ),
              if (widget.locked)
                const SizedBox.shrink()
              else
                TextButton(
                  onPressed: widget.saving || widget.removing ? null : widget.onRemove,
                  child: Text(
                    widget.removing ? 'Borrando...' : 'Quitar',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
              const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qty(TextEditingController controller, String label) {
    if (widget.locked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Text('${label.split('.').first} ${controller.text}', style: const TextStyle(fontSize: 11)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12),
        decoration: _dec(label),
      ),
    );
  }
}
