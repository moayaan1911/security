# Section 4 — Puppy Raffle Audit

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Days:** 5–8 &nbsp;·&nbsp; **Type:** Hands-on audit
**Goal:** Audit a bigger contract than PasswordStore — starting with automated tooling, then manual review.

← Back to [Smart Contract Security](../README.md)

---

## Day 5 — Static analysis tools & DoS fundamentals

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Scope hash isn't always the latest** | This client's README pointed at an old commit — the course says stay on the latest commit and work from a new branch instead. |
| 2 | **Slither** | Python static analyzer (`uv tool install slither-analyzer`) that prints colour-coded findings straight to the terminal. |
| 3 | **Aderyn** | Cyfrin's Rust static analyzer (`npm install @cyfrin/aderyn -g`) that writes a near-ready audit report as `report.md`. |
| 4 | **Colour triage** | Red = look immediately, yellow = check carefully, green = informational/low but still review in a deep audit. |
| 5 | **Denial of Service (DoS)** | An attacker makes an action so gas-expensive that legitimate users can no longer perform it. |
| 6 | **Tools map, humans find** | Static analyzers give you a map of the codebase fast — they don't replace manual review. |

### Comparison tables

**Slither vs Aderyn**

| | Slither | Aderyn |
|---|---|---|
| **Built with / by** | Python — Trail of Bits | Rust — Cyfrin |
| **Output** | Colour-coded terminal findings | Writes `report.md`, a near-ready audit report |

### Reading Slither's output

| Colour | Risk | What I do |
|---|---|---|
| 🔴 Red | High | Investigate immediately |
| 🟡 Yellow | Medium | Check carefully, verify by hand |
| 🟢 Green | Informational / low | Not urgent, but still worth reviewing in a deep audit |

### DoS — the concept

An attacker doesn't steal anything. They make the protocol **unusable for everyone else** by making an operation cost more gas than a normal user can pay.

The teaching example lives in [`DoS.sol`](DoS.sol):

```solidity
function enter() public {
    // Check for duplicate entrants
    for (uint256 i; i < entrants.length; i++) {
        if (entrants[i] == msg.sender) {
            revert("You've already entered!");
        }
    }
    entrants.push(msg.sender);
}
```

Every new entrant loops over **all** previous entrants. The array only ever grows, so the gas cost of `enter()` grows with it. An attacker entering from many addresses inflates the array until legitimate users can't afford to enter at all — a DoS with no exploit and no stolen funds, just a broken design.

> The course also walked through real audits where this pattern showed up: **GMX V2** and **Bridges Exchange**.

### What I actually did

1. **Cloned** the `puppy-raffle` client repo using the command in *their* README
2. **Skipped their commit hash** — it was stale, so I stayed on the latest commit and created a working branch `audit-by-ayaan`
3. **Installed Slither** with `uv tool install slither-analyzer`
4. **Ran `slither .`** inside the client repo → a large colour-coded report
5. **Installed Aderyn** with `npm install @cyfrin/aderyn -g` (both `curl` methods timed out, so npm it was)
6. **Ran `aderyn .`** → generated [`report.md`](puppy-raffle/report.md), a near-ready audit report
7. **Installed the Solidity Visual Developer** VSCode extension
8. **Studied DoS separately first** via `DoS.sol`, *then* went back to see how the client's contract uses it
9. **Tagged 3 open questions** in the client contract with `// @AUDIT-q::` — things to ask the team, not findings

> 🔒 [`audit_notes.md`](audit_notes.md) is my private scratchpad — never sent to the client.
> 📁 `audit_data/` is the folder that gets shared with the client at the end — still empty for now.

### Day 5 — Key takeaways

1. **Automated tools first.** They map a codebase in seconds, which matters far more as contracts get bigger.
2. **Colour is triage, not truth.** Green findings still get read; red findings still get verified by hand.
3. **DoS is a design flaw, not an exploit.** Nothing is stolen — availability is destroyed.
4. **Unbounded loops over growing arrays** are the classic DoS shape to hunt for.
5. **Hard material needs rewatches.** The DoS lesson took several passes — that's normal, not a sign you're behind.

---

## Day 6 — Proving DoS & learning ReEntrancy

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Version pinning bites** | The client's pinned `forge-std` was too old: `vm.txGasPrice` needs v1.6.0+, and its legacy `console.log(string, uint)` silently emitted nothing. |
| 2 | **A PoC turns a hunch into a finding** | Spotting the DoS in the code wasn't enough — the gas-measuring test is what made it provable. |
| 3 | **ReEntrancy** | The contract makes an external call *before* updating its own state, so the attacker re-enters and drains it. |
| 4 | **The CEI pattern** | Checks (validate) → Effects (update state) → Interactions (external calls **last**). The industry-standard ordering. |
| 5 | **ReentrancyGuard** | OpenZeppelin's `nonReentrant` modifier blocks re-entrant calls — one reason ReEntrancy is much rarer today. |
| 6 | **Templates pay off** | Reusing `finding_layout.md` from Section 3 made writing the report almost mechanical. |

### DoS: from hunch to proof

The `@AUDIT` tags pointed at the loop; the test proved it. Same operation, two batches of 100 players:

| Batch | Gas used |
|---|---|
| First 100 players | `6,538,557` |
| Second 100 players | `19,242,109` |
| **Difference** | **`12,703,552`** |

Nearly **3× the gas for the exact same work**, because the duplicate check loops over every player already in the array.

> Test: `test_DenialOfService_AUDIT` in `PuppyRaffleTest.t.sol` · written up as **`H-1`** in [`audit_data/findings.md`](audit_data/findings.md)

### ReEntrancy — the concept

The teaching example in [`ReEntrancy.sol`](ReEntrancy.sol) shows the flaw in a few lines:

```solidity
function withdrawBalance() public {
    uint256 balance = userBalance[msg.sender];
    // An external call and then a state change!
    (bool success, ) = msg.sender.call{value: balance}("");
    if (!success) {
        revert();
    }

    userBalance[msg.sender] = 0;   // state change comes too late
}
```

The attacker's `receive()` calls back into `withdrawBalance()` before their balance is zeroed. The function still sees the old balance, pays out again, and keeps paying until the contract is drained.

> This was one of the most common loopholes in early contracts. It's far rarer now thanks to [OpenZeppelin's `ReentrancyGuard`](https://docs.openzeppelin.com/contracts/3.x/api/utils#ReentrancyGuard) and better security practice.

### Stopping it: the CEI pattern

| Step | What you do |
|---|---|
| **C — Checks** | Validate everything up front (`require`, `if/else`) |
| **E — Effects** | Update your own state variables |
| **I — Interactions** | Make external calls **last** |

Reorder the function so the state change happens *before* the external call, and re-entry hits a zero balance.

### What I actually did

1. **Published the blog** about my first audit (PasswordStore)
2. **Finished the DoS lecture** and located the issue in the client's `enterRaffle`
3. **Wrote `test_DenialOfService_AUDIT`** to prove it, comparing gas across two batches of players
4. **Hit a tooling wall** — the pinned `forge-std` was too old, so `vm.txGasPrice` didn't exist and legacy `console.log(string, uint)` printed nothing at all
5. **Wrote up `H-1`** (DoS) in `audit_data/findings.md`, following the `finding_layout.md` template
6. **Learned ReEntrancy** from `ReEntrancy.sol`, then found the same flaw in the client's `refund` function
7. **Wrote up `H-2`** (ReEntrancy) and tagged it `// @AUDIT-HIGH::`

> 📌 Carried over from Day 5: **3 open questions** tagged `// @AUDIT-q::` in the client contract. Not findings — things to ask the team, still unresolved.

### Day 6 — Key takeaways

1. **A finding isn't a finding until you can prove it.** The gas-diff test is what made the DoS credible.
2. **Dependencies are part of the audit surface.** A stale `forge-std` cost real time and silently swallowed every log.
3. **ReEntrancy is an ordering bug.** External call first, state change second, is the entire vulnerability.
4. **CEI is the habit; ReentrancyGuard is the seatbelt.** Use both.
5. **This section is big.** DoS and ReEntrancy down, plenty still to go.

---

## Day 7 — Weak randomness, overflow & a finished findings report

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Weak randomness** | `keccak256(msg.sender, block.timestamp, block.difficulty)` is not random — all three inputs are public, and the block producer picks two of them. |
| 2 | **Grinding** | An attacker brute-forces a public input (the timestamp, the difficulty) until the "random" output lands in their favour. |
| 3 | **Off-chain randomness** | Real fairness needs a verifiable oracle like Chainlink VRF, where the number is unknown until it is used and cannot be tampered with. |
| 4 | **Arithmetic overflow** | On Solidity 0.7.x, `+` wraps around silently instead of reverting. SafeMath existed for exactly this reason. |
| 5 | **Unsafe casting** | `uint64(fee)` truncates instead of reverting, and it still truncates on 0.8+ because the built-in checks only cover arithmetic. |
| 6 | **Ambiguous return values** | A function returning `0` for "not found" collides with a valid index `0`. |

### Today's teaching examples

**Weak randomness** — [`WeakRandomness.sol`](WeakRandomness.sol) does exactly what the client contract does:

```solidity
keccak256(abi.encodePacked(msg.sender, block.prevrandao, block.timestamp))
```

All three values are public or chosen by the block producer, so anyone can predict the result, and a block producer can grind it. The real fix is an oracle like [Chainlink VRF](https://docs.chain.link/vrf), where the random value is not known when the transaction is submitted.

**Overflow / underflow / precision loss** — [`Arithmatic.sol`](Arithmatic.sol) shows the three ways integer maths goes wrong:

| Example | What happens |
|---|---|
| `Overflow` | `uint8` 255 + 1 becomes `0` |
| `Underflow` | `uint8` 0 - 1 becomes `255` |
| `PrecisionLoss` | `225 / 4` returns `56`, not `56.25` |

### The findings from today

| ID | Severity | Finding |
|---|---|---|
| `I-1` | Informational | `getActivePlayerIndex` returns `0` for inactive players |
| `H-3` | High | Weak randomness in `selectWinner` lets an attacker hand-pick the winner |
| `M-1` | Medium | `totalFees` overflows and wraps around |
| `M-2` | Medium | `uint64(fee)` silently truncates the recorded fee |
| `Q-1` | Question | Is the 80/20 winner-to-fee split intended? |

All five live in **[`audit_data/findings.md`](audit_data/findings.md)**.

### Tests written today

| Test | What it proves |
|---|---|
| `test_GetActivePlayerIndex_AUDIT` | An inactive player and the real index-0 player both come back as `0` |
| `test_WeakRandomness_AUDIT` | The attacker grinds the timestamp until they win |
| `test_ArithmeticOverflow_AUDIT` | Two 12 ETH fees record as 5.55 ETH instead of 24 ETH |
| `test_UnsafeCasting_AUDIT` | A 20 ETH fee records as 1.55 ETH |

### What I actually did

1. **Found the index-0 question** while reading `getActivePlayerIndex` — inactive players return `0`, which is also a perfectly valid index
2. **Studied weak randomness** through `WeakRandomness.sol`, then mapped it onto `selectWinner`
3. **Studied overflow** through `Arithmatic.sol` before looking at `totalFees`
4. **Wrote the weak randomness test** using DeepSeek Harness, so I could see exactly how the grind works instead of just copying it
5. **Wrote the other tests myself** and added all five findings to the report

### Day 7 — Key takeaways

1. **Block values are not randomness.** If a contract claims "random" and uses `block.*`, an attacker can grind it.
2. **Narrowing casts never revert.** `uint64(x)` silently drops the high bits, even on Solidity 0.8.
3. **Small types cause big bugs.** `uint64` for a wei amount is a bug waiting for enough volume.
4. **Ambiguous APIs are still bugs.** Returning `0` for "not found" is unsafe when `0` is valid.
5. **Findings are done, the section isn't.** Five written up, but Section 4 still has more code to review.

---

## Day 8 — Questions in the code & mishandling of ETH

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Questions are findings too** | `// @AUDIT-q` tags anything unclear, even something small. An audit is not only a bug hunt. |
| 2 | **Never assume, always ask** | Every confusion goes to the client as a question. Clearing the small ones is what uncovers the bigger bug later. |
| 3 | **Mishandling of ETH** | A contract that assumes its ETH balance can only change through its own functions. |
| 4 | **Forced ETH** | `selfdestruct` pushes ETH into a target without calling it, so a `receive` or `fallback` cannot stop it. |
| 5 | **Strict balance checks break** | `address(this).balance == totalFees` becomes permanently false once extra ETH lands, locking `withdrawFees` forever. |
| 6 | **Slither suppressions** | `// slither-disable-next-line <detector>` silences one detector, and only once the auditor has verified it is a false positive. |
| 7 | **Tag lifecycle** | If the code or the language already answers a question, it is not a client question. Convert it to a finding tag, or delete it. |

### Mishandling of ETH — the concept

The teaching example lives in [`MishandlingEth.sol`](MishandlingEth.sol). The contract only lets ETH in through `deposit()`, so it *assumes* a strict equality always holds:

```solidity
assert(address(this).balance == totalDeposits); // bad
```

Anyone can break that assumption without interacting with the contract at all:

```solidity
function attack() external payable {
    selfdestruct(payable(address(target)));
}
```

`selfdestruct` adds the ETH to the target's balance and never runs a line of the target's code, so there is nothing that can reject it. That is why the fix is never a `receive()` that reverts, it is to stop trusting `address(this).balance`.

The same pattern sits in the client's `withdrawFees`:

```solidity
require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
```

A single selfdestruct breaks the equality forever, so the feeAddress can never withdraw its fees again.

> PoC: `test_MishandlingOfETH_AUDIT` + `ETHForcer` in `PuppyRaffleTest.t.sol` · written up as **`H-4`** in [`audit_data/findings.md`](audit_data/findings.md)

### Findings written today

| ID | Severity | Finding |
|---|---|---|
| `H-4` | High | Mishandling of ETH: forced ETH locks the fees in `withdrawFees` forever |
| `L-1` | Low | Loop based membership check in `_isActivePlayer`, a mapping would be cheaper |
| `Q-1` | Question | An empty players array is accepted in `enterRaffle` |
| `I-2` – `I-9` | Informational | Floating pragma, non-constant image URIs, constructor zero checks, empty-array event, cached array length, magic numbers, zero address check, unused function |

> The Day 7 `Q-1` about the 80/20 split turned out to be documented in the contract's own natspec, so it was refiled as the magic numbers Info (`I-7`), and `Q-1` was reused for the empty players array question.

### Tests written today

| Test | What it proves |
|---|---|
| `test_MishandlingOfETH_AUDIT` | A forced transfer breaks the balance equality, so `withdrawFees` reverts forever |
| `test_LoopBasedMembershipCheck_AUDIT` | The same lookup costs about 9x more gas with 100 players than with 10 |

### What I actually did

1. **Reviewed every `@AUDIT` tag** in the contract and triaged it: answered by the code, code quality, or a genuine question for the client
2. **Studied mishandling of ETH** through `MishandlingEth.sol`, then found the same flaw in the client's `withdrawFees`
3. **Wrote the selfdestruct PoC** to prove the fees are locked permanently
4. **Ran `slither .`** as a final sweep over the contract and triaged the output
5. **Added `// slither-disable-next-line arbitrary-send-eth`** on the fee payout, where the detector is a false positive because `feeAddress` is owner controlled
6. **Ran `aderyn .`** after the Slither pass for a final automated report
7. **Wrote up the remaining findings**, rewrote `Q-1`, and reordered `findings.md` into H → M → L → Q → I

### Day 8 — Key takeaways

1. **A question is a finding in waiting.** Clarifying the small ones is how the big ones show up.
2. **Never assume the client's intent.** If it is not written down, it is a question, not a fact.
3. **Never trust `address(this).balance`.** ETH can always be forced in, so track what you owe in your own variable and compare with `>=`, never `==`.
4. **A suppression is a claim you have to defend.** `slither-disable-next-line` should only silence something verified by hand.
5. **Keep the code and the report in sync.** Every `@AUDIT` tag should have a finding behind it, and every finding a tag.
6. **Layout is part of the deliverable.** H → M → L → Q → I puts the worst news first.

---

*Days 5–8 of my [smart contract security journey](../README.md). Section 4 — audit in progress.*
