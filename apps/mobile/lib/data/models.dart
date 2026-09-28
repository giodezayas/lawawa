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
  });

  final String id;
  final String name;
  final double salePrice;
  final double replenishmentCost;
  final double lastPurchasePrice;
  final double minStock;
  final double stockQty;
  final bool isActive;

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
  });

  final double cashIn;
  final double transferIn;
  final double cashOut;
  final double transferOut;

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
    required this.received,
    required this.withdrawn,
    required this.deposited,
    required this.balance,
  });

  final double received;
  final double withdrawn;
  final double deposited;
  final double balance;
}

class CardBalances {
  const CardBalances({required this.p, required this.f});

  final CardSlice p;
  final CardSlice f;

  static CardBalances from(List<IpvDoc> ipvs, List<CashMoveRow> moves, String from, String to) {
    var pIn = 0.0;
    var fIn = 0.0;
    var pOut = 0.0;
    var fOut = 0.0;
    var pDep = 0.0;
    var fDep = 0.0;
    for (final doc in ipvs) {
      if (doc.workDate.compareTo(from) < 0 || doc.workDate.compareTo(to) > 0) {
        continue;
      }
      pIn += doc.transferPCollected;
      fIn += doc.transferFCollected;
    }
    for (final move in moves) {
      if (move.occurredOn.compareTo(from) < 0 || move.occurredOn.compareTo(to) > 0) {
        continue;
      }
      if (move.isWithdrawal) {
        if (move.card == 'f') {
          fOut += move.amount;
        } else {
          pOut += move.amount;
        }
      } else if (move.card == 'f') {
        fDep += move.amount;
      } else {
        pDep += move.amount;
      }
    }
    return CardBalances(
      p: CardSlice(received: pIn, withdrawn: pOut, deposited: pDep, balance: pIn + pDep - pOut),
      f: CardSlice(received: fIn, withdrawn: fOut, deposited: fDep, balance: fIn + fDep - fOut),
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
