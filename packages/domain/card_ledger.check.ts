import { CardLedger } from './src/entities/card_ledger.ts';
import type { IpvDocument } from './src/entities/ipv.ts';
import type { CashMove } from './src/entities/cash_move.ts';

const ipv = {
  workDate: '2026-10-15',
  transferPCollected: 100,
  transferFCollected: 50,
} as IpvDocument;

const carry = {
  asOf: '2026-10-01',
  pAmount: 999,
  fAmount: 999,
  cashAsOf: '2026-10-04',
  cashAmount: 1,
  notes: '',
};

const day31 = { ...ipv, workDate: '2026-10-31', transferPCollected: 40 } as IpvDocument;
const october = CardLedger.from([ipv, day31], [], '2026-10-01', '2026-10-31', carry);
if (october.p.balance !== 10000) {
  throw new Error(`October personal should remain 10000, got ${october.p.balance}`);
}
if (october.f.balance !== 65000) {
  throw new Error(`October fiscal should remain 65000, got ${october.f.balance}`);
}

const novemberIpv = { ...ipv, workDate: '2026-11-02' } as IpvDocument;
const november = CardLedger.from([ipv, novemberIpv], [] as CashMove[], '2026-11-01', '2026-11-30', carry);
if (november.f.balance !== 50 || november.p.balance !== 100) {
  throw new Error(`November should start at 0, got P ${november.p.balance} F ${november.f.balance}`);
}

console.log('card ledger ok');
