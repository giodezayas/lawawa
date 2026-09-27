import type { PaymentMethod, PurchaseDocument } from '../entities/purchase';

export type CreatePurchaseLineInput = {
  productId: string;
  qty: number;
  unitCost: number;
};

export type CreatePurchaseInput = {
  purchasedOn: string;
  paymentMethod: PaymentMethod;
  createdBy: string;
  lines: readonly CreatePurchaseLineInput[];
};

export type UpdatePurchaseInput = {
  id: string;
  purchasedOn: string;
  paymentMethod: PaymentMethod;
  lines: readonly CreatePurchaseLineInput[];
};

export interface PurchaseRepository {
  list(): Promise<PurchaseDocument[]>;
  getById(id: string): Promise<PurchaseDocument | null>;
  create(input: CreatePurchaseInput): Promise<PurchaseDocument>;
  update(input: UpdatePurchaseInput): Promise<PurchaseDocument>;
  remove(id: string): Promise<void>;
}
