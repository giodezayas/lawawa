import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(message, style: const TextStyle(color: AppColors.danger)),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: tone ?? AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.enabled = true,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class CashFlowCards extends StatelessWidget {
  const CashFlowCards({super.key, required this.flow, required this.title});

  final CashFlow flow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          flow.firstSaleOn == null
              ? 'Todavía no hay venta, así que no hay flujo de caja.'
              : 'Empieza el ${formatDateOnly(flow.firstSaleOn!)}, con la primera venta. Las compras de antes son inversión y no entran aquí.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        StatCard(
          label: 'Efectivo',
          value: formatMoney(flow.cashNet),
          tone: moneyColor(flow.cashNet),
        ),
        const SizedBox(height: 8),
        Text(
          'IPV ${formatMoney(flow.ipvCash)} · De Transferencia ${formatMoney(flow.transferToCash)} · Compras ${formatMoney(flow.cashPurchases)}${flow.ipvSalary > 0 ? ' · Salario ${formatMoney(flow.ipvSalary)}' : ''}${flow.cashToTransfer > 0 ? ' · A Transferencia ${formatMoney(flow.cashToTransfer)}' : ''}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        StatCard(
          label: 'Transferencia',
          value: formatMoney(flow.transferNet),
          tone: moneyColor(flow.transferNet),
        ),
        const SizedBox(height: 8),
        Text(
          'IPV ${formatMoney(flow.ipvTransfer)} · Compras ${formatMoney(flow.transferPurchases)} · Extracciones ${formatMoney(flow.transferToCash)}${flow.cashToTransfer > 0 ? ' · De Efectivo ${formatMoney(flow.cashToTransfer)}' : ''}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

Future<bool> confirmAction(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
      ],
    ),
  );
  return ok == true;
}

Color moneyColor(num value) {
  if (value > 0) {
    return AppColors.success;
  }
  if (value < 0) {
    return AppColors.danger;
  }
  return AppColors.ink;
}
