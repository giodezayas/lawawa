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

String formatPct(num value) {
  return '${value.toStringAsFixed(1)} %';
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

const ipvDailySalary = 1500.0;

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
  final today = isoDate();
  return (from: startOfMonth(today), to: today);
}

String startOfMonth([String? iso]) {
  final value = iso ?? isoDate();
  return '${value.substring(0, 7)}-01';
}

String endOfMonth([String? iso]) {
  final value = iso ?? isoDate();
  final first = DateTime.parse('${startOfMonth(value)}T00:00:00');
  final nextMonth = DateTime(first.year, first.month + 1, 1);
  final last = nextMonth.subtract(const Duration(days: 1));
  return isoDate(last);
}

({String from, String to}) shiftCalendarMonth(String from, int direction) {
  final first = DateTime.parse('${from.substring(0, 7)}-01T00:00:00');
  final shifted = DateTime(first.year, first.month + direction, 1);
  final start = isoDate(shifted);
  final end = endOfMonth(start);
  final today = isoDate();
  if (start.compareTo(today) <= 0 && today.compareTo(end) <= 0) {
    return (from: start, to: today);
  }
  return (from: start, to: end);
}

({String from, String to}) previousCalendarMonth() {
  return shiftCalendarMonth(startOfMonth(), -1);
}

bool isLiveCurrentMonth(String from, [String? to]) {
  return from == defaultBillingPeriod().from;
}

({String from, String to}) resolveBillingPeriod({String? from, String? to, bool? live}) {
  final livePeriod = defaultBillingPeriod();
  if (live != false || from == livePeriod.from) {
    return livePeriod;
  }
  if (from != null && to != null && to.compareTo(from) >= 0) {
    return (from: from, to: to);
  }
  return livePeriod;
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
