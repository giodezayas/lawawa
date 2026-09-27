import path from 'node:path';
import { fileURLToPath } from 'node:url';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

const rootDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(rootDir, 'src'),
      '@wawa/domain': path.resolve(rootDir, '../../packages/domain/src/index.ts'),
      '@wawa/data': path.resolve(rootDir, '../../packages/data/src/index.ts'),
      '@wawa/theme': path.resolve(rootDir, '../../packages/theme/src/index.ts'),
    },
  },
  optimizeDeps: {
    exclude: ['@wawa/domain', '@wawa/data', '@wawa/theme'],
  },
  server: {
    port: 5173,
    fs: {
      allow: [path.resolve(rootDir, '../..')],
    },
  },
});
