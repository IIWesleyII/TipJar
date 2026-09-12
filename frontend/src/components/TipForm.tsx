import { useState } from 'react'
import { useConnection } from 'wagmi'
import { chain, explorer } from '../config'
import { parseUsdc, usdc } from '../lib/amount'
import { useTipTransaction } from '../hooks/useTipTransaction'

type Props = {
  balance?: bigint
  allowance?: bigint
  gas?: bigint
  ready: boolean
}

export function TipForm({ balance, allowance, gas, ready }: Props) {
  const [input, setInput] = useState('0.1')
  const [message, setMessage] = useState('')
  const { isConnected, chainId } = useConnection()
  const { transaction, send, busy } = useTipTransaction()
  const amount = parseUsdc(input)
  const needsApproval =
    amount !== undefined && allowance !== undefined && allowance < amount
  const insufficientBalance =
    amount !== undefined && balance !== undefined && amount > balance
  const canAct =
    isConnected &&
    chainId === chain.id &&
    ready &&
    gas !== undefined &&
    gas > 0n &&
    amount !== undefined &&
    allowance !== undefined &&
    balance !== undefined &&
    !insufficientBalance &&
    !busy
  const explanation = !isConnected
    ? 'Connect your wallet to get started.'
    : chainId !== chain.id
      ? 'Switch your wallet to Base Sepolia.'
      : !amount
        ? 'Enter an amount above zero with up to 6 decimal places.'
        : insufficientBalance
          ? 'Your USDC balance is lower than this tip.'
          : gas === 0n
            ? 'You need Base Sepolia ETH to pay transaction gas.'
            : !ready ||
                allowance === undefined ||
                balance === undefined ||
                gas === undefined
              ? 'Waiting for current wallet and contract balances…'
              : needsApproval
                ? 'First, give this jar permission to spend exactly your tip amount.'
                : 'Your allowance covers this amount. You’re ready to send your tip.'

  return (
    <section className="tip-panel" aria-labelledby="tip-heading">
      <div className="section-heading">
        <h2 id="tip-heading">Send a little thanks</h2>
        <span className="coin">$</span>
      </div>
      <p className="muted">A small gesture. A lasting thank you.</p>
      <label htmlFor="amount">Tip amount</label>
      <div className={`amount-input ${input && !amount ? 'invalid' : ''}`}>
        <input
          id="amount"
          inputMode="decimal"
          autoComplete="off"
          value={input}
          disabled={busy}
          onChange={(event) => setInput(event.target.value)}
          aria-describedby="tip-help"
          aria-invalid={Boolean(input && !amount)}
        />
        <span>USDC</span>
      </div>
      <div className="presets" aria-label="Suggested tip amounts">
        {['0.1', '0.25', '0.5'].map((value) => (
          <button
            type="button"
            key={value}
            disabled={busy}
            aria-pressed={input === value}
            onClick={() => setInput(value)}
          >
            {value} USDC
          </button>
        ))}
      </div>
      <label htmlFor="message">
        Leave a message <span className="muted normal">(optional)</span>
      </label>
      <textarea
        id="message"
        rows={3}
        placeholder="Thanks for sharing what you do."
        value={message}
        disabled={busy}
        onChange={(event) => setMessage(event.target.value)}
      />
      <p className="small muted">Your message will be public on-chain.</p>
      <div className="approval-flow">
        <div
          className={`flow-step ${!needsApproval && allowance !== undefined && amount ? 'complete' : ''}`}
        >
          <span className="step-number">1</span>
          <div>
            <strong>Approve USDC</strong>
            <p>Grant spending permission</p>
          </div>
          <span className="step-status">
            {!needsApproval && allowance !== undefined && amount
              ? 'Ready'
              : 'First'}
          </span>
        </div>
        <div className="flow-step">
          <span className="step-number">2</span>
          <div>
            <strong>Send your tip</strong>
            <p>Move USDC into the jar</p>
          </div>
        </div>
      </div>
      <p id="tip-help" className="small form-help">
        {explanation}
      </p>
      <button
        className="button primary tip-button"
        disabled={!canAct}
        onClick={() => {
          if (amount)
            void send(needsApproval ? 'approve' : 'tip', amount, message)
        }}
      >
        {busy
          ? 'Transaction in progress…'
          : needsApproval
            ? `Approve ${usdc(amount)} USDC`
            : `Send ${usdc(amount)} USDC tip`}
        {!busy && <span aria-hidden="true">↗</span>}
      </button>
      <p className="small muted center">
        USDC is the tip. Test ETH pays the gas.
      </p>
      {transaction.phase !== 'idle' && (
        <div
          className={`notice transaction ${transaction.phase}`}
          role={transaction.phase === 'error' ? 'alert' : 'status'}
          aria-live="polite"
        >
          <strong>
            {transaction.phase === 'signing'
              ? 'Waiting for wallet signature'
              : transaction.phase === 'confirming'
                ? 'Transaction submitted — waiting for confirmation'
                : transaction.phase === 'error'
                  ? 'Transaction not completed'
                  : transaction.action === 'approve'
                    ? 'Approval confirmed'
                    : 'Tip confirmed. Thank you!'}
          </strong>
          {transaction.phase === 'confirmed' &&
            transaction.action === 'approve' && (
              <p>No USDC moved yet. Press Send to submit your tip.</p>
            )}
          {transaction.error && <p>{transaction.error}</p>}
          {transaction.hash && (
            <a
              href={`${explorer}/tx/${transaction.hash}`}
              target="_blank"
              rel="noreferrer"
            >
              View transaction ↗
            </a>
          )}
        </div>
      )}
    </section>
  )
}
