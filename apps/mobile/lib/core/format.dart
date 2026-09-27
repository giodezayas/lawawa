String isoDate([DateTime? value]) {
  final date = value ?? DateTime.now();
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String formatDateOnly(String iso) {
  if (iso.length < 10) {
    return iso;
  }
  return '${iso.substring(0, 4)}/${iso.substring(5, 7)}/${iso.substring(8, 10)}';
}

String formatMoney(num value) {
  final amount = value.isFinite ? value.toDouble() : 0.0;
  final parts = amount.abs().toStringAsFixed(2).split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  final sign = amount < 0 ? '-' : '';
  return '\$ $sign${buffer.toString()}.${parts[1]}';
}

double parseMoney(String value) {
  return double.tryParse(value.trim()) ?? 0;
}

double asNum(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

({String from, String to}) billingPeriodContaining(String iso, int startDay) {
  final day = startDay.clamp(1, 28);
  final date = DateTime.parse('${iso}T00:00:00');
  if (day == 1) {
    final from = DateTime(date.year, date.month, 1);
    final to = DateTime(date.year, date.month + 1, 0);
    return (from: isoDate(from), to: isoDate(to));
  }
  if (date.day >= day) {
    final from = DateTime(date.year, date.month, day);
    final to = DateTime(date.year, date.month + 1, day).subtract(const Duration(days: 1));
    return (from: isoDate(from), to: isoDate(to));
  }
  final from = DateTime(date.year, date.month - 1, day);
  final to = DateTime(date.year, date.month, day).subtract(const Duration(days: 1));
  return (from: isoDate(from), to: isoDate(to));
}

({String from, String to}) shiftBillingPeriod(String from, String to, int startDay, int direction) {
  final pivot = DateTime.parse('${direction > 0 ? to : from}T00:00:00').add(Duration(days: direction > 0 ? 1 : -1));
  return billingPeriodContaining(isoDate(pivot), startDay);
}

String billingPeriodLabel(int startDay) {
  final day = startDay.clamp(1, 28);
  return day == 1 ? 'Del Día 1 Al Último Del Mes' : 'Del Día $day Al ${day - 1} Del Mes Siguiente';
}

String ipvTodayLabel(String status) {
  if (status == 'closed') {
    return 'Cerrado';
  }
  if (status == 'open') {
    return 'Abierto';
  }
  return 'Sin IPV';
}

String cadenceLabel(String cadence) {
  return switch (cadence) {
    'daily' => 'Diario',
    'weekly' => 'Semanal',
    'monthly' => 'Mensual',
    _ => 'Una Vez',
  };
}

String paymentLabel(String method) {
  return method == 'transfer' ? 'Transferencia' : 'Efectivo';
}

String movementLabel(String kind) {
  return switch (kind) {
    'purchase' => 'Compra',
    'ipv_sale' => 'Venta IPV',
    'ipv_outbound' => 'Salida IPV',
    'ipv_inbound' => 'Entrada IPV',
    'ipv_close' => 'Ajuste Al Cierre IPV',
    'adjustment' => 'Ajuste',
    _ => kind,
  };
}
