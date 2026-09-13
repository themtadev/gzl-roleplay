import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: './',
  publicDir: false,
  build: {
    outDir: '.',
    emptyOutDir: false,
    target: 'esnext',
    rollupOptions: {
      output: {
        entryFileNames: 'assets/index-323a8bdd.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: (assetInfo) => {
          if (assetInfo.name && assetInfo.name.endsWith('.css')) {
            return 'assets/index-ae037b2a.css';
          }
          return 'assets/[name].[ext]';
        },
      },
    },
  },
  define: {
    'process.env': {},
  },
  esbuild: {
    logOverride: { 'this-is-undefined-in-esm': 'silent' },
  },
});
