import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './features/**/*.{js,ts,jsx,tsx,mdx}',
    './lib/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        ink: '#09111f',
        panel: '#121d2e',
        line: '#253047',
        accent: '#4ecdc4',
        gold: '#f2c572',
        gain: '#52d38d',
        loss: '#ff6b6b',
      },
      boxShadow: {
        glow: '0 20px 60px rgba(26, 39, 64, 0.32)',
      },
      backgroundImage: {
        'trading-grid': 'linear-gradient(rgba(255,255,255,0.04) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.04) 1px, transparent 1px)',
      },
      fontFamily: {
        sans: ['"IBM Plex Sans"', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'monospace'],
      },
    },
  },
  plugins: [],
}

export default config
