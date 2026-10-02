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
  late final TextEditingController _opening;
  late final TextEditingController _inbound;
  late final TextEditingController _outbound;
  late final TextEditingController _sold;
  late final TextEditingController _salePrice;
  late final TextEditingController _cost;
  late bool _addsStock;

  @override
  void initState() {
    super.initState();
    _opening = TextEditingController(text: widget.line.openingQty.toString());
    _inbound = TextEditingController(text: widget.line.inboundQty.toString());
    _outbound = TextEditingController(text: widget.line.outboundQty.toString());
    _sold = TextEditingController(text: widget.line.soldQty.toString());
    _salePrice = TextEditingController(text: widget.line.salePrice.toString());
    _cost = TextEditingController(text: widget.line.replenishmentCost.toString());
    _addsStock = widget.line.inboundAddsStock;
  }

  @override
  void dispose() {
    _opening.dispose();
    _inbound.dispose();
    _outbound.dispose();
    _sold.dispose();
    _salePrice.dispose();
    _cost.dispose();
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
                      '${formatMoney(line.saleTotal)} · ${formatMoney(line.grossProfit)}',
                      style: TextStyle(color: moneyColor(line.grossProfit), fontSize: 10),
                    ),
                  ],
                ),
              ),
              _qty(_opening, 'Inicio'),
              _qty(_inbound, 'Ent.'),
              _qty(_outbound, 'Sal.'),
              _qty(_sold, 'Vend.'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text('Final ${line.closingQty}', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          TableRow(
            children: [
              _qty(_salePrice, 'P. Venta'),
              _qty(_cost, 'Costo'),
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
                            openingQty: parseMoney(_opening.text),
                            inboundQty: parseMoney(_inbound.text),
                            outboundQty: parseMoney(_outbound.text),
                            soldQty: parseMoney(_sold.text),
                            salePrice: parseMoney(_salePrice.text),
                            replenishmentCost: parseMoney(_cost.text),
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
