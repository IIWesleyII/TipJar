import { useBalance, useConnection, useReadContracts } from 'wagmi'
import { erc20Abi, zeroAddress } from 'viem'
import { tipJarAbi } from '../abi/tipJar'
import { chain, jarAddress, usdcAddress } from '../config'

export function useJarReads() {
  const { address } = useConnection()
  const jar = {
    address: jarAddress,
    abi: tipJarAbi,
    chainId: chain.id,
  } as const
  // Shared statistics can be read even when no wallet is connected.
  const stats = useReadContracts({
    allowFailure: false,
    contracts: [
      { ...jar, functionName: 'totalTips' },
      { ...jar, functionName: 'tipCount' },
      { ...jar, functionName: 'largestTip' },
      { ...jar, functionName: 'largestTipper' },
      { ...jar, functionName: 'owner' },
      { ...jar, functionName: 'withdrawalAddress' },
      { ...jar, functionName: 'usdc' },
      {
        address: usdcAddress,
        abi: erc20Abi,
        chainId: chain.id,
        functionName: 'balanceOf',
        args: [jarAddress],
      },
    ],
    query: { refetchInterval: 12_000 },
  })
  const wallet = useReadContracts({
    allowFailure: false,
    contracts: [
      {
        address: usdcAddress,
        abi: erc20Abi,
        chainId: chain.id,
        functionName: 'balanceOf',
        args: [address ?? zeroAddress],
      },
      {
        address: usdcAddress,
        abi: erc20Abi,
        chainId: chain.id,
        functionName: 'allowance',
        args: [address ?? zeroAddress, jarAddress],
      },
      { ...jar, functionName: 'tippedBy', args: [address ?? zeroAddress] },
    ],
    query: { enabled: Boolean(address), refetchInterval: 12_000 },
  })
  const gas = useBalance({
    address,
    chainId: chain.id,
    query: { enabled: Boolean(address), refetchInterval: 12_000 },
  })
  return { stats, wallet, gas }
}
