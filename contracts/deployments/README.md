# Base Sepolia deployment

Contract: 0x045ec89C111f0f8fdCA868d736C7DCB8A92201DA

USDC: 0x036CbD53842c5426634e7929541eC2318f3dCF7e

Owner: 0xFBccd87D2adcD6b734fdd61C4b088dE88112e659

Chain ID: 84532. Solidity: 0.8.24.

[Deployment transaction](https://sepolia.basescan.org/tx/0xb9c4a1b9954f966daa9d96d6ee31998d9568c4847c95bb72e9ba66bbf60c3b65)

## Testnet smoke test

All transactions confirmed successfully. Receipts are saved in base-sepolia.json.

| Action | Transaction |
| --- | --- |
| Approve 0.1 USDC | [View receipt](https://sepolia.basescan.org/tx/0x743c4e8cafe0c5f6c72589b20a16fff70762009f6c3cada5ba58a66ef3a9f515) |
| Tip with message | [View receipt](https://sepolia.basescan.org/tx/0x7e97b49bad6bd1aba25f08a9125fce698214dec4ee949f8372025022c8654d27) |
| Set recipient to tipper | [View receipt](https://sepolia.basescan.org/tx/0xbd18e7ce1f6c34752196a99966e2d70cd5bb5f40d7e2c7fa24fa765e2d7d8094) |
| Withdraw to configured recipient | [View receipt](https://sepolia.basescan.org/tx/0xafa4b0435ee00103817da630b088c0b63d2aafa60f4f64fcd1980e04c2bfd865) |
| Restore owner as recipient | [View receipt](https://sepolia.basescan.org/tx/0x9d85613a2e00367eeef766be941c33ab5e275f628419e61538d8ff218b573ad2) |

Verified: approval alone moved no USDC; the tip emitted its message and updated
all statistics; allowance returned to zero; unauthorized withdrawals and a zero
destination reverted in read-only simulations; the owner withdrew to the
configured recipient; an empty withdrawal reverted; the owner destination was
restored. One immediate post-receipt balance read was stale; subsequent reads
confirmed the expected balances without repeating the successful withdrawal.

Final state: jar balance 0, lifetime tips 100000 (0.1 USDC), tip count 1,
largest tip 100000, withdrawal destination = owner. The tipper received their
0.1 USDC back; both wallets spent test ETH for gas.

The previous Phase 1 jar is retained in the JSON record for reference.
New approvals must target this deployment. No private keys or private RPC URLs
are stored in these deployment records.
