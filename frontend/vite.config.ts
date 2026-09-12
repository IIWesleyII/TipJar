import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    // WSL file events can miss edits made by a Windows editor.
    watch: { usePolling: Boolean(process.env.WSL_DISTRO_NAME) },
  },
})
