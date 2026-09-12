import { expect, test } from '@playwright/test'
import { decodeFunctionData, erc20Abi } from 'viem'
import { tipJarAbi } from '../src/abi/tipJar'
import { setupWallet } from './wallet-fixture'

test('disconnected visitors can read statistics and the mobile layout fits', async ({
  page,
}) => {
  await setupWallet(page)
  await page.goto('/')
  await expect(page.getByTestId('total-tips')).toContainText('0.10')
  await expect(page.getByRole('button', { name: /Send .* tip/ })).toBeDisabled()
  await page.screenshot({ path: 'test-results/desktop.png', fullPage: true })
  await page.setViewportSize({ width: 390, height: 844 })
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true)
  await page.screenshot({ path: 'test-results/mobile.png', fullPage: true })
})

test('approval is exact and a separate click sends the tip and message', async ({
  page,
}) => {
  const state = await setupWallet(page)
  await page.goto('/')
  await page.getByRole('button', { name: /Connect / }).click()
  await page.getByLabel('Leave a message').fill('Thanks from the browser')
  const approve = page.getByRole('button', { name: 'Approve 0.10 USDC' })
  await expect(approve).toBeEnabled()
  await approve.click()
  await expect(
    page.getByText('Approval confirmed', { exact: true }),
  ).toBeVisible()
  expect(state.sent).toHaveLength(1)
  const approval = decodeFunctionData({
    abi: erc20Abi,
    data: state.sent[0].data,
  })
  expect(approval.functionName).toBe('approve')
  expect(approval.args?.[1]).toBe(100000n)
  expect(state.balance).toBe(900000n)

  const tip = page.getByRole('button', { name: 'Send 0.10 USDC tip' })
  await expect(tip).toBeEnabled()
  await tip.click()
  await expect(
    page.getByText('Tip confirmed. Thank you!', { exact: true }),
  ).toBeVisible()
  expect(state.sent).toHaveLength(2)
  const submitted = decodeFunctionData({
    abi: tipJarAbi,
    data: state.sent[1].data,
  })
  expect(submitted.args).toEqual([100000n, 'Thanks from the browser'])
  await expect(page.getByTestId('total-tips')).toContainText('0.20')
  await expect(page.getByTestId('tip-count')).toHaveText(/^2\s*tips$/)
  expect(state.allowance).toBe(0n)
})

test('wrong network blocks transactions until the wallet switches', async ({
  page,
}) => {
  await setupWallet(page, { chainId: 1 })
  await page.goto('/')
  await page.getByRole('button', { name: /Connect / }).click()
  await expect(
    page.getByRole('button', { name: 'Approve 0.10 USDC' }),
  ).toBeDisabled()
  await page.getByRole('button', { name: 'Switch to Base Sepolia' }).click()
  await expect(
    page.getByRole('button', { name: 'Approve 0.10 USDC' }),
  ).toBeEnabled()
})

test('invalid precision and insufficient balance block submission', async ({
  page,
}) => {
  const state = await setupWallet(page)
  await page.goto('/')
  await page.getByRole('button', { name: /Connect / }).click()
  await page.getByLabel('Tip amount', { exact: true }).fill('0.0000001')
  await expect(
    page.getByText('Enter an amount above zero with up to 6 decimal places.'),
  ).toBeVisible()
  await expect(page.locator('.tip-button')).toBeDisabled()
  await page.getByLabel('Tip amount', { exact: true }).fill('10')
  await expect(
    page.getByText('Your USDC balance is lower than this tip.'),
  ).toBeVisible()
  await expect(page.locator('.tip-button')).toBeDisabled()
  expect(state.sent).toHaveLength(0)
})

test('rejected signatures are recoverable and do not send transactions', async ({
  page,
}) => {
  const state = await setupWallet(page, { reject: true })
  await page.goto('/')
  await page.getByRole('button', { name: /Connect / }).click()
  await page.getByRole('button', { name: 'Approve 0.10 USDC' }).click()
  await expect(page.getByRole('alert')).toContainText(
    'Transaction not completed',
  )
  await expect(
    page.getByRole('button', { name: 'Approve 0.10 USDC' }),
  ).toBeEnabled()
  expect(state.sent).toHaveLength(0)
})

test('a reverted receipt is never shown as a successful tip', async ({
  page,
}) => {
  const state = await setupWallet(page, { allowance: 100000n, revert: true })
  await page.goto('/')
  await page.getByRole('button', { name: /Connect / }).click()
  await page.getByRole('button', { name: 'Send 0.10 USDC tip' }).click()
  await expect(page.getByRole('alert')).toContainText('Transaction reverted')
  await expect(page.getByTestId('total-tips')).toContainText('0.10')
  expect(state.balance).toBe(900000n)
})

test('RPC failure is visible instead of displaying invented zero balances', async ({
  page,
}) => {
  await setupWallet(page, { rpcFailure: true })
  await page.goto('/')
  await expect(page.getByRole('alert')).toContainText('couldn’t refresh')
  await expect(page.getByTestId('total-tips')).toContainText('—')
  await expect(page.locator('.tip-button')).toBeDisabled()
})
