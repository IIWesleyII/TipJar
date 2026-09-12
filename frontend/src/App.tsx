import { useConnection } from 'wagmi'
import { zeroAddress } from 'viem'
import { useQueryClient } from '@tanstack/react-query'
import { useJarReads } from './hooks/useJarReads'
import { WalletPanel } from './components/WalletPanel'
import { TipForm } from './components/TipForm'
import { explorer, jarAddress, usdcAddress } from './config'
import { shortAddress, usdc } from './lib/amount'

export default function App() {
  const { address } = useConnection()
  const { stats, wallet, gas } = useJarReads()
  const queries = useQueryClient()
  const data = stats.data
  const personal = address ? wallet.data : undefined
  const tokenMatches = data?.[6].toLowerCase() === usdcAddress.toLowerCase()
  const readError =
    stats.isError || (Boolean(address) && (wallet.isError || gas.isError))

  return (
    <div className="site-shell">
      <header className="topbar">
        <a className="brand" href="#" aria-label="TipJar home">
          <svg
            width="30"
            height="34"
            viewBox="0 0 30 34"
            fill="none"
            aria-hidden="true"
          >
            <path
              d="M8 3h14M7 7h16v4l3 5v10a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5V16l3-5V7Z"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
            />
            <path
              d="M15 15v10m3-8h-4a2 2 0 0 0 0 4h2a2 2 0 0 1 0 4h-4"
              stroke="currentColor"
              strokeWidth="1.7"
              strokeLinecap="round"
            />
          </svg>
          <span>
            TipJar<span className="brand-dot">.</span>
          </span>
        </a>
        <div className="topbar-right">
          <span className="network-chip">
            <span />
            Base Sepolia
          </span>
          <span className="small muted testnet-label">Testnet edition</span>
        </div>
      </header>

      <main>
        <section className="intro">
          <p className="eyebrow">SMALL GESTURES, REAL APPRECIATION</p>
          <h1>
            A little thanks
            <br />
            goes a <em>long way.</em>
          </h1>
          <p className="intro-copy">
            Support good work, one USDC tip at a time.
            <br />
            Connect your wallet. Leave a note. Make someone’s day.
          </p>
          <div className="intro-note">
            <span className="tiny-star">✳</span> Made for learning. Powered by
            test USDC.
          </div>
        </section>

        {readError && (
          <div className="notice warning" role="alert">
            <strong>We couldn’t refresh the on-chain balances.</strong>
            <p>
              Check your connection and try again. Transactions are paused until
              the data is available.
            </p>
            <button
              className="text-button"
              onClick={() => void queries.invalidateQueries()}
            >
              Retry reads
            </button>
          </div>
        )}
        {data && !tokenMatches && (
          <div className="notice warning" role="alert">
            The jar’s token doesn’t match this app’s USDC configuration. Tipping
            is disabled.
          </div>
        )}

        <div className="dashboard">
          <div className="overview">
            <section className="jar-card" aria-labelledby="jar-heading">
              <div className="section-heading">
                <h2 id="jar-heading">A little jar of appreciation</h2>
                <span className="live-label">
                  <span />
                  On-chain
                </span>
              </div>
              <p className="balance-label">Currently in the jar</p>
              <p className="jar-balance" data-testid="jar-balance">
                {usdc(data?.[7])}
                <span>USDC</span>
              </p>
              <p className="jar-caption">Every tip starts with a thank you.</p>
              <div className="jar-stats">
                <div>
                  <span>Total tipped, all time</span>
                  <strong data-testid="total-tips">
                    {usdc(data?.[0])} <small>USDC</small>
                  </strong>
                </div>
                <div>
                  <span>Little acts of thanks</span>
                  <strong data-testid="tip-count">
                    {data?.[1].toString() ?? '—'}{' '}
                    <small>{data?.[1] === 1n ? 'tip' : 'tips'}</small>
                  </strong>
                </div>
              </div>
            </section>
            <section className="record-card" aria-labelledby="record-heading">
              <div className="record-icon" aria-hidden="true">
                ✳
              </div>
              <div>
                <h2 id="record-heading">Biggest thank you</h2>
                <p className="record-amount">
                  {usdc(data?.[2])} <span>USDC</span>
                </p>
                <p className="small muted">
                  {!data ? (
                    'Loading record…'
                  ) : data[3] === zeroAddress ? (
                    'Your tip could be the first.'
                  ) : (
                    <>
                      From{' '}
                      <a
                        href={`${explorer}/address/${data[3]}`}
                        target="_blank"
                        rel="noreferrer"
                        title={data[3]}
                      >
                        {shortAddress(data[3])} ↗
                      </a>
                    </>
                  )}
                </p>
              </div>
            </section>
            <WalletPanel
              balance={personal?.[0]}
              allowance={personal?.[1]}
              gas={gas.data?.value}
            />
            {address && (
              <div className="your-contribution">
                <span>Your lifetime contribution</span>
                <strong>{usdc(personal?.[2])} USDC</strong>
              </div>
            )}
          </div>
          <TipForm
            balance={personal?.[0]}
            allowance={personal?.[1]}
            gas={gas.data?.value}
            ready={Boolean(data && personal && tokenMatches && !readError)}
          />
        </div>

        <section className="how-it-works" aria-label="How tipping works">
          <div>
            <span>01</span>
            <h3>Connect</h3>
            <p>Use a wallet with Base Sepolia ETH and test USDC.</p>
          </div>
          <div>
            <span>02</span>
            <h3>Approve</h3>
            <p>Give the jar permission for exactly the amount you choose.</p>
          </div>
          <div>
            <span>03</span>
            <h3>Send a little thanks</h3>
            <p>Confirm your tip. Your message becomes part of the story.</p>
          </div>
        </section>
      </main>

      <footer>
        <p>A little appreciation, on-chain.</p>
        <div>
          <a
            href={`${explorer}/address/${jarAddress}`}
            target="_blank"
            rel="noreferrer"
          >
            View TipJar contract ↗
          </a>
          <a
            href={`${explorer}/address/${usdcAddress}`}
            target="_blank"
            rel="noreferrer"
          >
            USDC contract ↗
          </a>
        </div>
      </footer>
    </div>
  )
}
