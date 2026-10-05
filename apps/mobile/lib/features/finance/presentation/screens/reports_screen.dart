import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/ui.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  var _from = isoDate();
  var _to = isoDate();
  SalesInsight? _insight;
  var _error = '';
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
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
      final ipvs = await ref.read(wawaClientProvider).ipvs();
      if (!mounted) {
        return;
      }
      setState(() {
        _insight = SalesInsight.fromIpvs(ipvs, _from, _to);
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

  void _shift(int direction) {
    final next = shiftCalendarMonth(_from, direction);
    setState(() {
      _from = next.from;
      _to = next.to;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final insight = _insight;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Estadísticas de IPV en el rango. Ganancia = venta menos costo de lo vendido. Margen = ganancia / venta.',
            style: TextStyle(color: AppColors.muted),
          ),
          Row(
            children: [
              TextButton(onPressed: () => _shift(-1), child: const Text('Anterior')),
              Expanded(
                child: Text(
                  '${formatDateOnly(_from)} — ${formatDateOnly(_to)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(onPressed: () => _shift(1), child: const Text('Siguiente')),
            ],
          ),
          TextButton(
            onPressed: () {
              final live = defaultBillingPeriod();
              setState(() {
                _from = live.from;
                _to = live.to;
              });
              _load();
            },
            child: const Text('Este Mes'),
          ),
          ErrorBanner(_error),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (!_loading && insight != null) ...[
            const Text('Productos', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _InsightCard(
              label: 'Más Vendido',
              title: insight.mostSold?.productName ?? '—',
              detail: insight.mostSold == null
                  ? 'Sin Ventas En El Rango'
                  : '${insight.mostSold!.soldQty} Unidades · ${formatMoney(insight.mostSold!.saleTotal)}',
            ),
            _InsightCard(
              label: 'Menos Vendido',
              title: insight.leastSold?.productName ?? '—',
              detail: insight.leastSold == null
                  ? 'Sin Ventas En El Rango'
                  : '${insight.leastSold!.soldQty} Unidades · ${formatMoney(insight.leastSold!.saleTotal)}',
            ),
            _InsightCard(
              label: 'Mayor Ganancia',
              title: insight.mostProfitProduct?.productName ?? '—',
              detail: insight.mostProfitProduct == null
                  ? 'Sin Ventas En El Rango'
                  : formatMoney(insight.mostProfitProduct!.profit),
              tone: insight.mostProfitProduct == null ? null : moneyColor(insight.mostProfitProduct!.profit),
            ),
            _InsightCard(
              label: 'Menor Ganancia',
              title: insight.leastProfitProduct?.productName ?? '—',
              detail: insight.leastProfitProduct == null
                  ? 'Sin Ventas En El Rango'
                  : formatMoney(insight.leastProfitProduct!.profit),
              tone: insight.leastProfitProduct == null ? null : moneyColor(insight.leastProfitProduct!.profit),
            ),
            _InsightCard(
              label: 'Mayor Margen',
              title: insight.bestMargin?.productName ?? '—',
              detail: insight.bestMargin == null ? 'Sin Ventas En El Rango' : formatPct(insight.bestMargin!.marginPct),
            ),
            _InsightCard(
              label: 'Menor Margen',
              title: insight.worstMargin?.productName ?? '—',
              detail: insight.worstMargin == null ? 'Sin Ventas En El Rango' : formatPct(insight.worstMargin!.marginPct),
            ),
            const SizedBox(height: 16),
            const Text('Días', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _InsightCard(
              label: 'Mayor Venta',
              title: insight.bestSaleDay == null ? '—' : formatDateOnly(insight.bestSaleDay!.workDate),
              detail: insight.bestSaleDay == null ? 'Sin IPV En El Rango' : formatMoney(insight.bestSaleDay!.saleTotal),
            ),
            _InsightCard(
              label: 'Menor Venta',
              title: insight.worstSaleDay == null ? '—' : formatDateOnly(insight.worstSaleDay!.workDate),
              detail: insight.worstSaleDay == null ? 'Sin IPV En El Rango' : formatMoney(insight.worstSaleDay!.saleTotal),
            ),
            _InsightCard(
              label: 'Mayor Ganancia',
              title: insight.bestProfitDay == null ? '—' : formatDateOnly(insight.bestProfitDay!.workDate),
              detail: insight.bestProfitDay == null ? 'Sin IPV En El Rango' : formatMoney(insight.bestProfitDay!.profit),
              tone: insight.bestProfitDay == null ? null : moneyColor(insight.bestProfitDay!.profit),
            ),
            _InsightCard(
              label: 'Menor Ganancia',
              title: insight.worstProfitDay == null ? '—' : formatDateOnly(insight.worstProfitDay!.workDate),
              detail: insight.worstProfitDay == null ? 'Sin IPV En El Rango' : formatMoney(insight.worstProfitDay!.profit),
              tone: insight.worstProfitDay == null ? null : moneyColor(insight.worstProfitDay!.profit),
            ),
            _InsightCard(
              label: 'Más Transferencia',
              title: insight.mostTransferDay == null ? '—' : formatDateOnly(insight.mostTransferDay!.workDate),
              detail: insight.mostTransferDay == null
                  ? 'Sin IPV En El Rango'
                  : formatMoney(insight.mostTransferDay!.transferCollected),
            ),
            _InsightCard(
              label: 'Menos Transferencia',
              title: insight.leastTransferDay == null ? '—' : formatDateOnly(insight.leastTransferDay!.workDate),
              detail: insight.leastTransferDay == null
                  ? 'Sin IPV En El Rango'
                  : formatMoney(insight.leastTransferDay!.transferCollected),
            ),
            const SizedBox(height: 16),
            const Text('Ranking De Productos', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (insight.products.isEmpty)
              const Text('No hay IPV con productos en esas fechas.', style: TextStyle(color: AppColors.muted))
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1),
                },
                children: [
                  const TableRow(
                    children: [
                      _Head('Producto'),
                      _Head('Unid.', align: TextAlign.right),
                      _Head('Venta', align: TextAlign.right),
                      _Head('Gan.', align: TextAlign.right),
                      _Head('Margen', align: TextAlign.right),
                    ],
                  ),
                  ...insight.products.map(
                    (row) => TableRow(
                      children: [
                        _Cell(row.productName),
                        _Cell('${row.soldQty}', align: TextAlign.right),
                        _Cell(formatMoney(row.saleTotal), align: TextAlign.right),
                        _Cell(formatMoney(row.profit), align: TextAlign.right, color: moneyColor(row.profit)),
                        _Cell(formatPct(row.marginPct), align: TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            const Text('Días Del Rango', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (insight.days.isEmpty)
              const Text('No hay IPV en esas fechas.', style: TextStyle(color: AppColors.muted))
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.3),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1.2),
                },
                children: [
                  const TableRow(
                    children: [
                      _Head('Fecha'),
                      _Head('Venta', align: TextAlign.right),
                      _Head('Gan.', align: TextAlign.right),
                      _Head('Efectivo', align: TextAlign.right),
                      _Head('Transf.', align: TextAlign.right),
                    ],
                  ),
                  ...insight.days.map(
                    (row) => TableRow(
                      children: [
                        _Cell(formatDateOnly(row.workDate)),
                        _Cell(formatMoney(row.saleTotal), align: TextAlign.right),
                        _Cell(formatMoney(row.profit), align: TextAlign.right, color: moneyColor(row.profit)),
                        _Cell(formatMoney(row.cashCollected), align: TextAlign.right),
                        _Cell(formatMoney(row.transferCollected), align: TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.label, required this.title, required this.detail, this.tone});

  final String label;
  final String title;
  final String detail;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tone ?? AppColors.ink)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text, {this.align = TextAlign.left});

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

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.align = TextAlign.left, this.color});

  final String text;
  final TextAlign align;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
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
