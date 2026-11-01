import { cardFCollectedInPeriod, declaredBilling, periodTaxes } from './src/entities/tax.ts';

const collected = cardFCollectedInPeriod(
  [
    { workDate: '2026-10-01', transferFCollected: 100 },
    { workDate: '2026-11-01', transferFCollected: 50 },
  ],
  '2026-10-01',
  '2026-10-31',
);
if (collected !== 100 || declaredBilling(collected) !== 300) {
  throw new Error(`Expected F 100 and billing 300, got ${collected} / ${declaredBilling(collected)}`);
}
const taxes = periodTaxes(300);
if (taxes.sale.tribute0114022 !== 30) {
  throw new Error(`Expected 10% of 300, got ${taxes.sale.tribute0114022}`);
}
console.log('tax billing ok');
