import type { CardOpening } from '../entities/card_opening';

export type UpsertCardOpeningInput = {
  asOf: string;
  pAmount: number;
  fAmount: number;
  notes: string;
  updatedBy: string;
};

export interface CardOpeningRepository {
  get(): Promise<CardOpening | null>;
  upsert(input: UpsertCardOpeningInput): Promise<CardOpening>;
}
