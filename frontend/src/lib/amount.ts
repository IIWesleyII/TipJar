import { BaseError, formatUnits, parseUnits } from 'viem'

// Validate before parseUnits: extra decimal places must not be rounded silently.
export function parseUsdc(input: string): bigint | undefined {
  const value = input.trim()
  if (value.length > 30 || !/^(?:\d+(?:\.\d{0,6})?|\.\d{1,6})$/.test(value)) {
    return undefined
  }
  const amount = parseUnits(value, 6)
  return amount > 0n ? amount : undefined
}

export function usdc(value: bigint | undefined) {
  if (value === undefined) return '—'
  const formatted = formatUnits(value, 6)
  const [whole, fraction = ''] = formatted.split('.')
  return `${whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}.${fraction.padEnd(2, '0')}`
}

export function shortAddress(address: string) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`
}

export function errorMessage(error: unknown): string {
  if (error instanceof BaseError) return error.shortMessage
  return error instanceof Error
    ? error.message
    : 'Something went wrong. Try again.'
}
