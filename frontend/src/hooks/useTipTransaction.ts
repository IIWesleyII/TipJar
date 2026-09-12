import { useRef, useState } from 'react'
import { useConnection, usePublicClient, useWriteContract } from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'
import { erc20Abi, type Hash } from 'viem'
import { chain, jarAddress, usdcAddress } from '../config'
import { tipJarAbi } from '../abi/tipJar'
import { errorMessage } from '../lib/amount'

type Action = 'approve' | 'tip'
type Phase = 'idle' | 'signing' | 'confirming' | 'confirmed' | 'error'
export type TransactionState = {
  phase: Phase
  action?: Action
  hash?: Hash
  error?: string
}

export function useTipTransaction() {
  const [transaction, setTransaction] = useState<TransactionState>({
    phase: 'idle',
  })
  const lock = useRef(false)
  const { address, chainId } = useConnection()
  const publicClient = usePublicClient({ chainId: chain.id })
  const writer = useWriteContract()
  const queries = useQueryClient()

  async function send(action: Action, amount: bigint, message: string) {
    if (lock.current || !address || chainId !== chain.id || !publicClient)
      return
    lock.current = true
    let hash: Hash | undefined
    let cancelled = false
    setTransaction({ phase: 'signing', action })
    try {
      // These are deliberately separate transactions. Approval never sends a tip.
      hash =
        action === 'approve'
          ? await writer.mutateAsync({
              address: usdcAddress,
              abi: erc20Abi,
              functionName: 'approve',
              args: [jarAddress, amount],
              account: address,
              chainId: chain.id,
            })
          : await writer.mutateAsync({
              address: jarAddress,
              abi: tipJarAbi,
              functionName: 'tip',
              args: [amount, message],
              account: address,
              chainId: chain.id,
            })
      setTransaction({ phase: 'confirming', action, hash })
      const receipt = await publicClient.waitForTransactionReceipt({
        hash,
        confirmations: 1,
        pollingInterval: 1_000,
        onReplaced(replacement) {
          hash = replacement.transaction.hash
          cancelled = replacement.reason !== 'repriced'
          setTransaction({ phase: 'confirming', action, hash })
        },
      })
      if (cancelled)
        throw new Error(
          'Transaction was cancelled or replaced. Check your wallet before retrying.',
        )
      if (receipt.status !== 'success')
        throw new Error(
          'Transaction reverted. No tip or approval was completed.',
        )
      setTransaction({
        phase: 'confirmed',
        action,
        hash: receipt.transactionHash,
      })
      await queries.invalidateQueries()
    } catch (error) {
      setTransaction({
        phase: 'error',
        action,
        hash,
        error: errorMessage(error),
      })
    } finally {
      lock.current = false
    }
  }

  return {
    transaction,
    send,
    busy: transaction.phase === 'signing' || transaction.phase === 'confirming',
  }
}
