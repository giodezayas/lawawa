import { periodDayStats } from './src/entities/sales_stats.ts';
import type { IpvDocument } from './src/entities/ipv.ts';

function doc(
  workDate: string,
  shift: 'manana' | 'noche',
  lines: { productId: string; productName: string; soldQty: number; saleTotal: number }[],
  cashCollected: number,
  transferCollected: number,
): IpvDocument {
  return {
    workDate,
    shift,
    lines,
    cashCollected,
    transferCollected,
    transferPCollected: 0,
    transferFCollected: 0,
  } as IpvDocument;
}

const days = periodDayStats(
  [
    doc(
      '2026-10-01',
      'manana',
      [
        { productId: 'a', productName: 'Malta', soldQty: 2, saleTotal: 20 },
        { productId: 'b', productName: 'Refresco', soldQty: 5, saleTotal: 40 },
      ],
      30,
      30,
    ),
    doc('2026-10-01', 'noche', [{ productId: 'a', productName: 'Malta', soldQty: 4, saleTotal: 40 }], 10, 30),
    doc('2026-11-01', 'manana', [{ productId: 'a', productName: 'Malta', soldQty: 9, saleTotal: 90 }], 90, 0),
  ],
  '2026-10-01',
  '2026-10-31',
);

if (
  days.length !== 1 ||
  days[0]?.topProductName !== 'Malta' ||
  days[0]?.topSoldQty !== 6 ||
  days[0]?.saleTotal !== 100 ||
  days[0]?.cashCollected !== 40 ||
  days[0]?.transferCollected !== 60
) {
  throw new Error(`Expected Malta 6, sales 100, cash 40, transfer 60, got ${JSON.stringify(days)}`);
}

console.log('sales chart ok');
