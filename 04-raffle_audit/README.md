# Section 4 — Puppy Raffle Audit

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Days:** 5–6 &nbsp;·&nbsp; **Type:** Hands-on audit
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

## Day 6 — Proving DoS & learning reentrancy

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Version pinning bites** | The client's pinned `forge-std` was too old: `vm.txGasPrice` needs v1.6.0+, and its legacy `console.log(string, uint)` silently emitted nothing. |
| 2 | **A PoC turns a hunch into a finding** | Spotting the DoS in the code wasn't enough — the gas-measuring test is what made it provable. |
| 3 | **Reentrancy** | The contract makes an external call *before* updating its own state, so the attacker re-enters and drains it. |
| 4 | **The CEI pattern** | Checks (validate) → Effects (update state) → Interactions (external calls **last**). The industry-standard ordering. |
| 5 | **ReentrancyGuard** | OpenZeppelin's `nonReentrant` modifier blocks re-entrant calls — one reason reentrancy is much rarer today. |
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

### Reentrancy — the concept

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
6. **Learned reentrancy** from `ReEntrancy.sol`, then found the same flaw in the client's `refund` function
7. **Wrote up `H-2`** (reentrancy) and tagged it `// @AUDIT-HIGH::`

> 📌 Carried over from Day 5: **3 open questions** tagged `// @AUDIT-q::` in the client contract. Not findings — things to ask the team, still unresolved.

### Day 6 — Key takeaways

1. **A finding isn't a finding until you can prove it.** The gas-diff test is what made the DoS credible.
2. **Dependencies are part of the audit surface.** A stale `forge-std` cost real time and silently swallowed every log.
3. **Reentrancy is an ordering bug.** External call first, state change second, is the entire vulnerability.
4. **CEI is the habit; ReentrancyGuard is the seatbelt.** Use both.
5. **This section is big.** DoS and reentrancy down, plenty still to go.

---

*Days 5–6 of my [smart contract security journey](../README.md). Section 4 — audit in progress.*