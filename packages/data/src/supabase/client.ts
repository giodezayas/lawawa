import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from './database.types';

export type AppSupabaseClient = SupabaseClient<Database>;

export type SupabaseConfig = {
  url: string;
  anonKey: string;
};

export type NativeAuthStorage = {
  getItem: (key: string) => Promise<string | null>;
  setItem: (key: string, value: string) => Promise<void>;
  removeItem: (key: string) => Promise<void>;
};

export function isSupabaseConfigured(config: Partial<SupabaseConfig>): config is SupabaseConfig {
  return Boolean(config.url?.startsWith('https://') && config.anonKey && config.anonKey.length > 20);
}

export function createBrowserSupabaseClient(config: SupabaseConfig): AppSupabaseClient {
  return createClient<Database>(config.url, config.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
}

export function createNativeSupabaseClient(
  config: SupabaseConfig,
  storage: NativeAuthStorage,
): AppSupabaseClient {
  return createClient<Database>(config.url, config.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
      storage,
    },
  });
}
