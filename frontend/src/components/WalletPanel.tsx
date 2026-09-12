import {
  useConnect,
  useConnection,
  useConnectors,
  useDisconnect,
  useSwitchChain,
} from 'wagmi'
import { formatEther } from 'viem'
import { chain, explorer } from '../config'
import { errorMessage, shortAddress, usdc } from '../lib/amount'

type Props = { balance?: bigint; allowance?: bigint; gas?: bigint }

export function WalletPanel({ balance, allowance, gas }: Props) {
  const { address, isConnected, chainId } = useConnection()
  const connect = useConnect()
  const disconnect = useDisconnect()
  const switchChain = useSwitchChain()
  const connectors = useConnectors()
  const discovered = connectors.filter(
    (connector) => connector.id !== 'injected',
  )
  const choices = discovered.length ? discovered : connectors
  const wrongChain = isConnected && chainId !== chain.id

  return (
    <section className="wallet-panel" aria-labelledby="wallet-heading">
      <div className="section-heading">
        <h2 id="wallet-heading">Your wallet</h2>
        <span className={`status-dot ${isConnected ? 'connected' : ''}`}>
          {isConnected ? 'Connected' : 'Not connected'}
        </span>
      </div>
      {address ? (
        <>
          <div className="wallet-address">
            <a
              href={`${explorer}/address/${address}`}
              target="_blank"
              rel="noreferrer"
              title={address}
            >
              {shortAddress(address)} ↗
            </a>
            <button className="text-button" onClick={() => disconnect.mutate()}>
              Disconnect
            </button>
          </div>
          <p className="muted small">
            Wallet network: {wrongChain ? `Chain ${chainId}` : chain.name}
          </p>
          {wrongChain && (
            <div className="notice warning">
              <p>Switch to Base Sepolia to approve or tip.</p>
              <button
                className="button secondary"
                disabled={switchChain.isPending}
                onClick={() => switchChain.mutate({ chainId: chain.id })}
              >
                {switchChain.isPending
                  ? 'Waiting for wallet…'
                  : 'Switch to Base Sepolia'}
              </button>
            </div>
          )}
          <dl className="wallet-balances">
            <div>
              <dt>USDC balance</dt>
              <dd>
                {usdc(balance)} <small>USDC</small>
              </dd>
            </div>
            <div>
              <dt>Jar allowance</dt>
              <dd>
                {usdc(allowance)} <small>USDC</small>
              </dd>
            </div>
            <div>
              <dt>ETH for gas</dt>
              <dd>
                {gas === undefined ? '—' : formatEther(gas)} <small>ETH</small>
              </dd>
            </div>
          </dl>
        </>
      ) : (
        <>
          <p className="muted">
            Connect a browser wallet to see your balance and send a little
            thanks.
          </p>
          <div className="wallet-options">
            {choices.map((connector) => (
              <button
                key={connector.uid}
                className="button primary"
                disabled={connect.isPending}
                onClick={() => connect.mutate({ connector })}
              >
                {connect.isPending
                  ? 'Waiting for wallet…'
                  : connector.id === 'injected'
                    ? 'Connect browser wallet'
                    : `Connect ${connector.name}`}
              </button>
            ))}
          </div>
          <p className="small muted">
            Use your funded Base Sepolia wallet. Your wallet signs each
            transaction.
          </p>
        </>
      )}
      {(connect.error || switchChain.error) && (
        <p role="alert" className="error-text">
          {errorMessage(connect.error || switchChain.error)}
        </p>
      )}
    </section>
  )
}
