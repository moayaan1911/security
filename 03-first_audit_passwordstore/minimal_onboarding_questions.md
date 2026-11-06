# Minimal Onboarding Questions

> Client intake form — filled in by the protocol team and returned before the security review starts.

---

## 1. Summary / description

**PasswordStore** — a smart contract application for storing a password.

Users should be able to store a password and then retrieve it later. Others should not be able to access the stored password. The owner can update the password at any time.

---

## 2. Contract metrics

| Metric | Value |
|---|---|
| nSloc (normalized source lines of code) | **20** *(FILLED BY AUDITOR MOHAMMAD AYAAN)* |
| Complexity | **10** *(FILLED BY AUDITOR MOHAMMAD AYAAN)* |

---

## 3. Complete commands

**Dependencies first** — the repo ships with uninitialized submodules, so a fresh clone won't build until these are installed:

```bash
git submodule update --init --recursive
# or
forge install
```

**Build**

```bash
forge build
```

**Test**

```bash
forge test
```

**Coverage**

```bash
forge coverage
forge coverage --report debug
```

**Deploy (local)**

```bash
make anvil     # terminal 1
make deploy    # terminal 2
```

**Deploy (Sepolia)**

```bash
make deploy ARGS="--network sepolia"
```

---

## 4. Commit hash

```
7d55682ddc4301a7b13ae9413095feffd9924566
```

**In scope:** `src/PasswordStore.sol` only.

> ⚠️ Any commit made after this hash is **unaudited**.

---

## 5. Contract / project info

| Field | Value |
|---|---|
| Solidity compiler | `0.8.18` (pinned, no floating pragma) |
| Foundry dependencies | forge-std `v1.7.1`, openzeppelin-contracts `v4.9.3`, chainlink-brownie-contracts `0.6.1`, foundry-devops `0.0.11` |
| Chains | Ethereum |
| In scope | `src/PasswordStore.sol` |
| Out of scope | `test/`, `script/` |
| Events | `SetNetPassword()` emitted on password update |

**Roles / permissions**

| Role | Assigned to | Permissions |
|---|---|---|
| `s_owner` | `msg.sender` at construction (deployer) | Set password, read password |

**Environment variables** — names only, never values

| Variable | Purpose |
|---|---|
| `PRIVATE_KEY` | Deployer key for Sepolia |
| `SEPOLIA_RPC_URL` | Sepolia RPC endpoint |
| `ETHERSCAN_API_KEY` | Contract verification |

---

*Client: PasswordStore · Onboarding completed 2026-11-06*