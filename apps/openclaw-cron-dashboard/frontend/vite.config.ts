import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/apps/openclaw-cron/',
  server: {
    port: 4174,
    proxy: {
      '/api/openclaw/cron': 'http://127.0.0.1:18813'
    }
  },
  build: {
    outDir: 'dist'
  }
})
