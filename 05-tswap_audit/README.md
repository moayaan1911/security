# Section 5 — TSwap Audit

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Days:** 10 &nbsp;·&nbsp; **Type:** Hands-on audit
**Goal:** Audit TSwap, a Uniswap V1 fork — onboarding first, then test coverage and manual review.

← Back to [Smart Contract Security](../README.md)

---

## Day 10 — Onboarding TSwap & how AMMs work

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **AMM (Automated Market Maker)** | Trades go against a pool of tokens that prices itself with a formula, instead of matching buyers and sellers. |
| 2 | **Order book limitation** | Order books are gas-expensive and simply do not scale on-chain, which is why AMMs were invented. |
| 3 | **Liquidity pools** | Anyone can trade against the pool at any time. No counterparty, no confirmation from other users, no central entity. |
| 4 | **Constant product formula** | The pool prices swaps along `x * y = k`, so buying one token pushes its price up and the other down. |
| 5 | **Liquidity providers** | They deposit both tokens into the pool and receive LP shares, which earn a cut of the trading fees. |
| 6 | **LP risk** | Fees are the upside. The downside is real money: if one token in the pool collapses, the loss can dwarf everything earned. |
| 7 | **Onboarding as a signal** | A client that fills in extensive onboarding questions properly shows professionalism, and it decides how much you can trust the docs. |

### Order book vs AMM

| | Order book | AMM |
|---|---|---|
| **How it works** | Buyers and sellers post orders, the exchange matches them | Trades execute against a liquidity pool, priced by a formula |
| **Why AMMs won** | Every order costs gas, the book does not scale on-chain | Anyone can trade any time, no counterparty needed |

### Liquidity providers

| They provide | They receive | Their risk |
|---|---|---|
| Both tokens, deposited into the pool | LP shares, plus a cut of the fees from every swap | If one token collapses, the loss can be far bigger than the fees earned |

Being an LP is not free yield. You are long both assets in the pool, and you eat the loss when one of them breaks.

### The client repo & onboarding

- Cloned [`https://github.com/Cyfrin/5-t-swap-audit.git`](https://github.com/Cyfrin/5-t-swap-audit.git) as `tswap`
- The repo ships a blank `extensive-onboarding-questions.md`, answered by the team in `t-swap-onboarded.md`
- Copied the blank sample into [`templates/`](templates/) so I can reuse it on future engagements
- **Stale commit hash again** — the README pointed at an old commit, so I stayed on the latest commit and worked from a new branch `audit-by-ayaan`, same as Section 4
- **Scope:** `src/PoolFactory.sol` and `src/TSwapPool.sol`
- **`forge coverage` showed very thin test coverage**, so the tests themselves are part of the audit surface

### Section folder

| Path | What it is |
|---|---|
| [`templates/`](templates/) | `findings_layout.md`, `report_example.md`, `report_example.html`, `extensive-onboarding-questions.md`, `profile.jpeg` |
| [`tswap/`](tswap/) | the client repo, tracked as plain files |
| [`audit_notes.md`](audit_notes.md) | private self-notes, never shared |

### What I actually did

1. **Cloned the client repo** as `tswap` and read its README before touching the code
2. **Skipped the stale commit hash** and created the working branch `audit-by-ayaan`
3. **Ran `forge coverage`** and found very little of the protocol is exercised by the existing tests
4. **Moved the template files into `templates/`** to keep the section folder clean, logo included
5. **Read the onboarding answers** in `t-swap-onboarded.md` and wrote up what TSwap actually is

### Day 10 — Key takeaways

1. **AMMs exist because order books do not scale on-chain.** Gas, not ideology, is the reason.
2. **A liquidity pool has no counterparty.** Anyone can trade whenever they want, which is the whole point.
3. **LP shares are a claim on the pool plus fees**, not a guaranteed return.
4. **Being an LP is a financial risk, not yield.** One token collapsing can take more than the fees ever paid.
5. **Onboarding quality tells you a lot.** A team that answers extensive questions properly is a team whose docs you can start to trust.
6. **Thin test coverage is a finding in itself.** If the protocol is barely tested, every invariant is unproven.

---

*Day 10 of my [smart contract security journey](../README.md). Section 5 — audit in progress.*
