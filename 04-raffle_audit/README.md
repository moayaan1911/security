# Section 4 — Puppy Raffle Audit

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Day:** 5 &nbsp;·&nbsp; **Type:** Hands-on audit
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

> 🔒 [`audit_notes.md`](audit_notes.md) is my private scratchpad — never sent to the client.
> 📁 `audit_data/` is the folder that gets shared with the client at the end — still empty for now.

### Day 5 — Key takeaways

1. **Automated tools first.** They map a codebase in seconds, which matters far more as contracts get bigger.
2. **Colour is triage, not truth.** Green findings still get read; red findings still get verified by hand.
3. **DoS is a design flaw, not an exploit.** Nothing is stolen — availability is destroyed.
4. **Unbounded loops over growing arrays** are the classic DoS shape to hunt for.
5. **Hard material needs rewatches.** The DoS lesson took several passes — that's normal, not a sign you're behind.

---

*Day 5 of my [smart contract security journey](../README.md). Section 4 — audit in progress.*