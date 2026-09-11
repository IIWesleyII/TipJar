# USDC Tip Jar

## Project Overview

USDC Tip Jar is a full-stack Web3 application built around a Solidity smart contract that allows users to send USDC tips, track contributor activity, and lets the contract owner withdraw collected funds.

The project is intended primarily as a portfolio and learning project that demonstrates:

* Solidity smart contract development
* ERC-20 token interactions
* USDC payments
* Smart contract security practices
* Foundry testing
* Wallet integration
* React and TypeScript frontend development
* Ethereum event logs
* Contract reads and writes
* Clean software engineering practices

The project should remain relatively small and understandable. Avoid adding unnecessary complexity solely to make the project appear more advanced.

---

# Core User Flow

The primary tipping flow is:

1. User connects an EVM wallet.
2. Frontend reads the user's USDC balance.
3. Frontend reads the user's USDC allowance for the Tip Jar contract.
4. User approves the Tip Jar contract to spend USDC.
5. User calls `tip(amount, message)`.
6. The Tip Jar contract calls USDC `transferFrom()`.
7. USDC moves from the user's wallet to the Tip Jar contract.
8. The contract updates tipping statistics.
9. The contract emits a `TipReceived` event.
10. The frontend displays the successful transaction and updated statistics.
11. The contract owner may later withdraw accumulated USDC.

The project should make this ERC-20 approval and transfer flow visible and understandable through the frontend.

---

# Technology Stack

## Smart Contracts

* Solidity
* Foundry
* OpenZeppelin Contracts
* ERC-20 / IERC20
* SafeERC20

Foundry should be used for:

* compiling contracts
* unit tests
* fuzz tests
* local blockchain development
* deployment scripts
* command-line contract interaction

Useful Foundry tools include:

* `forge`
* `cast`
* `anvil`

## Frontend

* React
* TypeScript
* Vite
* viem
* wagmi

Avoid unnecessary frontend libraries unless they solve a clear problem.

The frontend should emphasize clarity and contract interaction rather than elaborate visual design.

---

# Repository Structure

A preferred structure is:

```text
tip-jar/
├── AGENTS.md
├── README.md
├── contracts/
│   ├── src/
│   │   └── TipJar.sol
│   ├── test/
│   │   └── TipJar.t.sol
│   ├── script/
│   │   └── DeployTipJar.s.sol
│   ├── foundry.toml
│   └── lib/
└── frontend/
    ├── src/
    │   ├── components/
    │   ├── hooks/
    │   ├── abi/
    │   ├── pages/
    │   └── App.tsx
    ├── package.json
    └── vite.config.ts
```

The exact organization may evolve, but smart contract and frontend concerns should remain clearly separated.

---

# Smart Contract Requirements

The main contract should be:

```text
TipJar.sol
```

The contract accepts an existing ERC-20 token rather than implementing a token itself.

The initial target token is USDC.

The USDC contract address should preferably be passed into the Tip Jar constructor rather than hardcoded into the contract.

Example conceptual constructor:

```solidity
constructor(address usdcAddress)
```

The contract should use OpenZeppelin's `IERC20` and `SafeERC20`.

---

# Initial Contract State

The contract will likely need state similar to:

```solidity
IERC20 public immutable usdc;

address public owner;
address public withdrawalAddress;

uint256 public totalTips;
uint256 public tipCount;

uint256 public largestTip;
address public largestTipper;

mapping(address => uint256) public tippedBy;
```

Exact implementation may change as the project develops.

Do not store unnecessary duplicated blockchain data.

---

# Core Contract Functions

## tip

Conceptual interface:

```solidity
function tip(
    uint256 amount,
    string calldata message
) external
```

Responsibilities:

* reject zero-value tips
* transfer USDC from the sender into the Tip Jar
* update total tips
* increment the tip count
* update the sender's cumulative contribution
* update largest-tip information when appropriate
* emit a `TipReceived` event

USDC uses 6 decimals. Avoid assuming ERC-20 tokens always use 18 decimals.

---

## withdraw

Conceptual interface:

```solidity
function withdraw() external
```

Responsibilities:

* only allow the owner to call the function
* determine the Tip Jar's current USDC balance
* transfer that balance to `withdrawalAddress`
* emit a withdrawal event
* handle zero-balance behavior cleanly

---

## setWithdrawalAddress

Conceptual interface:

```solidity
function setWithdrawalAddress(
    address newWithdrawalAddress
) external
```

Responsibilities:

* owner only
* reject the zero address
* update the withdrawal destination
* emit an event

---

# Events

Events are an important part of the project because they demonstrate Ethereum logging and allow the frontend to display historical tipping activity without storing a large on-chain array.

The contract should emit an event similar to:

```solidity
event TipReceived(
    address indexed tipper,
    uint256 amount,
    string message
);
```

Also include events for administrative actions.

For example:

```solidity
event Withdrawal(
    address indexed recipient,
    uint256 amount
);

event WithdrawalAddressChanged(
    address indexed previousAddress,
    address indexed newAddress
);
```

The exact names may be adjusted if there is a good reason.

---

# Errors and Validation

Prefer Solidity custom errors over long revert strings.

Examples:

```solidity
error InvalidAmount();
error Unauthorized();
error InvalidAddress();
error NothingToWithdraw();
```

Validation should be simple and explicit.

Do not introduce unusual modifier abstractions unless they improve readability.

---

# Security Expectations

This project should demonstrate basic smart contract security awareness.

Important considerations include:

* use `SafeERC20`
* validate addresses
* restrict administrative functions
* follow checks-effects-interactions where appropriate
* minimize external calls
* avoid unnecessary mutable state
* consider reentrancy where external token transfers occur
* avoid trusting arbitrary ERC-20 return behavior
* test failure paths as well as successful transactions

Do not add security libraries mechanically. If something such as `ReentrancyGuard` is introduced, document why it is necessary.

---

# Testing Strategy

Smart contract tests are a major part of this project.

Use Foundry tests.

Tests should include at minimum:

```text
test_UserCanTip
test_TipTransfersUSDC
test_TipUpdatesTotalTips
test_TipUpdatesTipCount
test_TipUpdatesUserContribution
test_TipEmitsEvent
test_TipUpdatesLargestTip
test_OwnerCanWithdraw
test_WithdrawTransfersCorrectBalance
test_NonOwnerCannotWithdraw
test_CannotTipZero
test_CannotSetZeroWithdrawalAddress
```

Also test multiple users tipping.

Where useful, include Foundry fuzz tests.

Example target:

```text
testFuzz_Tip
```

Fuzz tests should have sensible bounds rather than generating meaningless impossible values.

A mock ERC-20 token should be used for local testing so tests do not depend on a public network or real USDC.

The mock should preferably use 6 decimals so behavior matches USDC more closely.

---

# Development Stages

Development should happen incrementally.

## Phase 1 — Basic Solidity

Implement only:

* mock USDC
* Tip Jar constructor
* `tip()`
* `withdraw()`
* `totalTips`
* basic events
* tests

The goal is to fully understand the core ERC-20 flow before adding more features.

---

## Phase 2 — Contract Features

Add:

* `tippedBy`
* `tipCount`
* largest tip
* largest tipper
* optional tip messages
* configurable withdrawal address
* custom errors
* additional event coverage

Keep the contract simple.

---

## Phase 3 — Strong Test Coverage

Expand Foundry tests to cover:

* successful behavior
* authorization
* invalid input
* event emission
* accounting
* multiple users
* withdrawals
* fuzz testing

The contract should have meaningful tests before frontend work becomes the focus.

---

## Phase 4 — React Frontend

Create a frontend that allows:

* wallet connection
* network display
* USDC balance display
* current allowance display
* USDC approval
* tip submission
* optional tip message
* transaction status
* Tip Jar USDC balance
* total tips
* tip count
* largest tip
* largest tipper
* current user's total contribution

The application should clearly distinguish between an ERC-20 approval transaction and the actual Tip Jar transaction.

---

## Phase 5 — Event History

Use `TipReceived` logs to display recent tips.

The frontend should retrieve blockchain logs rather than relying on a large on-chain array of tip records.

Recent tips should display information such as:

```text
Wallet
Amount
Message
Transaction hash
Block
```

This feature is specifically intended to demonstrate knowledge of Ethereum logs and event-driven application architecture.

---

## Phase 6 — Owner Controls

When the connected wallet is the owner, display an owner section containing:

* Tip Jar USDC balance
* withdrawal address
* change withdrawal address
* withdraw funds

Owner-only controls should not be presented as available actions to ordinary users.

The smart contract must still enforce authorization regardless of frontend visibility.

---

# Frontend UX

The frontend is also intended to serve as a testing interface for the contract.

Important information should remain visible.

A useful layout could include:

```text
Wallet

Connected Address
Network
USDC Balance
USDC Allowance

Send Tip

Tip Amount
Message
Approve USDC
Send Tip

Tip Jar Statistics

Contract Balance
Total Tips
Tip Count
Largest Tip
Largest Tipper
Your Contributions

Recent Tips

Address
Amount
Message

Owner Controls

Withdrawal Address
Change Address
Withdraw
```

Transaction states should be visible.

Examples:

```text
Waiting for wallet signature
Transaction submitted
Waiting for confirmation
Transaction confirmed
Transaction failed
```

Do not hide blockchain behavior behind overly generic UI messages.

---

# ERC-20 Approval UX

Approval is a major learning objective.

The frontend should expose:

```text
USDC balance
Tip Jar allowance
Desired tip
```

If allowance is insufficient, the UI should make it clear that approval is required.

Conceptually:

```text
Allowance: 0 USDC
Tip amount: 10 USDC

Approve 10 USDC
```

After approval:

```text
Allowance: 10 USDC

Send 10 USDC Tip
```

Do not automatically implement unlimited token approvals unless intentionally chosen and documented.

---

# Network Development

Start with a local Foundry Anvil chain.

Use a mock USDC contract for local development.

Later, deploy to an appropriate EVM testnet.

Do not make the early development workflow dependent on third-party RPC services when Anvil is sufficient.

Network-specific configuration should live in environment variables or configuration files rather than being scattered throughout application code.

---

# Code Quality Preferences

Code should prioritize readability and learning value.

Avoid:

* unnecessary abstractions
* giant helper classes
* excessive dependency injection
* deeply nested logic
* premature optimization
* excessive comments explaining obvious code
* complicated architecture for a small project

Prefer:

* small functions
* descriptive names
* explicit control flow
* clean module boundaries
* straightforward tests

Keep source lines under approximately 80 characters when practical.

Only wrap a line when it would otherwise exceed approximately 80 characters.

Terminal commands should use Bash syntax.

---

# Documentation Expectations

The final repository README should explain:

1. What the project does
2. Why ERC-20 approval is necessary
3. How `approve()` and `transferFrom()` work together
4. Architecture
5. Technology stack
6. Local setup
7. Running Anvil
8. Deploying contracts
9. Running tests
10. Starting the frontend
11. Contract addresses
12. Example user flow
13. Security considerations

Include a simple architecture diagram where useful.

---

# Portfolio Goal

This project is not intended to demonstrate the largest possible application.

It should demonstrate that the developer understands the full lifecycle of an EVM application:

```text
Wallet
  ↓
ERC-20 approval
  ↓
Solidity contract call
  ↓
ERC-20 transferFrom
  ↓
Contract state update
  ↓
Ethereum event
  ↓
Transaction receipt
  ↓
Frontend state refresh
```

Someone reviewing the repository should be able to see competency in:

* Solidity
* Ethereum
* ERC-20
* Foundry
* contract testing
* transaction handling
* event logs
* React
* TypeScript
* wallet interaction
* software architecture

---

# Implementation Philosophy

Do not generate the entire project in one large pass.

Implement small milestones and keep the project runnable after each milestone.

When making meaningful changes:

1. explain what is being added
2. implement the smallest reasonable version
3. add or update tests
4. run the relevant tests
5. fix failures before moving forward

Prefer teaching-quality code over clever code.

When there are multiple reasonable implementation choices, favor the approach commonly used in professional Solidity/EVM development and briefly explain the tradeoff.
