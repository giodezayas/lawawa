export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type AppRole = 'admin' | 'manager' | 'trabajador';
export type IpvShift = 'manana' | 'noche';
export type IpvStatus = 'open' | 'closed';

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          email: string;
          username: string;
          full_name: string;
          role: AppRole;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          email: string;
          username: string;
          full_name?: string;
          role?: AppRole;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          email?: string;
          username?: string;
          full_name?: string;
          role?: AppRole;
          is_active?: boolean;
          updated_at?: string;
        };
        Relationships: [];
      };
      business_settings: {
        Row: {
          id: string;
          name: string;
          timezone: string;
          tax_rate: string;
          billing_start_day: number;
          billing_period_from: string;
          billing_period_to: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name?: string;
          timezone?: string;
          tax_rate?: number | string;
          billing_start_day?: number;
          billing_period_from?: string;
          billing_period_to?: string;
          updated_at?: string;
        };
        Update: {
          name?: string;
          timezone?: string;
          tax_rate?: number | string;
          billing_start_day?: number;
          billing_period_from?: string;
          billing_period_to?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      products: {
        Row: {
          id: string;
          name: string;
          sale_price: string;
          purchase_price: string;
          replenishment_cost: string;
          min_stock: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          name: string;
          sale_price?: number | string;
          purchase_price?: number | string;
          replenishment_cost?: number | string;
          min_stock?: number | string;
          is_active?: boolean;
        };
        Update: {
          name?: string;
          sale_price?: number | string;
          purchase_price?: number | string;
          replenishment_cost?: number | string;
          min_stock?: number | string;
          is_active?: boolean;
          updated_at?: string;
        };
        Relationships: [];
      };
      purchase_documents: {
        Row: {
          id: string;
          purchased_on: string;
          payment_method: string;
          created_by: string;
          created_at: string;
        };
        Insert: {
          purchased_on: string;
          payment_method?: string;
          created_by: string;
        };
        Update: {
          purchased_on?: string;
          payment_method?: string;
        };
        Relationships: [];
      };
      purchase_lines: {
        Row: {
          id: string;
          purchase_id: string;
          product_id: string;
          qty: string;
          unit_cost: string;
          created_at: string;
        };
        Insert: {
          purchase_id: string;
          product_id: string;
          qty: number | string;
          unit_cost: number | string;
        };
        Update: {
          qty?: number | string;
          unit_cost?: number | string;
        };
        Relationships: [];
      };
      stock_movements: {
        Row: {
          id: string;
          product_id: string;
          kind: string;
          qty: string;
          unit_cost: string;
          occurred_on: string;
          purchase_line_id: string | null;
          ipv_line_id: string | null;
          created_at: string;
        };
        Insert: {
          product_id: string;
          kind: string;
          qty: number | string;
          unit_cost?: number | string;
          occurred_on: string;
          purchase_line_id?: string | null;
          ipv_line_id?: string | null;
        };
        Update: Record<string, never>;
        Relationships: [];
      };
      ipv_documents: {
        Row: {
          id: string;
          work_date: string;
          shift: IpvShift;
          status: IpvStatus;
          created_by: string;
          closed_by: string | null;
          closed_at: string | null;
          cash_collected: string;
          transfer_collected: string;
          transfer_p_collected: string;
          transfer_f_collected: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          work_date: string;
          shift?: IpvShift;
          status?: IpvStatus;
          created_by: string;
          closed_by?: string | null;
          closed_at?: string | null;
          cash_collected?: number | string;
          transfer_collected?: number | string;
          transfer_p_collected?: number | string;
          transfer_f_collected?: number | string;
        };
        Update: {
          status?: IpvStatus;
          closed_by?: string | null;
          closed_at?: string | null;
          cash_collected?: number | string;
          transfer_collected?: number | string;
          transfer_p_collected?: number | string;
          transfer_f_collected?: number | string;
        };
        Relationships: [];
      };
      ipv_lines: {
        Row: {
          id: string;
          ipv_id: string;
          product_id: string;
          product_name: string;
          opening_qty: string;
          inbound_qty: string;
          outbound_qty: string;
          closing_qty: string;
          sale_price: string;
          replenishment_cost: string;
          sold_qty: string;
          sale_total: string;
          gross_profit: string;
          inbound_adds_stock: boolean;
          sort_order: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          ipv_id: string;
          product_id: string;
          product_name: string;
          opening_qty?: number | string;
          inbound_qty?: number | string;
          outbound_qty?: number | string;
          sold_qty?: number | string;
          sale_price?: number | string;
          replenishment_cost?: number | string;
          inbound_adds_stock?: boolean;
          sort_order?: number;
        };
        Update: {
          opening_qty?: number | string;
          inbound_qty?: number | string;
          outbound_qty?: number | string;
          sold_qty?: number | string;
          sale_price?: number | string;
          replenishment_cost?: number | string;
          inbound_adds_stock?: boolean;
          sort_order?: number;
        };
        Relationships: [];
      };
      expense_categories: {
        Row: {
          id: string;
          name: string;
          kind: string;
          cadence: string;
          default_amount: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          name: string;
          kind: string;
          cadence: string;
          default_amount?: number | string;
          is_active?: boolean;
        };
        Update: {
          name?: string;
          kind?: string;
          cadence?: string;
          default_amount?: number | string;
          is_active?: boolean;
        };
        Relationships: [];
      };
      expense_entries: {
        Row: {
          id: string;
          category_id: string | null;
          name: string;
          occurred_on: string;
          cadence: string;
          amount: string;
          notes: string;
          created_by: string;
          created_at: string;
        };
        Insert: {
          category_id?: string | null;
          name: string;
          occurred_on: string;
          cadence?: string;
          amount: number | string;
          notes?: string;
          created_by: string;
        };
        Update: {
          category_id?: string | null;
          name?: string;
          occurred_on?: string;
          cadence?: string;
          amount?: number | string;
          notes?: string;
        };
        Relationships: [];
      };
      cash_moves: {
        Row: {
          id: string;
          occurred_on: string;
          kind: string;
          card: string;
          amount: string;
          notes: string;
          created_by: string;
          created_at: string;
        };
        Insert: {
          occurred_on: string;
          kind: string;
          card?: string;
          amount: number | string;
          notes?: string;
          created_by: string;
        };
        Update: {
          occurred_on?: string;
          kind?: string;
          card?: string;
          amount?: number | string;
          notes?: string;
        };
        Relationships: [];
      };
      card_opening: {
        Row: {
          id: boolean;
          as_of: string;
          p_amount: string;
          f_amount: string;
          notes: string;
          updated_by: string | null;
          updated_at: string;
        };
        Insert: {
          id?: boolean;
          as_of: string;
          p_amount?: number | string;
          f_amount?: number | string;
          notes?: string;
          updated_by?: string | null;
          updated_at?: string;
        };
        Update: {
          as_of?: string;
          p_amount?: number | string;
          f_amount?: number | string;
          notes?: string;
          updated_by?: string | null;
          updated_at?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      product_catalog: {
        Row: {
          id: string;
          name: string;
          sale_price: string;
          replenishment_cost: string;
          min_stock: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
          stock_qty: string;
          last_purchase_price: string | null;
          average_cost: string;
        };
        Relationships: [];
      };
      dashboard_stats: {
        Row: {
          product_count: number;
          low_stock_count: number;
          stock_units: string;
          ipv_today_count: number;
          ipv_today_status: string;
          sale_today: string;
          profit_today: string;
          sale_month: string;
          profit_month: string;
          purchase_today: string;
          active_user_count: number;
        };
        Relationships: [];
      };
    };
    Functions: {
      close_ipv: {
        Args: { p_id: string };
        Returns: undefined;
      };
      adjust_product_stock: {
        Args: { p_id: string; p_qty: number };
        Returns: undefined;
      };
      delete_ipv: {
        Args: { p_id: string };
        Returns: undefined;
      };
      delete_product: {
        Args: { p_id: string };
        Returns: undefined;
      };
      invite_staff: {
        Args: { p_username: string; p_password: string; p_full_name: string; p_role: AppRole };
        Returns: string;
      };
      resolve_login: {
        Args: { p_login: string };
        Returns: string | null;
      };
      update_staff: {
        Args: {
          p_id: string;
          p_full_name: string;
          p_role: AppRole;
          p_is_active: boolean;
          p_password?: string | null;
        };
        Returns: undefined;
      };
      delete_staff: {
        Args: { p_id: string };
        Returns: undefined;
      };
      period_report: {
        Args: { p_from: string; p_to: string };
        Returns: Json;
      };
      close_billing_period: {
        Args: { p_from: string; p_to: string };
        Returns: undefined;
      };
      cash_flow_report: {
        Args: { p_from: string; p_to: string };
        Returns: Json;
      };
    };
    Enums: {
      app_role: AppRole;
      ipv_shift: IpvShift;
      ipv_status: IpvStatus;
    };
    CompositeTypes: Record<string, never>;
  };
};
