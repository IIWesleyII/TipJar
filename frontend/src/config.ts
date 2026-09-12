import { createConfig, http } from 'wagmi'
import { injected } from 'wagmi/connectors'
import { baseSepolia } from 'wagmi/chains'
import { getAddress } from 'viem'
import deployment from './deployment.json' with { type: 'json' }

// VITE_ values are public. Signing is delegated to the user's browser wallet.
export const jarAddress = getAddress(
  import.meta.env.VITE_TIP_JAR_ADDRESS || deployment.address,
)
export const usdcAddress = getAddress(
  import.meta.env.VITE_USDC_ADDRESS || deployment.usdc,
)
export const chain = baseSepolia
export const explorer = baseSepolia.blockExplorers.default.url
export const config = createConfig({
  chains: [baseSepolia],
  connectors: [injected()],
  transports: {
    [baseSepolia.id]: http(
      import.meta.env.VITE_RPC_URL || 'https://sepolia.base.org',
      { retryCount: 1, timeout: 15_000 },
    ),
  },
})
