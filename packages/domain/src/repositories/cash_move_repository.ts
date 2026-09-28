import type { CashMove, CashMoveKind, TransferCard } from '../entities/cash_move';

export type CreateCashMoveInput = {
  occurredOn: string;
  kind: CashMoveKind;
  card: TransferCard;
  amount: number;
  notes: string;
  createdBy: string;
};

export interface CashMoveRepository {
  list(from: string, to: string): Promise<CashMove[]>;
  create(input: CreateCashMoveInput): Promise<CashMove>;
  remove(id: string): Promise<void>;
}
