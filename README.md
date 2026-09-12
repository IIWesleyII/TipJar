# TipJar

A learning project for sending and withdrawing ERC-20 tips on-chain.
**Phases 1–3 are implemented and tested**, and the completed contract is
deployed on Base Sepolia. Phase 4 adds a React interface for wallet connection,
USDC approval, tipping, and live statistics.

## What is implemented

- A local mock USDC token with 6 decimals and unrestricted minting.
- A Tip Jar configured with a token address at deployment.
- `tip(uint256 amount, string calldata message)` and owner-only `withdraw()`.
- Lifetime `totalTips` and optional messages recorded in tip events.
- A successful-tip count and lifetime contribution totals for each address.
- The largest single successful tip and the address that sent it.
- An owner-controlled withdrawal destination, initially the owner.
- Custom errors and events for tips, withdrawals, and destination changes.
- Foundry unit tests, bounded fuzz tests, and token failure coverage.

The deployer remains the fixed owner, even when the withdrawal destination
changes. The React interface supports Phase 4's tipping flow. Phase 5's event
history and Phase 6's frontend owner controls remain separate future work.

## Files and tools

```text
contracts/
  foundry.toml           Compiler, imports, and fuzz configuration
  src/TipJar.sol         Tip statistics and owner controls
  test/TipJar.t.sol      Unit tests and token failure cases
  test/TipJarFuzz.t.sol  Tests with generated inputs
  test/mocks/
    MockUSDC.sol              Token for local tests and Anvil
    MockNonReturningUSDC.sol  Token returning no transfer data
  lib/                  Installed dependencies (ignored)
  deployments/          Public Base Sepolia addresses and test receipts
frontend/
  src/App.tsx           Statistics and page layout
  src/components/       Wallet connection and tipping form
  src/hooks/            Contract reads and transaction lifecycle
  src/abi/tipJar.ts      Generated contract ABI
  src/deployment.json   Public deployment configuration
  tests/                Browser tests using a simulated wallet and RPC
```

The mock stays under `test/mocks/` so local tests can create token balances
without faucets or a network connection. Testnet deployments use Circle's
existing USDC contract; `TipJar.sol` does not import or deploy the mock.

The project uses Solidity 0.8.24, Foundry, OpenZeppelin Contracts 5.0.2,
and forge-std 1.9.7. Dependency versions are deliberately pinned for this
learning milestone; they are not claims about the latest releases.

## Setup and tests

For the React interface, see [frontend setup](frontend/README.md). With
Node.js 22.12 or newer installed, start from the repository root:

```bash
bash run-frontend.sh
```

The script also finds this workspace's local WSL Node runtime and installs
frontend dependencies when missing. Press Ctrl+C to stop the server.

The app defaults to the deployed Base Sepolia contract. Connect the funded
tipper wallet in your browser; approve USDC first, then send a separate tip.
Browser signing does not use the private keys in `contracts/.env`.

### Solidity

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
They also check tip counts, separate contribution totals for multiple users,
and preservation of existing statistics when a subsequent tip fails.
Largest-tip tests cover the first record, larger and smaller tips, ties,
repeated contributions, failed record attempts, and records after withdrawals.
Message tests check empty text, nonempty text, Unicode, newlines, and exact
event contents. Failure tests also exercise invalid tips with messages.

Phase 3 adds authorization and validation for withdrawal destinations,
minimum-unit and full-balance tips, failed withdrawals, and SafeERC20 behavior
when tokens return false, revert, or transfer successfully without return data.
The latter mock really moves tokens so its test verifies balances end to end.

The suite has **36 unit tests and 6 fuzz tests**, all passing. Each fuzz test
runs 256 generated cases by default (1,536 fuzz cases per suite run). Tests
bound amounts to available balances and exercise multiple contributors,
withdrawals, recipient changes, insufficient allowances, messages, and direct
token transfers. These use a local EVM and never sign testnet transactions.

From `contracts/`, explore tests and coverage with:

```bash
# Unit tests only.
forge test --match-contract '^TipJarTest$' -vv
# Generated inputs, with the default 256 cases per fuzz test.
forge test --match-contract TipJarFuzzTest -vv
# Trace a changed withdrawal destination and the resulting transfer.
forge test --match-test test_WithdrawTransfersToConfiguredRecipient -vvvv
# Measure execution coverage of the contract.
forge coverage --report summary
```

The measured `TipJar.sol` coverage is 100% of lines, statements, branches,
and functions. Coverage shows which code was exercised, not proof that every
possible behavior is safe; the trusted-token assumptions below still apply.

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

The current deployment is
[`0x045ec89C111f0f8fdCA868d736C7DCB8A92201DA`](https://sepolia.basescan.org/address/0x045ec89C111f0f8fdCA868d736C7DCB8A92201DA).
The owner deployed it, the tipper approved and tipped 0.1 USDC with a message,
and the owner changed the destination and withdrew the tip back to the tipper.
The destination was then restored to the owner. The jar is empty, with lifetime
tips of 0.1 USDC and one successful tip at the end of this check.
See [the public deployment report](contracts/deployments/README.md) for receipts.

The old Phase 1 jar is retained only for reference in the deployment record.
These contracts are not upgradeable: future contract changes require another
deployment and new approvals. Never assume an old jar gained the new code.

The current function signature is `tip(uint256,string)`, and the tip event is
`TipReceived(address,uint256,string)`. The old Phase 1 jar uses
`tip(uint256)` and `TipReceived(address,uint256)`. Use the matching signature
for each deployment; this version does not include the old one-argument call.

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
move tokens. The user then calls `jar.tip(amount, message)`. Inside the jar,
`msg.sender` is the tipper; when the jar calls the token's `transferFrom`, the
token sees the jar as the spender and checks its allowance from that tipper.

```text
Tipper -- approve(jar, amount) --> USDC: grants spending permission
Tipper -- tip(amount, message) -> TipJar
                                |-- transferFrom(tipper, jar, amount) --> USDC
                                |-- emits TipReceived
Owner  -- withdraw() ---------> TipJar -- transfer(recipient, balance) --> USDC
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

**Validation and atomicity.** `if (...) revert ErrorName()` rejects bad inputs
or unauthorized calls. Tipping checks the amount, updates accounting, then calls the token:
checks-effects-interactions. A failed token transfer reverts the whole
transaction, including the `totalTips` update and any token state changes.
The tests exercise both insufficient allowance and insufficient balance.
Custom errors identify failures by a compact selector (the first four bytes of
the error signature's hash). Tests use `vm.expectRevert(TipJar.InvalidAmount.selector)`
to check the exact error. OpenZeppelin token errors propagate through SafeERC20.

| Error | When it occurs |
| --- | --- |
| `InvalidAmount()` | The tip amount is zero |
| `Unauthorized()` | A caller other than the owner tries an owner function |
| `InvalidAddress()` | Token is zero or has no code; destination is zero or the jar |
| `NothingToWithdraw()` | The jar has no USDC to withdraw |

**Withdrawal destination and modifiers.** `withdrawalAddress` starts as the
deployer's address. The owner can call `setWithdrawalAddress(newAddress)` to
change it, including back to the owner. Zero and the jar itself are rejected
so a withdrawal does not send to an invalid destination or back into the jar.
The change emits `WithdrawalAddressChanged(previousAddress, newAddress)`.
Selecting the existing destination is allowed and emits the event too.

Both administrative functions use the `onlyOwner` modifier. It checks the
caller before the `_` placeholder runs the function body. The recipient does
not gain permission to withdraw or change settings. `withdraw()` transfers the
entire current USDC balance to that recipient and logs the recipient and amount.
A failed token transfer leaves funds and lifetime statistics unchanged.

**Accounting versus balance.** `totalTips` is lifetime successful `tip()` volume.
It never resets when funds are withdrawn. `usdc.balanceOf(address(jar))` is the
current withdrawable balance. Direct ERC-20 transfers increase that balance
without calling `tip()`, so they do not increase `totalTips` or emit its event.

**Events.** `TipReceived` and `Withdrawal` log successful actions. Indexed
addresses let future clients filter logs by tipper or recipient. Logs avoid
storing an ever-growing history array in contract storage.

**Optional messages and calldata.** Pass a string to `tip(amount, message)`;
use `tip(amount, "")` when no message is wanted. Solidity still requires both
arguments. `string calldata message` lets the function read the text from its
input data without making a separate mutable copy in memory. The text is
public transaction data and appears in the `TipReceived` event. It is not
saved in a contract storage variable, so there is no message getter; clients
retrieve messages from event logs. Longer messages cost more gas, and this
milestone does not impose an application-specific length limit.

**Tip counts and mappings.** `tipCount` counts successful `tip()` calls, not
unique contributors. `mapping(address => uint256) public tippedBy` looks up
each wallet's lifetime contribution in USDC base units. An address that has
never tipped returns zero. For example, two tips from Alice of 0.1 and 0.2 USDC
produce `tipCount == 2` and `tippedBy(alice) == 300000` in a fresh jar.

Inside `tip()`, `tippedBy[msg.sender] += amount` updates only the caller's
entry. All statistics update before the token transfer, and all revert
if that transfer fails. Withdrawals preserve the statistics; direct token
transfers into the jar do not change them. A mapping supports lookup by address
but does not provide a list of its keys.

**Largest single tip.** `largestTip` starts at zero, and `largestTipper` starts
at `address(0)` because nobody has tipped yet. Each successful tip checks
`if (amount > largestTip)` and updates both values when it sets a new record.
The strict `>` comparison means a tie keeps the first record holder. This
tracks one tip, not cumulative contributions: Alice tipping 15 USDC twice
does not beat Bob's single 20 USDC tip. Failed transfers undo record updates,
direct transfers do not count, and withdrawals preserve the record.

**Test callers.** Foundry's `vm.prank` changes the sender for the next call;
`vm.startPrank` applies it until `vm.stopPrank`. These simulate different users.
`vm.expectRevert` and `vm.expectEmit` check failures and event contents.

**Fuzz tests.** A test with input parameters lets Foundry generate many cases.
`bound(amount, 1, STARTING_BALANCE)` keeps tip amounts meaningful for the funded
wallet. `vm.assume` skips inputs that do not belong in a scenario, such as the
owner in a test for unauthorized callers. The message fuzz test limits text to
256 bytes to keep cases small; the contract itself has no such limit. Every
generated case starts with fresh test state, so previous cases cannot affect it.

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
cast send "$JAR_ADDRESS" 'tip(uint256,string)' 10000000 "Thanks!" \
  --rpc-url "$RPC_URL" --unlocked --from "$TIPPER"

cast call "$JAR_ADDRESS" 'totalTips()(uint256)' --rpc-url "$RPC_URL"
cast send "$JAR_ADDRESS" 'withdraw()' \
  --rpc-url "$RPC_URL" --unlocked --from "$OWNER"
cast call "$USDC_ADDRESS" 'balanceOf(address)(uint256)' "$JAR_ADDRESS" \
  --rpc-url "$RPC_URL"
```

Replace the angle-bracket address placeholders before running those lines.
Use `""` in place of `"Thanks!"` to tip without a message.
After withdrawal, the jar balance is zero and `totalTips` remains `10000000`.
Local addresses depend on deployments and chain resets. Keep your testnet jar
address in `contracts/.env` as `TIP_JAR_ADDRESS`.

To practice changing the withdrawal destination on this local deployment:

```bash
cast send "$JAR_ADDRESS" 'setWithdrawalAddress(address)' "$TIPPER" \
  --rpc-url "$RPC_URL" --unlocked --from "$OWNER"
cast call "$JAR_ADDRESS" 'withdrawalAddress()(address)' --rpc-url "$RPC_URL"
```

Future withdrawals now send USDC to the tipper, but only the owner can trigger
them. Repeat the setter with `"$OWNER"` to restore the original destination.

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
