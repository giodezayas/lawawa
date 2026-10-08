class ProductRow {
  const ProductRow({
    required this.id,
    required this.name,
    required this.salePrice,
    required this.replenishmentCost,
    required this.lastPurchasePrice,
    required this.minStock,
    required this.stockQty,
    required this.isActive,
    required this.countsForTax,
  });

  final String id;
  final String name;
  final double salePrice;
  final double replenishmentCost;
  final double lastPurchasePrice;
  final double minStock;
  final double stockQty;
  final bool isActive;
  final bool countsForTax;

  bool get isLowStock => minStock > 0 && stockQty <= minStock;
}

class StockMove {
  const StockMove({
    required this.id,
    required this.kind,
    required this.qty,
    required this.occurredOn,
  });

  final String id;
  final String kind;
  final double qty;
  final String occurredOn;
}

class IpvLineRow {
  const IpvLineRow({
    required this.id,
    required this.productId,
    required this.productName,
    required this.openingQty,
    required this.inboundQty,
    required this.outboundQty,
    required this.soldQty,
    required this.closingQty,
    required this.salePrice,
    required this.replenishmentCost,
    required this.saleTotal,
    required this.grossProfit,
    required this.inboundAddsStock,
  });

  final String id;
  final String productId;
  final String productName;
  final double openingQty;
  final double inboundQty;
  final double outboundQty;
  final double soldQty;
  final double closingQty;
  final double salePrice;
  final double replenishmentCost;
  final double saleTotal;
  final double grossProfit;
  final bool inboundAddsStock;
}

class IpvDoc {
  const IpvDoc({
    required this.id,
    required this.workDate,
    required this.status,
    required this.cashCollected,
    required this.transferPCollected,
    required this.transferFCollected,
    required this.lines,
  });

  final String id;
  final String workDate;
  final String status;
  final double cashCollected;
  final double transferPCollected;
  final double transferFCollected;
  final List<IpvLineRow> lines;

  bool get isOpen => status == 'open';
  double get transferCollected => transferPCollected + transferFCollected;
  double get saleTotal => lines.fold(0, (sum, line) => sum + line.saleTotal);
  double get grossProfit => lines.fold(0, (sum, line) => sum + line.grossProfit);
}

class PurchaseLineRow {
  const PurchaseLineRow({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitCost,
  });

  final String productId;
  final String productName;
  final double qty;
  final double unitCost;

  double get total => qty * unitCost;
}

class PurchaseDoc {
  const PurchaseDoc({
    required this.id,
    required this.purchasedOn,
    required this.paymentMethod,
    required this.lines,
  });

  final String id;
  final String purchasedOn;
  final String paymentMethod;
  final List<PurchaseLineRow> lines;

  double get total => lines.fold(0, (sum, line) => sum + line.total);
}

class ExpenseRow {
  const ExpenseRow({
    required this.id,
    required this.name,
    required this.occurredOn,
    required this.cadence,
    required this.amount,
    required this.notes,
  });

  final String id;
  final String name;
  final String occurredOn;
  final String cadence;
  final double amount;
  final String notes;
}

class IpvDayCut {
  const IpvDayCut({
    required this.grossProfit,
    required this.taxableGrossProfit,
    required this.salary,
    required this.otherExpenses,
    required this.expenseTotal,
    required this.utilidad,
    required this.net,
    required this.ownerShare,
  });

  final double grossProfit;
  final double taxableGrossProfit;
  final double salary;
  final double otherExpenses;
  final double expenseTotal;
  final double utilidad;
  final double net;
  final double ownerShare;

  static IpvDayCut compute({
    required double grossProfit,
    double taxableGrossProfit = 0,
    double salary = 1500,
    double otherExpenses = 0,
  }) {
    final expenseTotal = _money(salary + otherExpenses);
    final utilidad = _money(grossProfit - expenseTotal);
    return IpvDayCut(
      grossProfit: _money(grossProfit),
      taxableGrossProfit: _money(taxableGrossProfit),
      salary: salary,
      otherExpenses: _money(otherExpenses),
      expenseTotal: expenseTotal,
      utilidad: utilidad,
      net: utilidad,
      ownerShare: _money(utilidad / 2),
    );
  }
}

double _money(double value) {
  return (value * 100).round() / 100;
}

const declaredMonthlySalary = 7000.0;
const saleTax0510122Exempt = 3260.0;
const salaryTax0520522Exempt = 3740.0;

({double tribute0114022, double tribute0510122, double total}) saleTaxes(double saleTotal) {
  final tribute0114022 = _money((saleTotal > 0 ? saleTotal : 0) * 0.1);
  final base0510 = saleTotal - saleTax0510122Exempt;
  final tribute0510122 = _money((base0510 > 0 ? base0510 : 0) * 0.05);
  return (
    tribute0114022: tribute0114022,
    tribute0510122: tribute0510122,
    total: _money(tribute0114022 + tribute0510122),
  );
}

({double declaredSalary, double tribute0810132, double tribute0820232, double tribute0520522, double total}) salaryTaxes() {
  final tribute0810132 = _money(declaredMonthlySalary * 0.125);
  final tribute0820232 = _money(declaredMonthlySalary * 0.05);
  final base0520 = declaredMonthlySalary - salaryTax0520522Exempt;
  final tribute0520522 = _money((base0520 > 0 ? base0520 : 0) * 0.03);
  return (
    declaredSalary: declaredMonthlySalary,
    tribute0810132: tribute0810132,
    tribute0820232: tribute0820232,
    tribute0520522: tribute0520522,
    total: _money(tribute0810132 + tribute0820232 + tribute0520522),
  );
}

({double total}) periodTaxes(double saleTotal) {
  final sale = saleTaxes(saleTotal);
  final salary = salaryTaxes();
  return (total: _money(sale.total + salary.total));
}

double otherExpensesOnDate(List<ExpenseRow> entries, String workDate) {
  if (workDate.isEmpty) {
    return 0;
  }
  final monthStart = DateTime.parse('${workDate.substring(0, 7)}-01T00:00:00');
  final monthDays = DateTime(monthStart.year, monthStart.month + 1, 1).subtract(const Duration(days: 1)).day;
  var sum = 0.0;
  for (final entry in entries) {
    if (entry.name == 'Salario') {
      continue;
    }
    final start = entry.occurredOn.length >= 10 ? entry.occurredOn.substring(0, 10) : entry.occurredOn;
    if (start.compareTo(workDate) > 0) {
      continue;
    }
    if (entry.cadence == 'daily') {
      sum += entry.amount;
    } else if (entry.cadence == 'weekly') {
      sum += entry.amount / 7;
    } else if (entry.cadence == 'monthly') {
      sum += entry.amount / monthDays;
    } else if (start == workDate) {
      sum += entry.amount;
    }
  }
  return _money(sum);
}

double taxableGrossForLines(List<IpvLineRow> lines, List<ProductRow> products) {
  var sum = 0.0;
  for (final line in lines) {
    var counts = true;
    for (final product in products) {
      if (product.id == line.productId) {
        counts = product.countsForTax;
      }
    }
    if (counts) {
      sum += line.grossProfit;
    }
  }
  return _money(sum);
}

class PeriodLine {
  const PeriodLine({
    required this.id,
    required this.name,
    required this.cadence,
    required this.occurredOn,
    required this.amount,
  });

  final String id;
  final String name;
  final String cadence;
  final String occurredOn;
  final double amount;
}

class PeriodReport {
  const PeriodReport({
    required this.from,
    required this.to,
    required this.saleTotal,
    required this.purchaseTotal,
    required this.grossProfit,
    required this.taxableGrossProfit,
    required this.expenseTotal,
    required this.utilidad,
    required this.tax,
    required this.net,
    required this.closed,
    required this.lines,
  });

  final String from;
  final String to;
  final double saleTotal;
  final double purchaseTotal;
  final double grossProfit;
  final double taxableGrossProfit;
  final double expenseTotal;
  final double utilidad;
  final double tax;
  final double net;
  final bool closed;
  final List<PeriodLine> lines;
}

class CashFlow {
  const CashFlow({
    required this.cashIn,
    required this.transferIn,
    required this.cashOut,
    required this.transferOut,
    this.ipvCash = 0,
    this.ipvTransfer = 0,
    this.cashPurchases = 0,
    this.transferPurchases = 0,
    this.transferToCash = 0,
    this.cashToTransfer = 0,
    this.ipvSalary = 0,
    this.ipvSetAside = 0,
    this.cashOpening = 0,
    this.cashOpeningOn,
    this.firstSaleOn,
  });

  final double cashIn;
  final double transferIn;
  final double cashOut;
  final double transferOut;
  final double ipvCash;
  final double ipvTransfer;
  final double cashPurchases;
  final double transferPurchases;
  final double transferToCash;
  final double cashToTransfer;
  final double ipvSalary;
  final double ipvSetAside;
  final double cashOpening;
  final String? cashOpeningOn;
  final String? firstSaleOn;

  double get cashNet => cashIn - cashOut;
  double get transferNet => transferIn - transferOut;
}

class CashMoveRow {
  const CashMoveRow({
    required this.id,
    required this.occurredOn,
    required this.kind,
    required this.card,
    required this.amount,
    required this.notes,
  });

  final String id;
  final String occurredOn;
  final String kind;
  final String card;
  final double amount;
  final String notes;

  bool get isWithdrawal => kind == 'transfer_to_cash';
  String get kindLabel => isWithdrawal ? 'Extracción A Efectivo' : 'Depósito Desde Efectivo';
  String get cardLabel => card == 'f' ? 'Tarjeta F' : 'Tarjeta P';
}

class CardSlice {
  const CardSlice({
    required this.opening,
    required this.received,
    required this.withdrawn,
    required this.deposited,
    required this.balance,
  });

  final double opening;
  final double received;
  final double withdrawn;
  final double deposited;
  final double balance;
}

class CardBalances {
  const CardBalances({required this.p, required this.f});

  final CardSlice p;
  final CardSlice f;

  static CardBalances from(
    List<IpvDoc> ipvs,
    List<CashMoveRow> moves,
    String from,
    String to,
    ({String asOf, double pAmount, double fAmount, String cashAsOf, double cashAmount})? opening,
  ) {
    if (opening == null) {
      return const CardBalances(
        p: CardSlice(opening: 0, received: 0, withdrawn: 0, deposited: 0, balance: 0),
        f: CardSlice(opening: 0, received: 0, withdrawn: 0, deposited: 0, balance: 0),
      );
    }
    final trackFrom = opening.asOf;
    final activityTo = opening.asOf.compareTo(to) > 0 ? opening.asOf : to;
    var pIn = 0.0;
    var fIn = 0.0;
    var pOut = 0.0;
    var fOut = 0.0;
    var pDep = 0.0;
    var fDep = 0.0;
    var pAllIn = 0.0;
    var fAllIn = 0.0;
    var pAllOut = 0.0;
    var fAllOut = 0.0;
    var pAllDep = 0.0;
    var fAllDep = 0.0;
    for (final doc in ipvs) {
      if (doc.workDate.compareTo(trackFrom) < 0 || doc.workDate.compareTo(activityTo) > 0) {
        continue;
      }
      pAllIn += doc.transferPCollected;
      fAllIn += doc.transferFCollected;
      if (doc.workDate.compareTo(from) >= 0 && doc.workDate.compareTo(to) <= 0) {
        pIn += doc.transferPCollected;
        fIn += doc.transferFCollected;
      }
    }
    for (final move in moves) {
      if (move.occurredOn.compareTo(trackFrom) < 0 || move.occurredOn.compareTo(activityTo) > 0) {
        continue;
      }
      if (move.isWithdrawal) {
        if (move.card == 'f') {
          fAllOut += move.amount;
          if (move.occurredOn.compareTo(from) >= 0 && move.occurredOn.compareTo(to) <= 0) {
            fOut += move.amount;
          }
        } else {
          pAllOut += move.amount;
          if (move.occurredOn.compareTo(from) >= 0 && move.occurredOn.compareTo(to) <= 0) {
            pOut += move.amount;
          }
        }
      } else if (move.card == 'f') {
        fAllDep += move.amount;
        if (move.occurredOn.compareTo(from) >= 0) {
          fDep += move.amount;
        }
      } else {
        pAllDep += move.amount;
        if (move.occurredOn.compareTo(from) >= 0) {
          pDep += move.amount;
        }
      }
    }
    return CardBalances(
      p: CardSlice(
        opening: opening.pAmount,
        received: pIn,
        withdrawn: pOut,
        deposited: pDep,
        balance: opening.pAmount + pAllIn + pAllDep - pAllOut,
      ),
      f: CardSlice(
        opening: opening.fAmount,
        received: fIn,
        withdrawn: fOut,
        deposited: fDep,
        balance: opening.fAmount + fAllIn + fAllDep - fAllOut,
      ),
    );
  }
}

class DashStats {
  const DashStats({
    required this.saleToday,
    required this.profitToday,
    required this.ipvTodayStatus,
  });

  final double saleToday;
  final double profitToday;
  final String ipvTodayStatus;
}

class StaffRow {
  const StaffRow({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isActive;
}

class ProductSalesRow {
  const ProductSalesRow({
    required this.productId,
    required this.productName,
    required this.soldQty,
    required this.saleTotal,
    required this.profit,
    required this.marginPct,
  });

  final String productId;
  final String productName;
  final double soldQty;
  final double saleTotal;
  final double profit;
  final double marginPct;
}

class DaySalesRow {
  const DaySalesRow({
    required this.workDate,
    required this.saleTotal,
    required this.profit,
    required this.cashCollected,
    required this.transferCollected,
  });

  final String workDate;
  final double saleTotal;
  final double profit;
  final double cashCollected;
  final double transferCollected;
}

class SalesInsight {
  const SalesInsight({
    required this.products,
    required this.days,
    required this.mostSold,
    required this.leastSold,
    required this.mostProfitProduct,
    required this.leastProfitProduct,
    required this.bestMargin,
    required this.worstMargin,
    required this.bestSaleDay,
    required this.worstSaleDay,
    required this.bestProfitDay,
    required this.worstProfitDay,
    required this.mostTransferDay,
    required this.leastTransferDay,
  });

  final List<ProductSalesRow> products;
  final List<DaySalesRow> days;
  final ProductSalesRow? mostSold;
  final ProductSalesRow? leastSold;
  final ProductSalesRow? mostProfitProduct;
  final ProductSalesRow? leastProfitProduct;
  final ProductSalesRow? bestMargin;
  final ProductSalesRow? worstMargin;
  final DaySalesRow? bestSaleDay;
  final DaySalesRow? worstSaleDay;
  final DaySalesRow? bestProfitDay;
  final DaySalesRow? worstProfitDay;
  final DaySalesRow? mostTransferDay;
  final DaySalesRow? leastTransferDay;

  static double _round2(double value) => (value * 100).round() / 100;

  static ProductSalesRow? _pickProduct(List<ProductSalesRow> rows, double Function(ProductSalesRow) key, bool max) {
    if (rows.isEmpty) {
      return null;
    }
    return rows.reduce((best, row) {
      final left = key(row);
      final right = key(best);
      if (max) {
        return left > right ? row : best;
      }
      return left < right ? row : best;
    });
  }

  static DaySalesRow? _pickDay(List<DaySalesRow> rows, double Function(DaySalesRow) key, bool max) {
    if (rows.isEmpty) {
      return null;
    }
    return rows.reduce((best, row) {
      final left = key(row);
      final right = key(best);
      if (max) {
        return left > right ? row : best;
      }
      return left < right ? row : best;
    });
  }

  static SalesInsight fromIpvs(List<IpvDoc> documents, String from, String to) {
    final inRange = documents
        .where((doc) => doc.workDate.compareTo(from) >= 0 && doc.workDate.compareTo(to) <= 0 && doc.lines.isNotEmpty)
        .toList();
    final byProduct = <String, ProductSalesRow>{};
    for (final document in inRange) {
      for (final line in document.lines) {
        final current = byProduct[line.productId];
        final soldQty = (current?.soldQty ?? 0) + line.soldQty;
        final saleTotal = _round2((current?.saleTotal ?? 0) + line.saleTotal);
        final profit = _round2((current?.profit ?? 0) + line.grossProfit);
        byProduct[line.productId] = ProductSalesRow(
          productId: line.productId,
          productName: line.productName,
          soldQty: soldQty,
          saleTotal: saleTotal,
          profit: profit,
          marginPct: saleTotal > 0 ? _round2((profit / saleTotal) * 100) : 0,
        );
      }
    }
    final products = byProduct.values.toList()..sort((a, b) => b.soldQty.compareTo(a.soldQty));
    final withSales = products.where((row) => row.saleTotal > 0).toList();
    final days = inRange
        .map(
          (document) => DaySalesRow(
            workDate: document.workDate,
            saleTotal: _round2(document.saleTotal),
            profit: _round2(document.grossProfit),
            cashCollected: document.cashCollected,
            transferCollected: document.transferCollected,
          ),
        )
        .toList()
      ..sort((a, b) => a.workDate.compareTo(b.workDate));
    return SalesInsight(
      products: products,
      days: days,
      mostSold: _pickProduct(products, (row) => row.soldQty, true),
      leastSold: _pickProduct(products, (row) => row.soldQty, false),
      mostProfitProduct: _pickProduct(withSales, (row) => row.profit, true),
      leastProfitProduct: _pickProduct(withSales, (row) => row.profit, false),
      bestMargin: _pickProduct(withSales, (row) => row.marginPct, true),
      worstMargin: _pickProduct(withSales, (row) => row.marginPct, false),
      bestSaleDay: _pickDay(days, (row) => row.saleTotal, true),
      worstSaleDay: _pickDay(days, (row) => row.saleTotal, false),
      bestProfitDay: _pickDay(days, (row) => row.profit, true),
      worstProfitDay: _pickDay(days, (row) => row.profit, false),
      mostTransferDay: _pickDay(days, (row) => row.transferCollected, true),
      leastTransferDay: _pickDay(days, (row) => row.transferCollected, false),
    );
  }
}

