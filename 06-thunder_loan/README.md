# Section 6 — Thunder Loan Audit

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Days:** 17–18 &nbsp;·&nbsp; **Type:** Hands-on audit
**Goal:** Audit Thunder Loan, an upgradeable flash loan protocol — static analysis first, then manual review.

← Back to [Smart Contract Security](../README.md)

---

## Day 17 — Section 6 kicked off: onboarding & static analysis

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Flash loan** | A loan that has to be borrowed and repaid inside a single transaction, with no collateral at all. |
| 2 | **Arbitrage** | Buying an asset where it is cheap and selling it where it is expensive, to close the price gap. |
| 3 | **Why they fit together** | Arbitrage needs capital, and a flash loan provides it for one transaction with no money upfront. |
| 4 | **Static analysis comes first** | Before reading any code by hand, run the analyzers. They map the codebase and flag known patterns in seconds. |
| 5 | **Upgradeable protocol** | The repo ships both `protocol/ThunderLoan.sol` and `upgradedProtocol/ThunderLoanUpgraded.sol`, so the storage layout across an upgrade is part of the audit surface. |
| 6 | **Known issues list** | The client documents what they already know about, so those items are not findings. |

### Flash loan vs arbitrage

| Concept | In one line | Example |
|---|---|---|
| **Flash loan** | Borrow and repay inside one transaction, no collateral, and if it is not repaid the whole transaction reverts. | A bot borrows `1M USDC` for a single transaction, uses it, and repays the loan plus the fee before the transaction ends. If it cannot repay, nothing happens at all. |
| **Arbitrage** | Profit from the same asset having two prices at the same time. | ETH is `$2,000` on DEX A and `$2,010` on DEX B, so you buy on A and sell on B and keep the difference minus fees. |

Together they are capital free arbitrage: the flash loan supplies the money, the arbitrage makes the profit, and the repayment happens in the same transaction.

### The client repo & onboarding

- Cloned the client repo into [`thunder-loan/`](thunder-loan/)
- **Commit:** the client README lists `026da6e73fde0dd0a650d623d0411547e3188909`, but I worked from `8803f851f6b37e99eab2e94b4690c8b70e26b3f6`. Its `src/` is **identical** to the repository tip, so the audited source is the latest one, and the README hash is stale exactly like Sections 4 and 5

```bash
git checkout 8803f851f6b37e99eab2e94b4690c8b70e26b3f6   # the commit to audit
git switch -c audit-by-ayaan                             # create and move to the working branch
```

> `git branch audit-by-ayaan` only *creates* the branch and leaves you on the detached commit. `git switch -c` creates it **and** moves you onto it.

- **Scope** per the client README: `interfaces/IThunderLoan.sol`, `protocol/ThunderLoan.sol` and `upgradedProtocol/ThunderLoanUpgraded.sol`. The repo also ships a `scope.txt` that lists the whole `src/` tree
- **Roles:** the owner (can upgrade the implementation), liquidity providers (deposit assets to earn interest), and users (take out flash loans)
- **Known issues:** zero fees on very small flash loans, an unfair advantage for the first depositor, and weird ERC20s breaking the protocol. Documented by the client, so not findings
- Copied the [`templates/`](templates/) folder over from Section 5, since the report will be built from it later

### Static analysis, before manual review

| Tool | Command | Result |
|---|---|---|
| **Slither** | `make slither` | 26 contracts, 101 detectors, 7 results: `reentrancy-balance`, `reentrancy-benign`, `reentrancy-events` and `events-maths` |
| **Aderyn** | `aderyn .` | [`thunder-loan/report.md`](thunder-loan/report.md) with 2 High and 9 Low |

Aderyn's Highs are `ETH transferred without address checks` and `Reentrancy: State change after external call`. The Low set is `L-1` centralization risk, `L-2` empty block, `L-3` PUSH0 opcode, `L-4` state change without event, `L-5` address state variable set without checks, `L-6` unchecked return, `L-7` unused error, `L-8` unused import, `L-9` public function not used internally.

Every one of these is a lead, not a severity. They get read, triaged and either written up or dropped during the manual review.

### Day 17 — Key takeaways

1. **Flash loans are atomic.** The repayment is not a promise, it is a condition of the transaction.
2. **Arbitrage is the classic flash loan use case.** The loan removes the capital requirement, nothing more.
3. **Static analysis is the first pass, not the audit.** The tools map the code and hand you leads; the manual review decides what is real.
4. **Check the commit before reading a line of code.** A stale hash means you audited something different from what the client thinks.
5. **Read the known issues list first.** The client's documented items are not findings, and re-reporting them wastes everyone's time.

---

## Day 18 — Manual review: the interface files

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Interfaces are in scope too** | A one-line interface can hide a real mismatch with the contract that is supposed to implement it. |
| 2 | **An interface nothing implements is not an ABI** | `IThunderLoan` is declared but no contract inherits it, so nothing enforces it. |
| 3 | **Type differences can be invisible** | `address` and `IERC20` encode the same way, so the mismatch never shows up on-chain. |
| 4 | **Callback interfaces need natspec** | Undocumented parameters on `executeOperation` are exactly how integrator bugs happen. |
| 5 | **Some things are questions, not bugs** | The price source and the TSwap dependency are design decisions the team has to answer, so they went in as questions. |
| 6 | **Info and Question findings need no proof** | For that tier a description is enough, no Impact, no proof of concept, no mitigation. |

### Findings from the interface pass

| ID | Type | Finding |
|---|---|---|
| `Q-1` | Question | every asset is priced only through its own TSwap WETH pool |
| `Q-2` | Question | the fee maths depends on TSwap, a less proven AMM than Uniswap |
| `I-1` | Informational | unused `IThunderLoan` import in `IFlashLoanReceiver` |
| `I-2` | Informational | no natspec on the `IFlashLoanReceiver::executeOperation` parameters |
| `I-3` | Informational | `IThunderLoan` is never implemented and its `repay` type differs from `ThunderLoan` |

All five live in [`audit_data/findings.md`](audit_data/findings.md), written in the `H` / `Q` / `I` order the layout uses, so the Highs and Mediums will slot in above them as the review goes on.

### What I actually did

1. **Read all four interface files** line by line and tagged every issue inline with `@AUDIT-info` or `@AUDIT-q`
2. **Checked the implementation behind each tag**, confirmed that nothing implements `IThunderLoan`, and traced how `OracleUpgradeable` prices an asset through `IPoolFactory` and `ITSwapPool`
3. **Wrote the five findings up** in `findings.md`, description only
4. **Turned two design decisions into questions** for the team instead of assuming the intent

> Short session today, an assignment took most of it. The manual review continues with the protocol contracts next.

### Day 18 — Key takeaways

1. **Read the interfaces first.** They are the cheapest place to find a mismatch, and they show what the rest of the code expects.
2. **Check who implements an interface.** If nobody does, it is documentation that no compiler verifies.
3. **Ask about intent, do not assume it.** Both questions today are design decisions, not code bugs.
4. **Info and Question findings are descriptions.** No Impact, no proof of concept, no mitigation.
5. **Short days still count.** One file group reviewed and written up properly.

---

*Days 17–18 of my [smart contract security journey](../README.md). Section 6 — audit in progress.*
