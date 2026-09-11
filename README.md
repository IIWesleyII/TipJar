# TipJar

A learning project for sending and withdrawing ERC-20 tips on-chain.
This milestone implements **Phase 1: basic Solidity** only.

## What is implemented

- A local mock USDC token with 6 decimals and unrestricted minting.
- A Tip Jar configured with a token address at deployment.
- `tip(uint256 amount)`, lifetime `totalTips`, and owner-only `withdraw()`.
- Tip and withdrawal events, validation, and Foundry unit tests.

The deployer is the fixed owner and receives withdrawals. Contributor tracking,
tip messages, configurable withdrawal destinations, custom Tip Jar errors,
expanded fuzz testing, and the frontend belong to later phases.

## Files and tools

```text
contracts/
  foundry.toml             Compiler and import configuration
  src/TipJar.sol           Tip and withdrawal logic
  test/TipJar.t.sol        Core success and failure tests
  test/mocks/MockUSDC.sol  Token for local tests and Anvil
  lib/                    Installed dependencies (ignored)
```

The mock stays under `test/mocks/` so local tests can create token balances
without faucets or a network connection. Testnet deployments use Circle's
existing USDC contract; `TipJar.sol` does not import or deploy the mock.

The project uses Solidity 0.8.24, Foundry, OpenZeppelin Contracts 5.0.2,
and forge-std 1.9.7. Dependency versions are deliberately pinned for this
learning milestone; they are not claims about the latest releases.

## Setup and tests

Use Bash (WSL or Git Bash on Windows). Install Foundry using the
[official instructions](https://getfoundry.sh/getting-started/installation).
The following commands start at the repository root:

```bash
cd contracts
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-git
forge install foundry-rs/forge-std@v1.9.7 --no-git
forge build
forge test -vv
forge fmt --check
```

Dependencies are local, ignored copies rather than Git submodules; run both
install commands after a fresh clone. The initial tool/dependency/compiler
downloads need internet access. Tests then run in Foundry's in-process EVM,
without Anvil, a public RPC, a wallet, or real funds.

For this workspace, Foundry 1.8.1 was downloaded into `contracts/.tools/` and
its archive checksum matched the official release checksum. In WSL, use this
before the commands above if Foundry is not on your PATH:

```bash
# Run from contracts/; applies only to the current shell.
export PATH="$PWD/.tools:$PATH"
```

The tests cover configuration, 6-decimal units, approval and transfer behavior,
multiple tips and users, emitted events, owner authorization, empty withdrawals,
failed transfers and rollback, repeated withdrawals, and direct token transfers.

## Testnet configuration

`contracts/.env.example` documents the testnet configuration. On a fresh clone,
copy it from the `contracts/` directory without overwriting an existing file:

```bash
cp -n .env.example .env
```

The configuration defaults to **Base Sepolia (chain ID 84532)**, matching the
funded development wallets. `USDC_ADDRESS` is filled
with Circle's official test USDC address:
`0x036CbD53842c5426634e7929541eC2318f3dCF7e`, verified against
[Circle's contract address list](https://developers.circle.com/stablecoins/usdc-contract-addresses).
Fill in `RPC_URL` with a Base Sepolia endpoint, plus your `OWNER_ADDRESS`
and `TIPPER_ADDRESS`. Record your deployed jar in `TIP_JAR_ADDRESS`. If changing
networks, update both the RPC endpoint and token address to match.

The actual deployment signer becomes the owner; setting `OWNER_ADDRESS` alone
does not configure ownership or authorize transactions. Use an encrypted
Foundry keystore for signing and keep private keys and seed phrases out of
these files. The repository ignores `.env`; `.env.example` is safe to commit
with the public token address and placeholders for your configuration.

To make your filled-in configuration available in a Bash terminal, run from
`contracts/`:

```bash
set -a
source .env
set +a
```

## Solidity concepts in this phase

**Constructor and immutable state.** The constructor runs once at deployment.
It records the USDC address and `msg.sender` as owner. `immutable` means neither
can be changed afterward. Public state variables have compiler-generated read
functions such as `owner()`, `usdc()`, and `totalTips()`.

**ERC-20 approval.** Tokens live in the token contract's balance mapping.
Calling `approve(jar, amount)` gives the jar a spending allowance; it does not
move tokens. The user then calls `jar.tip(amount)`. Inside the jar,
`msg.sender` is the tipper; when the jar calls the token's `transferFrom`, the
token sees the jar as the spender and checks its allowance from that tipper.

```text
Tipper -- approve(jar, amount) --> USDC: grants spending permission
Tipper -- tip(amount) --------> TipJar
                                |-- transferFrom(tipper, jar, amount) --> USDC
                                |-- emits TipReceived
Owner  -- withdraw() ---------> TipJar -- transfer(owner, balance) ------> USDC
```

**Decimals.** Solidity uses integer token amounts. With 6 decimals, `1 USDC`
is `1_000_000` units, and `10 USDC` is `10 * 1e6`. Decimals describe display
precision, not floating-point arithmetic. The mock overrides OpenZeppelin's
default 18 decimals. See the
[OpenZeppelin ERC-20 guide](https://docs.openzeppelin.com/contracts/5.x/erc20).

**Interfaces and safe transfers.** `IERC20` describes the token functions the
jar can call. `using SafeERC20 for IERC20` attaches safe transfer helpers to
that interface. Those helpers handle tokens returning `false` or no return
value; they do not certify that an arbitrary token is trustworthy. See the
[SafeERC20 reference](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#SafeERC20).

**Validation and atomicity.** `require` rejects bad inputs or unauthorized
calls. Tipping checks the amount, updates accounting, then calls the token:
checks-effects-interactions. A failed token transfer reverts the whole
transaction, including the `totalTips` update and any token state changes.
The tests exercise both insufficient allowance and insufficient balance.
Short revert strings keep this phase simple; the mock's inherited OpenZeppelin
implementation already uses custom errors internally.

**Accounting versus balance.** `totalTips` is lifetime successful `tip()` volume.
It never resets when funds are withdrawn. `usdc.balanceOf(address(jar))` is the
current withdrawable balance. Direct ERC-20 transfers increase that balance
without calling `tip()`, so they do not increase `totalTips` or emit its event.

**Events.** `TipReceived` and `Withdrawal` log successful actions. Indexed
addresses let future clients filter logs by tipper or recipient. Logs avoid
storing an ever-growing history array in contract storage.

**Test callers.** Foundry's `vm.prank` changes the sender for the next call;
`vm.startPrank` applies it until `vm.stopPrank`. These simulate different users.
`vm.expectRevert` and `vm.expectEmit` check failures and event contents.

## Optional local walkthrough

In a separate Bash terminal, start a disposable local chain:

```bash
anvil
```

From `contracts/`, use two of Anvil's default unlocked accounts. These commands
are for local Anvil only. Deployments print the addresses to use below:

```bash
export RPC_URL=http://127.0.0.1:8545
export OWNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export TIPPER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

forge create test/mocks/MockUSDC.sol:MockUSDC \
  --rpc-url "$RPC_URL" --unlocked --from "$OWNER" --broadcast

export USDC_ADDRESS="<mock-address-from-deployment>"

forge create src/TipJar.sol:TipJar \
  --rpc-url "$RPC_URL" --unlocked --from "$OWNER" --broadcast \
  --constructor-args "$USDC_ADDRESS"

export JAR_ADDRESS="<jar-address-from-deployment>"

# Mint 100 mock USDC to the tipper.
cast send "$USDC_ADDRESS" 'mint(address,uint256)' "$TIPPER" 100000000 \
  --rpc-url "$RPC_URL" --unlocked --from "$OWNER"

# Approve exactly 10 USDC, then tip in a separate transaction.
cast send "$USDC_ADDRESS" 'approve(address,uint256)' "$JAR_ADDRESS" 10000000 \
  --rpc-url "$RPC_URL" --unlocked --from "$TIPPER"
cast send "$JAR_ADDRESS" 'tip(uint256)' 10000000 \
  --rpc-url "$RPC_URL" --unlocked --from "$TIPPER"

cast call "$JAR_ADDRESS" 'totalTips()(uint256)' --rpc-url "$RPC_URL"
cast send "$JAR_ADDRESS" 'withdraw()' \
  --rpc-url "$RPC_URL" --unlocked --from "$OWNER"
cast call "$USDC_ADDRESS" 'balanceOf(address)(uint256)' "$JAR_ADDRESS" \
  --rpc-url "$RPC_URL"
```

Replace the angle-bracket address placeholders before running those lines.
After withdrawal, the jar balance is zero and `totalTips` remains `10000000`.
Local addresses depend on deployments and chain resets. Keep your testnet jar
address in `contracts/.env` as `TIP_JAR_ADDRESS`.

## Scope and assumptions

The configured token must be trusted USDC or this mock: ordinary exact-amount
ERC-20 transfers, without transfer fees, rebasing, or transfer callbacks. The
constructor rejects zero and non-contract addresses, but cannot prove a token
is authentic USDC. The mock does not reproduce USDC's administrative features.

No reentrancy guard is added in this phase: the intended token has no recipient
callbacks, tipping updates accounting before its external transfer, and only
the fixed owner can withdraw. Supporting arbitrary tokens would require
revisiting these assumptions. There is no ownership transfer or recovery flow;
the deployment account must be the intended owner. The mock's public mint
function is strictly for local development.
