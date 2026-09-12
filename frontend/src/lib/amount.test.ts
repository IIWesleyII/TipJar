import { describe, expect, it } from 'vitest'
import { parseUsdc, usdc } from './amount'

describe('USDC input', () => {
  it('converts decimal amounts to exact six-decimal base units', () => {
    expect(parseUsdc('0.1')).toBe(100000n)
    expect(parseUsdc('.25')).toBe(250000n)
    expect(parseUsdc(' 1.234567 ')).toBe(1234567n)
    expect(parseUsdc('0.000001')).toBe(1n)
  })
  it.each([
    '',
    '0',
    '-1',
    '1e6',
    '0.0000001',
    '1.1234567',
    'NaN',
    '1,000',
    'Infinity',
  ])('rejects invalid or inexact input %s', (input) => {
    expect(parseUsdc(input)).toBeUndefined()
  })
  it('preserves small amounts and separates unavailable data from zero', () => {
    expect(usdc(undefined)).toBe('—')
    expect(usdc(0n)).toBe('0.00')
    expect(usdc(1n)).toBe('0.000001')
    expect(usdc(1234567890n)).toBe('1,234.56789')
  })
})
