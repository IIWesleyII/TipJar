# TipJar React interface

React, TypeScript, Vite, wagmi, viem, and TanStack Query power the Phase 4
interface. It reads from the deployed Base Sepolia jar without requiring a
wallet connection. Connect a browser wallet to approve and tip test USDC.

## Start locally

From the repository root in **Git Bash or WSL Bash**:

```bash
bash run-frontend.sh
```

The script uses this workspace's local Node runtime when available and
installs dependencies if `node_modules` is missing. In Git Bash, it forwards
to WSL when that local Linux runtime is present. Otherwise, it uses your
installed Node.js and npm (Node.js 22.12 or newer is required).

Press **Ctrl+C** to stop. Extra Vite options can be passed through:

```bash
bash run-frontend.sh --port 5174
```

Open the localhost URL printed by Vite in a browser with a wallet extension.
Choose the funded tipper wallet and Base Sepolia. Your browser wallet signs
transactions; this app does not read the private keys in `contracts/.env`.

For a fresh clone, install Node.js separately because `.tools/` is ignored.
Vite uses polling under WSL so edits from a Windows editor refresh the page.
The default public RPC and deployed addresses work without a frontend `.env`.
Optional overrides are documented in `.env.example`. All `VITE_` variables
are public browser configuration; a private RPC API key must not be put there.

## Approval and tipping

1. Connect your browser wallet. Switch to Base Sepolia if prompted.
2. Check the USDC balance, jar allowance, and ETH available for gas.
3. Enter an amount with at most six decimal places and an optional message.
4. If allowance is too small, approve exactly the entered amount.
5. Wait for confirmation. Approval does not transfer tokens or auto-send a tip.
6. Press Send and confirm the separate tip transaction in your wallet.
7. Follow the transaction link and watch statistics refresh after confirmation.

The interface shows waiting for signature, submitted, confirmed, and failure
states. Rejected signatures can be retried. Failed receipts are not shown as
successes. Wrong-network, invalid-amount, insufficient-balance, and read-error
states disable sending. The public RPC is polled every 12 seconds; node lag
can briefly delay balance updates even after a transaction receipt arrives.

## How the code fits together

- `config.ts` configures the chain, public RPC, and browser wallet connector.
- `useJarReads.ts` batches reads and keeps public and wallet statistics separate.
- `TipForm.tsx` validates six-decimal amounts and explains approve versus send.
- `useTipTransaction.ts` requests a wallet signature, waits for a receipt, and
  refreshes cached reads. A signature alone is not a successful transaction.
- `abi/tipJar.ts` describes the contract's functions, inputs, events, and errors.
  It is generated from the same Foundry artifact used for deployment.

After an intentional contract build and deployment update:

```bash
npm run sync:contract
```

This reads only the public Foundry ABI and `contracts/deployments/base-sepolia.json`.
It never copies `contracts/.env` into the frontend.

## Verification

```bash
npm run build
npm test
npx playwright install chromium
npm run test:e2e
```

Browser tests use a simulated injected wallet and intercepted RPC responses.
They do not use real keys or broadcast transactions. The real contract's
deployment and smoke-test receipts are in `contracts/deployments/`.

The production build, 11 amount tests, and 7 browser tests pass. A separate
browser check also read the deployed contract through the public RPC and
confirmed the expected statistics without sending any transactions.

To use an installed Chrome browser in the same environment as Node:

```bash
PLAYWRIGHT_CHANNEL=chrome npm run test:e2e
```

Event history and owner withdrawal/settings screens are deferred to Phases 5
and 6. The contract already supports those operations through Foundry commands.
