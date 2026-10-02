import type { CashFlow } from '../entities/cash_flow';
import type { IpvDocument, IpvLine } from '../entities/ipv';

export type CreateIpvInput = {
  workDate: string;
  createdBy: string;
};

export type UpsertIpvLineInput = {
  id?: string;
  ipvId: string;
  productId: string;
  productName: string;
  openingQty: number;
  inboundQty: number;
  outboundQty: number;
  soldQty: number;
  salePrice: number;
  replenishmentCost: number;
  inboundAddsStock: boolean;
  sortOrder: number;
};

export interface IpvRepository {
  list(): Promise<IpvDocument[]>;
  getById(id: string): Promise<IpvDocument | null>;
  create(input: CreateIpvInput): Promise<IpvDocument>;
  upsertLine(input: UpsertIpvLineInput): Promise<IpvLine>;
  removeLine(lineId: string): Promise<void>;
  close(id: string, closedBy: string): Promise<IpvDocument>;
  updateCollections(
    id: string,
    cashCollected: number,
    transferPCollected: number,
    transferFCollected: number,
  ): Promise<IpvDocument>;
  getCashFlow(from: string, to: string): Promise<CashFlow>;
  remove(id: string): Promise<void>;
}
