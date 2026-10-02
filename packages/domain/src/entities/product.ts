export type StockMovementKind =
  | 'purchase'
  | 'ipv_sale'
  | 'ipv_outbound'
  | 'ipv_inbound'
  | 'ipv_close'
  | 'adjustment';

export type StockMovementProps = {
  readonly id: string;
  readonly productId: string;
  readonly kind: StockMovementKind;
  readonly qty: number;
  readonly unitCost: number;
  readonly occurredOn: string;
};

export type StockMovement = Readonly<StockMovementProps>;

export const StockMovement = {
  create(props: StockMovementProps): StockMovement {
    return Object.freeze({ ...props });
  },

  kindLabel(kind: StockMovementKind): string {
    switch (kind) {
      case 'purchase':
        return 'Compra';
      case 'ipv_sale':
        return 'Venta IPV';
      case 'ipv_outbound':
        return 'Salida IPV';
      case 'ipv_inbound':
        return 'Entrada IPV';
      case 'ipv_close':
        return 'Ajuste Al Cierre IPV';
      case 'adjustment':
        return 'Ajuste';
    }
  },
};

export type ProductProps = {
  readonly id: string;
  readonly name: string;
  readonly salePrice: number;
  readonly replenishmentCost: number;
  readonly lastPurchasePrice: number | null;
  readonly minStock: number;
  readonly stockQty: number;
  readonly isActive: boolean;
  readonly countsForTax: boolean;
};

export type Product = Readonly<ProductProps>;

export const Product = {
  create(props: ProductProps): Product {
    return Object.freeze({ ...props });
  },

  isLowStock(product: Product): boolean {
    return product.minStock > 0 && product.stockQty <= product.minStock;
  },
};
