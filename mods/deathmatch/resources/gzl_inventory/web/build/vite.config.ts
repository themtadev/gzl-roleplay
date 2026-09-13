import { copyFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), {
    name: 'publish-mta-assets',
    writeBundle() {
      for (const [from, to] of [
        ['ui.html', 'index.html'],
        ['assets/index-323a8bdd.js', 'assets/index-323a8bdd.js'],
        ['assets/index-ae037b2a.css', 'assets/index-ae037b2a.css'],
      ]) copyFileSync(resolve(__dirname, 'build_output', from), resolve(__dirname, to));
    },
  }],
  base: './',
  publicDir: false,
  build: {
    outDir: 'build_output',
    emptyOutDir: false,
    target: 'esnext',
    rollupOptions: {
      input: resolve(__dirname, 'ui.html'),
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
