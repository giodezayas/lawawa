import { IpvDocument, type IpvDocument as IpvDoc } from './ipv';

export type ProductSalesRow = {
  readonly productId: string;
  readonly productName: string;
  readonly soldQty: number;
  readonly saleTotal: number;
  readonly profit: number;
  readonly marginPct: number;
};

export type DaySalesRow = {
  readonly workDate: string;
  readonly saleTotal: number;
  readonly profit: number;
  readonly cashCollected: number;
  readonly transferCollected: number;
};

export type SalesInsight = {
  readonly products: readonly ProductSalesRow[];
  readonly days: readonly DaySalesRow[];
  readonly mostSold: ProductSalesRow | null;
  readonly leastSold: ProductSalesRow | null;
  readonly mostProfitProduct: ProductSalesRow | null;
  readonly leastProfitProduct: ProductSalesRow | null;
  readonly bestMargin: ProductSalesRow | null;
  readonly worstMargin: ProductSalesRow | null;
  readonly bestSaleDay: DaySalesRow | null;
  readonly worstSaleDay: DaySalesRow | null;
  readonly bestProfitDay: DaySalesRow | null;
  readonly worstProfitDay: DaySalesRow | null;
  readonly mostTransferDay: DaySalesRow | null;
  readonly leastTransferDay: DaySalesRow | null;
};

function round2(value: number) {
  return Math.round(value * 100) / 100;
}

function pickProduct(
  rows: ProductSalesRow[],
  key: 'soldQty' | 'profit' | 'marginPct',
  direction: 'max' | 'min',
) {
  if (rows.length === 0) {
    return null;
  }
  return rows.reduce((best, row) => {
    const left = row[key];
    const right = best[key];
    if (direction === 'max') {
      return left > right ? row : best;
    }
    return left < right ? row : best;
  });
}

function pickDay(
  rows: DaySalesRow[],
  key: 'saleTotal' | 'profit' | 'transferCollected',
  direction: 'max' | 'min',
) {
  if (rows.length === 0) {
    return null;
  }
  return rows.reduce((best, row) => {
    const left = row[key];
    const right = best[key];
    if (direction === 'max') {
      return left > right ? row : best;
    }
    return left < right ? row : best;
  });
}

export const SalesInsight = {
  fromIpvs(documents: readonly IpvDoc[], from: string, to: string): SalesInsight {
    const inRange = documents.filter(
      (document) => document.workDate >= from && document.workDate <= to && document.lines.length > 0,
    );

    const byProduct = new Map<string, ProductSalesRow>();
    for (const document of inRange) {
      for (const line of document.lines) {
        const current = byProduct.get(line.productId);
        const soldQty = (current?.soldQty ?? 0) + line.soldQty;
        const saleTotal = round2((current?.saleTotal ?? 0) + line.saleTotal);
        const profit = round2((current?.profit ?? 0) + line.grossProfit);
        byProduct.set(line.productId, {
          productId: line.productId,
          productName: line.productName,
          soldQty,
          saleTotal,
          profit,
          marginPct: saleTotal > 0 ? round2((profit / saleTotal) * 100) : 0,
        });
      }
    }

    const products = [...byProduct.values()].sort((left, right) => right.soldQty - left.soldQty);
    const withSales = products.filter((row) => row.saleTotal > 0);
    const days = inRange
      .map((document) => ({
        workDate: document.workDate,
        saleTotal: round2(IpvDocument.saleTotal(document)),
        profit: round2(IpvDocument.grossProfit(document)),
        cashCollected: document.cashCollected,
        transferCollected: document.transferCollected,
      }))
      .sort((left, right) => left.workDate.localeCompare(right.workDate));

    return {
      products,
      days,
      mostSold: pickProduct(products, 'soldQty', 'max'),
      leastSold: pickProduct(products, 'soldQty', 'min'),
      mostProfitProduct: pickProduct(withSales, 'profit', 'max'),
      leastProfitProduct: pickProduct(withSales, 'profit', 'min'),
      bestMargin: pickProduct(withSales, 'marginPct', 'max'),
      worstMargin: pickProduct(withSales, 'marginPct', 'min'),
      bestSaleDay: pickDay(days, 'saleTotal', 'max'),
      worstSaleDay: pickDay(days, 'saleTotal', 'min'),
      bestProfitDay: pickDay(days, 'profit', 'max'),
      worstProfitDay: pickDay(days, 'profit', 'min'),
      mostTransferDay: pickDay(days, 'transferCollected', 'max'),
      leastTransferDay: pickDay(days, 'transferCollected', 'min'),
    };
  },
};
