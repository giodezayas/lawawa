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
  return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';
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

({String from, String to}) defaultBillingPeriod() {
  return (from: '2026-08-31', to: isoDate());
}

({String from, String to}) shiftBillingRange(String from, String to, int direction) {
  final start = DateTime.parse('${from}T00:00:00');
  final end = DateTime.parse('${to}T00:00:00');
  final span = end.difference(start).inDays + 1;
  if (direction > 0) {
    final nextFrom = DateTime.parse('${to}T00:00:00').add(const Duration(days: 1));
    final nextTo = nextFrom.add(Duration(days: span - 1));
    return (from: isoDate(nextFrom), to: isoDate(nextTo));
  }
  final nextTo = DateTime.parse('${from}T00:00:00').subtract(const Duration(days: 1));
  final nextFrom = nextTo.subtract(Duration(days: span - 1));
  return (from: isoDate(nextFrom), to: isoDate(nextTo));
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
