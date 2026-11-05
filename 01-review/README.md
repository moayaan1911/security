# Day 1 — Section 1 Revision

**Status:** ✅ Section 1 complete &nbsp;·&nbsp; **Type:** Revision / recap
**Goal:** Re-solidify the Solidity fundamentals I already knew *before* starting actual smart contract auditing.

← Back to [Smart Contract Security](../README.md)

---

## Concepts revised

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **ERC20** | The fungible token standard — `transfer`, `approve`/`transferFrom`, `balanceOf`, `totalSupply`, plus `Transfer`/`Approval` events. |
| 2 | **Installing OpenZeppelin** | `forge install OpenZeppelin/openzeppelin-contracts` + a remapping, giving you audited implementations instead of hand-rolled ones. |
| 3 | **Fuzz testing** | Foundry throws random inputs at one function and asserts your property holds for every single run. |
| 4 | **Invariant testing** | Foundry calls random functions in random order and asserts a property holds in *every reachable state*, not just one call. |
| 5 | **ERC721** | The non-fungible standard — each `tokenId` has exactly one owner; `ownerOf`, `safeTransferFrom`, `tokenURI`, `setApprovalForAll`. |
| 6 | **Storage** | Permanent on-chain state, packed into 32-byte slots — the single most expensive thing you can write to. |
| 7 | **Constants** | `constant` and `immutable` are baked into bytecode, **never** occupy a storage slot, so reading them costs no `SLOAD` gas. |
| 8 | **fallback & receive** | Backup functions: `receive()` takes plain ETH, `fallback()` handles calls to functions that don't exist. |
| 9 | **abi.encode & abi.encodePacked** | Two ways to serialize data — one is padded and collision-safe, the other is tightly packed and collision-prone. |
| 10 | **abi.decode** | The inverse of encoding: turns raw ABI-encoded `bytes` back into real typed values. |
| 11 | **call & staticCall** | Low-level external calls — one is allowed to mutate state, the other is enforced read-only. |
| 12 | **abi.encodeWithSignature** | Builds a 4-byte function selector plus encoded arguments so `call` can invoke a function by name. |
| 13 | **selfdestruct** | Sends the contract's ETH to a target address and — much more rarely than it used to — deletes the code. |
| 14 | **Upgradeable contracts (proxies)** | `delegatecall` lets you swap logic while preserving storage; extremely powerful and extremely easy to break. |

---

## Comparison tables

### `fallback` vs `receive`

Both are **backup functions** — they run when the contract has no normal function to handle the call.

| | `receive()` | `fallback()` |
|---|---|---|
| **When it runs** | Someone sends **only ETH** (no function name, no data) | Someone calls a **function that doesn't exist** |
| **ETH sent *with* data** | **Never runs** — only reacts to empty calldata | Runs **only if** the data matches no real function |
| **Can accept ETH?** | Yes, always (it must be `payable`) | Only if you write `payable` |

**What runs when — full order:**

1. Calldata **empty**? → `receive()`. No `receive()`? → `fallback()`. Neither? → **revert**
2. Calldata **matches a real function**? → that function runs — `fallback()` is **not** used
3. Calldata matches **nothing**? → `fallback()`. No `fallback()`? → **revert**
4. ETH attached to a **non-payable** function? → **revert**

```solidity
// empty calldata + ETH            -> receive()
addr.call{value: 1 ether}("");

// unknown function + ETH          -> fallback()
addr.call{value: 1 ether}(abi.encodeWithSignature("doesNotExist()"));

// real function + ETH             -> that function runs, NOT fallback()
addr.call{value: 1 ether}(abi.encodeWithSignature("known()"));
```

> Proof for all 6 cases: [`src/FallbackDemo.sol`](src/FallbackDemo.sol) + [`test/FallbackDemo.t.sol`](test/FallbackDemo.t.sol).

---

### `abi.encode` vs `abi.encodePacked`

| | `abi.encode` | `abi.encodePacked` |
|---|---|---|
| **Padding** | Every argument padded to 32 bytes | Tightly packed, no padding |
| **Safe for hashing?** | Yes | **No** — collision risk with 2+ dynamic args |

> `abi.encodePacked("a","bc")` == `abi.encodePacked("ab","c")` ⇒ same hash ⇒ signature forgery.

---

### `call` vs `staticCall`

| | `call` | `staticCall` |
|---|---|---|
| **Can modify state** | Yes | **No** — reverts if the callee tries |
| **Can send ETH** | Yes, via `{value: x}` | No |

> Both return `(bool success, bytes data)` and **neither reverts on failure** — always check `success`. `delegatecall` is the third sibling (proxy pattern).

---

### Storage vs `constant` / `immutable`

| | Storage variable | `constant` / `immutable` |
|---|---|---|
| **Lives in** | A storage slot | Bytecode — no slot at all |
| **Read cost** | ~2100 gas (cold `SLOAD`) | ~free |

> `constant` is set at compile time, `immutable` once in the constructor. Neither ever touches storage.

---

## Key takeaways from Day 1

1. **Automated testing is an auditor's main weapon** — fuzz tests check *inputs*, invariants check *states*. Learn invariant testing properly, not just `testFuzz_`.
2. **`abi.encodePacked` + `keccak256` is a real vulnerability class**, not a trivia question. It shows up in signature verification and `permit`-style flows.
3. **Low-level calls fail silently.** `call`/`staticCall` return a `bool`; unchecked, it becomes a silent no-op instead of a revert.
4. **`fallback`/`receive` decide whether your contract can even hold ETH** — a missing `receive()` is a legitimate denial-of-service vector against other protocols.
5. **Gas optimizations and security often pull in opposite directions** — `encodePacked` is cheaper *and* less safe. Know which one you're choosing.

---

*Day 1 of my [smart contract security journey](../README.md). Section 1 complete — auditing starts next.*
