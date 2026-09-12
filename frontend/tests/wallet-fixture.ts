import type { Page } from '@playwright/test'
import {
  decodeFunctionData,
  encodeFunctionResult,
  erc20Abi,
  multicall3Abi,
  numberToHex,
  zeroAddress,
  type Address,
  type Hex,
} from 'viem'
import { tipJarAbi } from '../src/abi/tipJar'
import deployment from '../src/deployment.json' with { type: 'json' }

export const tipper = '0x1111111111111111111111111111111111111111'
const owner = '0x2222222222222222222222222222222222222222'
const jar = deployment.address as Address
const token = deployment.usdc as Address

type RpcRequest = { id?: number; method: string; params?: unknown[] }
type Sent = { to: Address; data: Hex; hash: Hex }

// A fake browser wallet and fake public RPC. No keys or transactions leave tests.
export async function setupWallet(
  page: Page,
  options: {
    chainId?: number
    allowance?: bigint
    reject?: boolean
    revert?: boolean
    rpcFailure?: boolean
  } = {},
) {
  const state = {
    connected: false,
    chainId: options.chainId ?? 84532,
    allowance: options.allowance ?? 0n,
    balance: 900000n,
    jarBalance: 0n,
    total: 100000n,
    count: 1n,
    contribution: 100000n,
    sent: [] as Sent[],
    applied: new Set<string>(),
    receiptReads: 0,
  }

  function contractCall(to: string, data: Hex): Hex {
    if (to.toLowerCase() === jar.toLowerCase()) {
      const decoded = decodeFunctionData({ abi: tipJarAbi, data })
      const values: Record<string, unknown> = {
        totalTips: state.total,
        tipCount: state.count,
        largestTip: 100000n,
        largestTipper: tipper,
        owner,
        withdrawalAddress: owner,
        usdc: token,
        tippedBy: state.contribution,
      }
      return encodeFunctionResult({
        abi: tipJarAbi,
        functionName: decoded.functionName,
        result: values[decoded.functionName],
      } as Parameters<typeof encodeFunctionResult>[0])
    }
    if (to.toLowerCase() !== token.toLowerCase()) {
      const decoded = decodeFunctionData({ abi: multicall3Abi, data })
      if (decoded.functionName !== 'getEthBalance') {
        throw new Error('Unsupported multicall read')
      }
      return encodeFunctionResult({
        abi: multicall3Abi,
        functionName: 'getEthBalance',
        result: 1_000_000_000_000_000n,
      })
    }
    const decoded = decodeFunctionData({ abi: erc20Abi, data })
    const result =
      decoded.functionName === 'balanceOf'
        ? String(decoded.args?.[0]).toLowerCase() === jar.toLowerCase()
          ? state.jarBalance
          : state.balance
        : decoded.functionName === 'allowance'
          ? state.allowance
          : 6
    return encodeFunctionResult({
      abi: erc20Abi,
      functionName: decoded.functionName,
      result,
    } as Parameters<typeof encodeFunctionResult>[0])
  }

  function applyTransaction(tx: Sent) {
    if (options.revert || state.applied.has(tx.hash)) return
    state.applied.add(tx.hash)
    if (tx.to.toLowerCase() === token.toLowerCase()) {
      const decoded = decodeFunctionData({ abi: erc20Abi, data: tx.data })
      if (decoded.functionName === 'approve') state.allowance = decoded.args[1]
    } else {
      const decoded = decodeFunctionData({ abi: tipJarAbi, data: tx.data })
      if (decoded.functionName === 'tip') {
        const amount = decoded.args[0]
        state.balance -= amount
        state.allowance -= amount
        state.jarBalance += amount
        state.total += amount
        state.count++
        state.contribution += amount
      }
    }
  }

  function publicRpc(request: RpcRequest): unknown {
    const params = request.params ?? []
    if (request.method === 'eth_chainId') return '0x14a34'
    if (request.method === 'eth_blockNumber') return '0x100'
    if (request.method === 'eth_getBalance') return '0x38d7ea4c68000'
    if (request.method === 'eth_getCode') return '0x'
    if (request.method === 'eth_call') {
      const { to, data } = params[0] as { to: string; data: Hex }
      if (
        to.toLowerCase() === jar.toLowerCase() ||
        to.toLowerCase() === token.toLowerCase()
      )
        return contractCall(to, data)
      const decoded = decodeFunctionData({ abi: multicall3Abi, data })
      if (decoded.functionName !== 'aggregate3')
        throw new Error('Unsupported multicall')
      return encodeFunctionResult({
        abi: multicall3Abi,
        functionName: 'aggregate3',
        result: decoded.args[0].map((call) => ({
          success: true,
          returnData: contractCall(call.target, call.callData),
        })),
      })
    }
    if (request.method === 'eth_getTransactionReceipt') {
      const tx = state.sent.find((sent) => sent.hash === params[0])
      if (!tx) return null
      state.receiptReads++
      applyTransaction(tx)
      return {
        transactionHash: tx.hash,
        transactionIndex: '0x0',
        blockHash: `0x${'ab'.repeat(32)}`,
        blockNumber: '0x100',
        from: tipper,
        to: tx.to,
        cumulativeGasUsed: '0x5208',
        gasUsed: '0x5208',
        contractAddress: null,
        logs: [],
        logsBloom: `0x${'00'.repeat(256)}`,
        status: options.revert ? '0x0' : '0x1',
        effectiveGasPrice: '0x1',
        type: '0x2',
      }
    }
    if (request.method === 'eth_getTransactionByHash') {
      const tx = state.sent.find((sent) => sent.hash === params[0])
      return tx
        ? {
            hash: tx.hash,
            from: tipper,
            to: tx.to,
            input: tx.data,
            nonce: '0x0',
            value: '0x0',
            gas: '0x100000',
            gasPrice: '0x1',
            type: '0x2',
            chainId: '0x14a34',
            blockHash: `0x${'ab'.repeat(32)}`,
            blockNumber: '0x100',
            transactionIndex: '0x0',
            maxFeePerGas: '0x1',
            maxPriorityFeePerGas: '0x1',
            v: '0x1',
            r: '0x1',
            s: '0x1',
          }
        : null
    }
    throw new Error(`Unhandled public RPC method ${request.method}`)
  }

  await page.route('https://sepolia.base.org/**', async (route) => {
    if (options.rpcFailure) return route.abort('failed')
    const body = route.request().postDataJSON() as RpcRequest | RpcRequest[]
    const respond = (request: RpcRequest) => ({
      jsonrpc: '2.0',
      id: request.id,
      result: publicRpc(request),
    })
    await route.fulfill({
      json: Array.isArray(body) ? body.map(respond) : respond(body),
    })
  })
  await page.exposeFunction('__walletRpc', async (request: RpcRequest) => {
    const params = request.params ?? []
    switch (request.method) {
      case 'eth_requestAccounts':
        state.connected = true
        return { result: [tipper] }
      case 'eth_accounts':
        return { result: state.connected ? [tipper] : [] }
      case 'eth_chainId':
        return { result: numberToHex(state.chainId) }
      case 'wallet_switchEthereumChain': {
        state.chainId = Number((params[0] as { chainId: string }).chainId)
        await page.evaluate((id) => {
          ;(
            window as unknown as {
              ethereum: { emit: (event: string, value: unknown) => void }
            }
          ).ethereum.emit('chainChanged', id)
        }, numberToHex(state.chainId))
        return { result: null }
      }
      case 'wallet_requestPermissions':
        return { result: [{ parentCapability: 'eth_accounts' }] }
      case 'wallet_revokePermissions':
        state.connected = false
        return { result: null }
      case 'wallet_getCapabilities':
        return { result: {} }
      case 'eth_sendTransaction': {
        if (options.reject)
          return {
            error: { code: 4001, message: 'User rejected the request.' },
          }
        const tx = params[0] as { to: Address; data: Hex }
        const hash =
          `0x${(state.sent.length + 1).toString(16).padStart(64, '0')}` as Hex
        state.sent.push({ ...tx, hash })
        return { result: hash }
      }
      default:
        return { result: publicRpc(request) }
    }
  })
  await page.addInitScript(() => {
    const listeners = new Map<string, Set<(value: unknown) => void>>()
    const host = window as unknown as {
      __walletRpc: (args: unknown) => Promise<{
        result?: unknown
        error?: { code: number; message: string }
      }>
      ethereum: unknown
    }
    host.ethereum = {
      isMetaMask: true,
      request: async (args: unknown) => {
        const response = await host.__walletRpc(args)
        if (response.error)
          throw Object.assign(new Error(response.error.message), {
            code: response.error.code,
          })
        return response.result
      },
      on: (name: string, handler: (value: unknown) => void) => {
        if (!listeners.has(name)) listeners.set(name, new Set())
        listeners.get(name)!.add(handler)
      },
      removeListener: (name: string, handler: (value: unknown) => void) =>
        listeners.get(name)?.delete(handler),
      emit: (name: string, value: unknown) =>
        listeners.get(name)?.forEach((handler) => handler(value)),
    }
  })
  return state
}
