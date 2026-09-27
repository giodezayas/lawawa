export type DashboardStatsProps = {
  readonly productCount: number;
  readonly lowStockCount: number;
  readonly stockUnits: number;
  readonly ipvTodayCount: number;
  readonly ipvTodayStatus: string;
  readonly saleToday: number;
  readonly profitToday: number;
  readonly saleMonth: number;
  readonly profitMonth: number;
  readonly purchaseToday: number;
  readonly activeUserCount: number;
};

export type DashboardStats = Readonly<DashboardStatsProps>;

export const DashboardStats = {
  create(props: DashboardStatsProps): DashboardStats {
    return Object.freeze({ ...props });
  },

  ipvTodayLabel(status: string): string {
    if (status === 'closed') {
      return 'Cerrado';
    }
    if (status === 'open') {
      return 'Abierto';
    }
    return 'Sin IPV';
  },
};
