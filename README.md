# MultiSig Wallet (Foundry)

This repository contains a multi-signature wallet smart contract implemented in Solidity, along with Foundry configuration for development, testing, and deployment.

## 📝 Description

A secure, gas-efficient multi-signature wallet that:

* Allows multiple owners to propose, confirm, and execute transactions
* Requires a configurable number of confirmations before execution
* Supports owner management (add/remove)
* Emits events for all state changes and deposits
* Protects against reentrancy via OpenZeppelin's `ReentrancyGuard`

## 📦 Prerequisites

* Node.js (for running scripts, if needed)
* Foundry (`forge`, `cast`)

  * Install via:

    ```bash
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    ```
* An Ethereum-compatible RPC endpoint (e.g., Anvil, Infura, Alchemy)

## 🔧 Project Setup

1. **Clone the repo**

   ```bash
   git clone https://github.com/your-username/multisig-foundry.git
   cd multisig-foundry
   ```

2. **Install dependencies**
   Foundry manages dependencies via `remappings.txt`.

   ```bash
   forge install
   ```

3. **Configure remappings**
   In `remappings.txt`, ensure the OpenZeppelin path is:

   ```text
   @openzeppelin/=lib/openzeppelin-contracts/
   ```

## ⚙️ Compilation

Compile the smart contracts:

```bash
forge build
```

## 🧪 Testing

Run the full test suite:

```bash
forge test
```

Run a specific test file or function:

```bash
forge test --match-test testAddOwner
```

## 🚀 Deployment

Use `forge script` to deploy on your preferred network. Example deploy script in `script/Deploy.s.sol`:

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## 📘 Contract Usage

### Constructor

```solidity
constructor(address[] memory _owners, uint256 _requiredConfirmations)
```

* `_owners`: Initial list of owner addresses
* `_requiredConfirmations`: Number of confirmations required to execute a transaction

### Key Functions

* `createTransaction(address to, uint256 value, bytes calldata data)`:

  * Propose a new transaction
* `confirmTransaction(uint256 txIndex)`:

  * Owner confirms a pending transaction
* `executeTransaction(uint256 txIndex)`:

  * Executes once enough confirmations are gathered
* `revokeConfirmation(uint256 txIndex)`:

  * Revokes an owner’s prior confirmation
* `addOwner(address newOwner)` / `removeOwner(address owner)`:

  * Manage the owner set (revokes confirmations of removed owner)
* `changeRequiredConfirmations(uint256 newRequiredConfirmations)`:

  * Update threshold

### View Functions

* `getOwners()`: Returns the owner list
* `getTransactionCount()`: Total proposals
* `getTransaction(uint256 txIndex)`: Details
* `getPendingTransactions()`: Indexes of non‑executed transactions

## 🔐 Security

* Uses OpenZeppelin’s `ReentrancyGuard` for `executeTransaction`
* Validates zero addresses and duplicate owners
* Cleans up confirmations when removing owners

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
