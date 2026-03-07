import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// Production-specific configuration
// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  base: './', // Use relative paths for Cloud Storage
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@services': path.resolve(__dirname, './src/services'),
      '@pages': path.resolve(__dirname, './src/pages'),
      '@components': path.resolve(__dirname, './src/components'),
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    minify: 'terser',
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
          mui: ['@mui/material', '@mui/icons-material'],
        },
      },
    },
  },
})
