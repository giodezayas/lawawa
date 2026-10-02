import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/domain_error.dart';
import '../core/format.dart';
import '../features/auth/data/mappers/user_mapper.dart';
import 'models.dart';

class WawaClient {
  WawaClient(this._client);

  final SupabaseClient _client;

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw DomainError(error.message, 'ERR');
    }
  }

  ProductRow _product(Map<String, dynamic> row) {
    return ProductRow(
      id: row['id'] as String,
      name: row['name'] as String,
      salePrice: asNum(row['sale_price']),
      replenishmentCost: asNum(row['replenishment_cost']),
      lastPurchasePrice: asNum(row['last_purchase_price'] ?? row['purchase_price']),
      minStock: asNum(row['min_stock']),
      stockQty: asNum(row['stock_qty']),
      isActive: row['is_active'] as bool? ?? true,
      countsForTax: row['counts_for_tax'] as bool? ?? true,
    );
  }

  IpvLineRow _ipvLine(Map<String, dynamic> row) {
    return IpvLineRow(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      productName: row['product_name'] as String,
      openingQty: asNum(row['opening_qty']),
      inboundQty: asNum(row['inbound_qty']),
      outboundQty: asNum(row['outbound_qty']),
      soldQty: asNum(row['sold_qty']),
      closingQty: asNum(row['closing_qty']),
      salePrice: asNum(row['sale_price']),
      replenishmentCost: asNum(row['replenishment_cost']),
      saleTotal: asNum(row['sale_total']),
      grossProfit: asNum(row['gross_profit']),
      inboundAddsStock: row['inbound_adds_stock'] as bool? ?? false,
    );
  }

  Future<DashStats> dashboardStats() {
    return _run(() async {
      final row = await _client.from('dashboard_stats').select().maybeSingle();
      if (row == null) {
        throw const DomainError('No se pudieron cargar las estadísticas.', 'ERR');
      }
      return DashStats(
        saleToday: asNum(row['sale_today']),
        profitToday: asNum(row['profit_today']),
        ipvTodayStatus: (row['ipv_today_status'] as String?) ?? '',
      );
    });
  }

  Future<({String from, String to})> billingPeriod() {
    return _run(() async {
      final row = await _client
          .from('business_settings')
          .select('billing_period_from, billing_period_to, billing_period_live')
          .limit(1)
          .maybeSingle();
      if (row?['billing_period_live'] != false) {
        return defaultBillingPeriod();
      }
      final from = row?['billing_period_from'] as String?;
      final to = row?['billing_period_to'] as String?;
      if (from != null && to != null && to.compareTo(from) >= 0) {
        return (from: from, to: to);
      }
      return defaultBillingPeriod();
    });
  }

  Future<({String from, String to})> setBillingPeriod(String from, String to) {
    return _run(() async {
      final existing = await _client.from('business_settings').select('id').limit(1).maybeSingle();
      if (existing == null) {
        throw const DomainError('No hay ajustes del negocio.', 'ERR');
      }
      final row = await _client
          .from('business_settings')
          .update({
            'billing_period_from': from,
            'billing_period_to': to,
            'billing_period_live': isLiveCurrentMonth(from, to),
          })
          .eq('id', existing['id'] as String)
          .select('billing_period_from, billing_period_to, billing_period_live')
          .single();
      if (row['billing_period_live'] != false) {
        return defaultBillingPeriod();
      }
      return (from: '${row['billing_period_from']}', to: '${row['billing_period_to']}');
    });
  }

  Future<PeriodReport> periodReport(String from, String to) {
    return _run(() async {
      final data = await _client.rpc('period_report', params: {'p_from': from, 'p_to': to});
      final row = Map<String, dynamic>.from(data as Map);
      final rawLines = (row['lines'] as List?) ?? [];
      final docs = await _client
          .from('purchase_documents')
          .select('id')
          .gte('purchased_on', from)
          .lte('purchased_on', to);
      final ids = (docs as List).map((item) => (item as Map)['id'] as String).toList();
      var purchaseTotal = 0.0;
      if (ids.isNotEmpty) {
        final lines = await _client.from('purchase_lines').select('qty, unit_cost').inFilter('purchase_id', ids);
        for (final item in lines as List) {
          final line = Map<String, dynamic>.from(item as Map);
          purchaseTotal += asNum(line['qty']) * asNum(line['unit_cost']);
        }
      }
      return PeriodReport(
        from: '${row['from']}',
        to: '${row['to']}',
        saleTotal: asNum(row['sale_total']),
        purchaseTotal: (purchaseTotal * 100).round() / 100,
        grossProfit: asNum(row['gross_profit']),
        taxableGrossProfit: asNum(row['taxable_gross_profit']),
        expenseTotal: asNum(row['expense_total']),
        utilidad: asNum(row['utilidad']),
        tax: asNum(row['tax']),
        net: asNum(row['net']),
        closed: row['closed'] == true,
        lines: rawLines.map((item) {
          final line = Map<String, dynamic>.from(item as Map);
          return PeriodLine(
            id: '${line['category_id']}',
            name: '${line['name']}',
            cadence: '${line['cadence']}',
            occurredOn: '${line['occurred_on']}',
            amount: asNum(line['amount']),
          );
        }).toList(),
      );
    });
  }

  Future<void> closeBillingPeriod(String from, String to) {
    return _run(() async {
      await _client.rpc('close_billing_period', params: {'p_from': from, 'p_to': to});
    });
  }

  Future<CashFlow> cashFlow(String from, String to) {
    return _run(() async {
      final data = await _client.rpc('cash_flow_report', params: {'p_from': from, 'p_to': to});
      final row = Map<String, dynamic>.from(data as Map);
      return CashFlow(
        cashIn: asNum(row['cash_in']),
        transferIn: asNum(row['transfer_in']),
        cashOut: asNum(row['cash_out']),
        transferOut: asNum(row['transfer_out']),
        ipvCash: asNum(row['ipv_cash']),
        ipvTransfer: asNum(row['ipv_transfer']),
        cashPurchases: asNum(row['cash_purchases']),
        transferPurchases: asNum(row['transfer_purchases']),
        transferToCash: asNum(row['transfer_to_cash']),
        cashToTransfer: asNum(row['cash_to_transfer']),
        ipvSalary: asNum(row['ipv_salary']),
        firstSaleOn: row['first_sale_on'] is String ? row['first_sale_on'] as String : null,
      );
    });
  }

  Future<List<CashMoveRow>> cashMoves(String from, String to) {
    return _run(() async {
      final rows = await _client
          .from('cash_moves')
          .select()
          .gte('occurred_on', from)
          .lte('occurred_on', to)
          .order('occurred_on', ascending: false);
      return (rows as List).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return CashMoveRow(
          id: row['id'] as String,
          occurredOn: '${row['occurred_on']}',
          kind: '${row['kind']}',
          card: row['card'] == 'f' ? 'f' : 'p',
          amount: asNum(row['amount']),
          notes: (row['notes'] as String?) ?? '',
        );
      }).toList();
    });
  }

  Future<void> createCashMove({
    required String occurredOn,
    required String kind,
    required String card,
    required double amount,
    required String notes,
    required String createdBy,
  }) {
    return _run(() async {
      if (amount <= 0) {
        throw const DomainError('El importe tiene que ser mayor que 0.', 'ERR');
      }
      await _client.from('cash_moves').insert({
        'occurred_on': occurredOn,
        'kind': kind,
        'card': card,
        'amount': amount,
        'notes': notes,
        'created_by': createdBy,
      });
    });
  }

  Future<void> deleteCashMove(String id) {
    return _run(() async {
      await _client.from('cash_moves').delete().eq('id', id);
    });
  }

  Future<({String asOf, double pAmount, double fAmount})?> cardOpening() {
    return _run(() async {
      final row = await _client.from('card_opening').select().limit(1).maybeSingle();
      if (row == null) {
        return null;
      }
      return (
        asOf: '${row['as_of']}',
        pAmount: asNum(row['p_amount']),
        fAmount: asNum(row['f_amount']),
      );
    });
  }

  Future<void> saveCardOpening({
    required String asOf,
    required double pAmount,
    required double fAmount,
    required String updatedBy,
  }) {
    return _run(() async {
      if (pAmount < 0 || fAmount < 0) {
        throw const DomainError('El saldo de las tarjetas no puede ser negativo.', 'ERR');
      }
      await _client.from('card_opening').upsert({
        'id': true,
        'as_of': asOf,
        'p_amount': pAmount,
        'f_amount': fAmount,
        'updated_by': updatedBy,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<List<ProductRow>> products({bool activeOnly = false}) {
    return _run(() async {
      final rows = activeOnly
          ? await _client.from('product_catalog').select().eq('is_active', true).order('name')
          : await _client.from('product_catalog').select().order('name');
      return (rows as List).map((row) => _product(Map<String, dynamic>.from(row as Map))).toList();
    });
  }

  Future<ProductRow> product(String id) {
    return _run(() async {
      final row = await _client.from('product_catalog').select().eq('id', id).maybeSingle();
      if (row == null) {
        throw const DomainError('No encontramos ese producto.', 'ERR');
      }
      return _product(row);
    });
  }

  Future<List<StockMove>> movements(String productId) {
    return _run(() async {
      final rows = await _client
          .from('stock_movements')
          .select()
          .eq('product_id', productId)
          .order('occurred_on', ascending: false);
      return (rows as List).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return StockMove(
          id: row['id'] as String,
          kind: row['kind'] as String,
          qty: asNum(row['qty']),
          occurredOn: '${row['occurred_on']}',
        );
      }).toList();
    });
  }

  Future<void> createProduct({
    required String name,
    required double salePrice,
    required double purchasePrice,
    required double replenishmentCost,
    required double minStock,
    bool countsForTax = true,
  }) {
    return _run(() async {
      await _client.from('products').insert({
        'name': name,
        'sale_price': salePrice,
        'purchase_price': purchasePrice,
        'replenishment_cost': replenishmentCost,
        'min_stock': minStock,
        'counts_for_tax': countsForTax,
      });
    });
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required double salePrice,
    required double purchasePrice,
    required double replenishmentCost,
    required double minStock,
    required bool isActive,
    required bool countsForTax,
  }) {
    return _run(() async {
      await _client.from('products').update({
        'name': name,
        'sale_price': salePrice,
        'purchase_price': purchasePrice,
        'replenishment_cost': replenishmentCost,
        'min_stock': minStock,
        'is_active': isActive,
        'counts_for_tax': countsForTax,
      }).eq('id', id);
    });
  }

  Future<void> adjustStock(String id, double qty) {
    return _run(() async {
      await _client.rpc('adjust_product_stock', params: {'p_id': id, 'p_qty': qty});
    });
  }

  Future<void> deleteProduct(String id) {
    return _run(() async {
      await _client.rpc('delete_product', params: {'p_id': id});
    });
  }

  Future<List<IpvDoc>> ipvs() {
    return _run(() async {
      final docs = await _client.from('ipv_documents').select().order('work_date', ascending: false);
      final lines = await _client.from('ipv_lines').select();
      final byIpv = <String, List<IpvLineRow>>{};
      for (final item in lines as List) {
        final row = Map<String, dynamic>.from(item as Map);
        final ipvId = row['ipv_id'] as String;
        byIpv.putIfAbsent(ipvId, () => []).add(_ipvLine(row));
      }
      return (docs as List).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return IpvDoc(
          id: row['id'] as String,
          workDate: '${row['work_date']}',
          status: row['status'] as String,
          cashCollected: asNum(row['cash_collected']),
          transferPCollected: _transferP(row),
          transferFCollected: _transferF(row),
          lines: byIpv[row['id'] as String] ?? const [],
        );
      }).toList();
    });
  }

  Future<IpvDoc> ipv(String id) {
    return _run(() async {
      final row = await _client.from('ipv_documents').select().eq('id', id).maybeSingle();
      if (row == null) {
        throw const DomainError('No encontramos ese IPV.', 'ERR');
      }
      final lines = await _client.from('ipv_lines').select().eq('ipv_id', id).order('sort_order');
      return IpvDoc(
        id: row['id'] as String,
        workDate: '${row['work_date']}',
        status: row['status'] as String,
        cashCollected: asNum(row['cash_collected']),
        transferPCollected: _transferP(row),
        transferFCollected: _transferF(row),
        lines: (lines as List).map((item) => _ipvLine(Map<String, dynamic>.from(item as Map))).toList(),
      );
    });
  }

  Future<IpvDoc> createIpv(String workDate, String createdBy) {
    return _run(() async {
      final row = await _client.from('ipv_documents').insert({
        'work_date': workDate,
        'shift': 'manana',
        'created_by': createdBy,
      }).select().single();
      final ipvId = row['id'] as String;
      final catalog = await _client.from('product_catalog').select().eq('is_active', true).gt('stock_qty', 0).order('name');
      final products = (catalog as List)
          .map((item) => _product(Map<String, dynamic>.from(item as Map)))
          .where((product) => product.isActive && product.stockQty > 0)
          .toList();
      if (products.isNotEmpty) {
        await _client.from('ipv_lines').insert(
          products
              .asMap()
              .entries
              .map(
                (entry) => {
                  'ipv_id': ipvId,
                  'product_id': entry.value.id,
                  'product_name': entry.value.name,
                  'opening_qty': entry.value.stockQty,
                  'inbound_qty': 0,
                  'outbound_qty': 0,
                  'sold_qty': 0,
                  'sale_price': entry.value.salePrice,
                  'replenishment_cost': entry.value.replenishmentCost,
                  'inbound_adds_stock': false,
                  'sort_order': entry.key,
                },
              )
              .toList(),
        );
      }
      return ipv(ipvId);
    });
  }

  Future<IpvLineRow> upsertIpvLine({
    String? id,
    required String ipvId,
    required String productId,
    required String productName,
    required double openingQty,
    required double inboundQty,
    required double outboundQty,
    required double soldQty,
    required double salePrice,
    required double replenishmentCost,
    required bool inboundAddsStock,
    required int sortOrder,
  }) {
    return _run(() async {
      final payload = {
        'opening_qty': openingQty,
        'inbound_qty': inboundQty,
        'outbound_qty': outboundQty,
        'sold_qty': soldQty,
        'sale_price': salePrice,
        'replenishment_cost': replenishmentCost,
        'inbound_adds_stock': inboundAddsStock,
        'sort_order': sortOrder,
      };
      var lineId = id;
      if (lineId == null) {
        final existing = await _client
            .from('ipv_lines')
            .select('id')
            .eq('ipv_id', ipvId)
            .eq('product_id', productId)
            .maybeSingle();
        lineId = existing?['id'] as String?;
      }
      final Map<String, dynamic> row;
      if (lineId != null) {
        row = await _client.from('ipv_lines').update(payload).eq('id', lineId).select().single();
      } else {
        row = await _client.from('ipv_lines').insert({
          'ipv_id': ipvId,
          'product_id': productId,
          'product_name': productName,
          ...payload,
        }).select().single();
      }
      return _ipvLine(row);
    });
  }

  Future<void> removeIpvLine(String id) {
    return _run(() async {
      await _client.from('ipv_lines').delete().eq('id', id);
    });
  }

  Future<void> updateIpvCollections(String id, double transferP, double transferF) {
    return _run(() async {
      if (transferP < 0 || transferF < 0) {
        throw const DomainError('Las transferencias no pueden ser negativas.', 'ERR');
      }
      final doc = await ipv(id);
      final cash = ((doc.saleTotal - transferP - transferF) * 100).round() / 100;
      if (cash < 0) {
        throw const DomainError('La transferencia no puede ser mayor que la venta del día.', 'ERR');
      }
      final row = await _client
          .from('ipv_documents')
          .update({
            'cash_collected': cash,
            'transfer_p_collected': transferP,
            'transfer_f_collected': transferF,
          })
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (row == null) {
        throw const DomainError('No encontramos ese IPV.', 'ERR');
      }
    });
  }

  Future<void> closeIpv(String id) {
    return _run(() async {
      await _client.rpc('close_ipv', params: {'p_id': id});
    });
  }

  Future<void> deleteIpv(String id) {
    return _run(() async {
      await _client.rpc('delete_ipv', params: {'p_id': id});
    });
  }

  Future<List<PurchaseDoc>> purchases() {
    return _run(() async {
      final docs = await _client.from('purchase_documents').select().order('purchased_on', ascending: false);
      final result = <PurchaseDoc>[];
      for (final item in docs as List) {
        final row = Map<String, dynamic>.from(item as Map);
        result.add(await _loadPurchase(row));
      }
      return result;
    });
  }

  Future<PurchaseDoc> purchase(String id) {
    return _run(() async {
      final row = await _client.from('purchase_documents').select().eq('id', id).maybeSingle();
      if (row == null) {
        throw const DomainError('No encontramos esa compra.', 'ERR');
      }
      return _loadPurchase(row);
    });
  }

  Future<PurchaseDoc> _loadPurchase(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final lines = await _client.from('purchase_lines').select().eq('purchase_id', id);
    final ids = (lines as List).map((item) => (item as Map)['product_id'] as String).toSet().toList();
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final products = await _client.from('products').select('id, name').inFilter('id', ids);
      for (final item in products as List) {
        final product = Map<String, dynamic>.from(item as Map);
        names[product['id'] as String] = product['name'] as String;
      }
    }
    return PurchaseDoc(
      id: id,
      purchasedOn: '${row['purchased_on']}',
      paymentMethod: (row['payment_method'] as String?) ?? 'cash',
      lines: (lines).map((item) {
        final line = Map<String, dynamic>.from(item as Map);
        return PurchaseLineRow(
          productId: line['product_id'] as String,
          productName: names[line['product_id'] as String] ?? 'Producto',
          qty: asNum(line['qty']),
          unitCost: asNum(line['unit_cost']),
        );
      }).toList(),
    );
  }

  Future<void> savePurchase({
    String? id,
    required String purchasedOn,
    required String paymentMethod,
    required String createdBy,
    required List<PurchaseLineRow> lines,
  }) {
    return _run(() async {
      late final String purchaseId;
      if (id == null) {
        final row = await _client.from('purchase_documents').insert({
          'purchased_on': purchasedOn,
          'payment_method': paymentMethod,
          'created_by': createdBy,
        }).select('id').single();
        purchaseId = row['id'] as String;
      } else {
        purchaseId = id;
        await _client.from('purchase_documents').update({
          'purchased_on': purchasedOn,
          'payment_method': paymentMethod,
        }).eq('id', id);
        await _client.from('purchase_lines').delete().eq('purchase_id', id);
      }
      await _client.from('purchase_lines').insert(
        lines
            .map(
              (line) => {
                'purchase_id': purchaseId,
                'product_id': line.productId,
                'qty': line.qty,
                'unit_cost': line.unitCost,
              },
            )
            .toList(),
      );
    });
  }

  Future<void> deletePurchase(String id) {
    return _run(() async {
      await _client.from('purchase_documents').delete().eq('id', id);
    });
  }

  Future<List<ExpenseRow>> expenses() {
    return _run(() async {
      final rows = await _client.from('expense_entries').select().order('occurred_on', ascending: false);
      return (rows as List).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return ExpenseRow(
          id: row['id'] as String,
          name: row['name'] as String,
          occurredOn: '${row['occurred_on']}',
          cadence: (row['cadence'] as String?) ?? 'once',
          amount: asNum(row['amount']),
          notes: (row['notes'] as String?) ?? '',
        );
      }).toList();
    });
  }

  Future<ExpenseRow> expense(String id) {
    return _run(() async {
      final row = await _client.from('expense_entries').select().eq('id', id).maybeSingle();
      if (row == null) {
        throw const DomainError('No encontramos ese gasto.', 'ERR');
      }
      return ExpenseRow(
        id: row['id'] as String,
        name: row['name'] as String,
        occurredOn: '${row['occurred_on']}',
        cadence: (row['cadence'] as String?) ?? 'once',
        amount: asNum(row['amount']),
        notes: (row['notes'] as String?) ?? '',
      );
    });
  }

  Future<void> saveExpense({
    String? id,
    required String name,
    required String occurredOn,
    required String cadence,
    required double amount,
    required String notes,
    required String createdBy,
  }) {
    return _run(() async {
      final payload = {
        'name': name,
        'occurred_on': occurredOn,
        'cadence': cadence,
        'amount': amount,
        'notes': notes,
      };
      if (id == null) {
        await _client.from('expense_entries').insert({...payload, 'created_by': createdBy});
        return;
      }
      await _client.from('expense_entries').update(payload).eq('id', id);
    });
  }

  Future<void> deleteExpense(String id) {
    return _run(() async {
      await _client.from('expense_entries').delete().eq('id', id);
    });
  }

  Future<List<StaffRow>> staff() {
    return _run(() async {
      final rows = await _client.from('profiles').select().order('full_name');
      return (rows as List).map((item) {
        final user = UserMapper.fromProfile(Map<String, dynamic>.from(item as Map));
        return StaffRow(
          id: user.id,
          email: user.email,
          fullName: user.fullName,
          role: user.role.name,
          isActive: user.isActive,
        );
      }).toList();
    });
  }

  Future<StaffRow> staffById(String id) {
    return _run(() async {
      final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
      if (row == null) {
        throw const DomainError('No encontramos ese usuario.', 'ERR');
      }
      final user = UserMapper.fromProfile(row);
      return StaffRow(
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        role: user.role.name,
        isActive: user.isActive,
      );
    });
  }

  Future<void> inviteStaff({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) {
    return _run(() async {
      await _client.rpc(
        'invite_staff',
        params: {'p_username': username, 'p_password': password, 'p_full_name': fullName, 'p_role': role},
      );
    });
  }

  Future<void> updateStaff({
    required String id,
    required String fullName,
    required String role,
    required bool isActive,
    String? password,
  }) {
    return _run(() async {
      await _client.rpc(
        'update_staff',
        params: {
          'p_id': id,
          'p_full_name': fullName,
          'p_role': role,
          'p_is_active': isActive,
          if (password != null && password.isNotEmpty) 'p_password': password,
        },
      );
    });
  }

  Future<void> deleteStaff(String id) {
    return _run(() async {
      await _client.rpc('delete_staff', params: {'p_id': id});
    });
  }
}

double _transferP(Map<String, dynamic> row) {
  final p = asNum(row['transfer_p_collected']);
  final f = asNum(row['transfer_f_collected']);
  if (p + f > 0) {
    return p;
  }
  return asNum(row['transfer_collected']);
}

double _transferF(Map<String, dynamic> row) {
  final p = asNum(row['transfer_p_collected']);
  final f = asNum(row['transfer_f_collected']);
  if (p + f > 0) {
    return f;
  }
  return 0;
}
