# Section 5 — TSwap Audit

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Days:** 10–13 &nbsp;·&nbsp; **Type:** Hands-on audit
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

## Day 11 — Stateless fuzzing vs invariant testing

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Stateless fuzzing** | The test calls one function with random inputs, and every run starts from a fresh state. |
| 2 | **Stateful fuzzing (invariant testing)** | One run is a whole flow: many functions, random inputs, random senders, all against the same state. |
| 3 | **Invariant** | A property that must hold in every reachable state, asserted after every call in the sequence. |
| 4 | **runs** | How many random inputs a stateless test gets, or how many independent sequences an invariant test tries. |
| 5 | **depth** | How many function calls happen inside a single sequence, so how deep one shared state gets explored. |
| 6 | **fail_on_revert** | `true` fails the run as soon as a call reverts, `false` ignores reverts and only checks the invariant. |
| 7 | **Stateless has a ceiling** | Each run starts clean, so it never sees the combined effect of several calls in a row. |

### Stateless fuzzing vs stateful (invariant) fuzzing

| | Stateless fuzzing | Stateful fuzzing (invariants) |
|---|---|---|
| **What runs** | One function per test, random inputs | Many functions, random inputs and senders, in one flow |
| **State between runs** | Reset every run, `setUp` runs again | Carried forward, one run is a sequence of calls |
| **What it proves** | That a single function survives weird inputs | That a property holds across the states the sequence reaches |
| **Foundry config** | `[fuzz] runs = X` | `[invariant] runs = X`, `depth = Y` |
| **Weak spot** | Never sees the combined effect of several calls | Slower, and reverts can hide bugs if you ignore them blindly |

### Configuring both in `foundry.toml`

The client's own [`foundry.toml`](tswap/foundry.toml) already ships an invariant block:

```toml
[fuzz]
runs = 256              # random inputs per stateless test

[invariant]
runs = 256              # independent sequences to try
depth = 32              # calls inside ONE sequence, so one shared state
fail_on_revert = true
```

`depth` is the one to think about: it is how many function calls happen inside a single sequence before the fuzzer starts a new one. Deeper means more complex states, shallower means more independent paths.

`fail_on_revert = true` fails the run the moment any call reverts. Setting it to `false` tells Foundry to ignore reverts and only keep checking the invariant, which is what you want when a revert is a normal outcome of a random sequence.

### Small examples

```solidity
// stateless: random input, one function, fresh state on every run
function testFuzz_DepositSucceeds(uint256 wethToDeposit) public {
    vm.assume(wethToDeposit > 0 && wethToDeposit < 1e30);
    pool.deposit(wethToDeposit, 0, type(uint256).max, uint64(block.timestamp));
}

// stateful: random sequences of deposit, withdraw and swap on the same state
uint256 private kBefore;

function setUp() public {
    kBefore = weth.balanceOf(address(pool)) * poolToken.balanceOf(address(pool));
}

function invariant_KNeverDecreases() public view {
    uint256 k = weth.balanceOf(address(pool)) * poolToken.balanceOf(address(pool));
    assertGe(k, kBefore); // fees only ever push k up
}
```

### What I actually did

1. **Learned the difference between stateless fuzzing and invariant testing**, and why one run in invariant testing is a whole sequence of calls
2. **Read the client's `foundry.toml`** to see the `[invariant]` block they ship: `runs = 256`, `depth = 32`, `fail_on_revert = true`
3. **Wrote down the config keys** (`runs`, `depth`, `fail_on_revert`) with what each one actually controls

### Day 11 — Key takeaways

1. **Stateless fuzzes one function, stateful fuzzes a flow.** The difference is whether state carries over between calls.
2. **Invariants are the real test of an AMM.** Pricing bugs show up when the pool is left in a weird state, not on a single clean call.
3. **`depth` decides how deep one state goes**, `runs` decides how many different paths you try.
4. **`fail_on_revert` is a choice, not a default to ignore.** `false` is only right when reverts are expected.
5. **The section name is `[invariant]`, singular**, in `foundry.toml`.

---

## Day 12 — Handlers, stateful fuzz implementation & weird ERC20s

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Handlers** | A wrapper contract that the fuzzer calls instead of the pool itself, so the call sequence stays realistic. |
| 2 | **Bounded inputs** | The handler clamps random inputs before passing them on, so the fuzzer spends its runs on meaningful states. |
| 3 | **`targetContract`** | Points the invariant fuzzer at the handler, so only the handler's functions get fuzzed. |
| 4 | **Why handlers exist** | Without them most random sequences just revert, and a revert tells you nothing about the invariant. |
| 5 | **Weird ERC20s** | Tokens that break the usual assumptions: no return value on `transfer`, fee-on-transfer, rebasing, multiple entry points. |
| 6 | **Why they matter for an AMM** | TSwap does accounting on two ERC20 balances, so one non standard token can break that accounting or lock funds. |

### Weird ERC20s

Reference list to keep for every future audit: [`d-xo/weird-erc20`](https://github.com/d-xo/weird-erc20). These are the tokens that pass a normal ERC20 mental check and still break an integration, which is exactly the class of bug that only shows up on mainnet.

### First Flight submission

Submitted the Section 4 raffle audit to the CodeHawks **First Flight** review, on top of the competitive audit submitted on Day 9. Two submissions now: one competitive audit, and one review of my own report to see how strangers read it.

### What I actually did

1. **Submitted the raffle audit to CodeHawks First Flight** for review
2. **Learned how handlers fit into stateful fuzzing**, and why an unbounded fuzzer mostly produces reverts
3. **Finished the explanation and implementation** of the stateful fuzz tests with handlers
4. **Read through the weird ERC20 list**, which is now a standing reference for future audits

> Section 5 is still in progress, this was another concept plus testing day. No findings written up yet.

### Day 12 — Key takeaways

1. **Handlers keep invariant fuzzing useful.** Without them the fuzzer burns its runs on reverts instead of states.
2. **Bound the inputs, then fuzz.** Random does not mean unconstrained, and constraints are what make the sequence realistic.
3. **Weird ERC20s break the integration, not the token.** A standard looking token can still break the pool's accounting.
4. **Keep a reference list.** `d-xo/weird-erc20` is a checklist I will run against every future protocol.
5. **First Flight is worth submitting to.** Reading your own report through a stranger's eyes is the fastest way to improve it.
6. **Progress is not completion.** Section 5 still has the manual review and findings ahead.

---

## Day 13 — My first invariant test & the deposit handler

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **No invariant tests is a red flag** | The client shipped unit tests only. Nothing checks the protocol across a sequence of calls. |
| 2 | **Handler** | A contract that wraps the protocol, so the fuzzer calls bounded, realistic actions instead of the raw functions. |
| 3 | **`bound`** | Squashes the fuzzer's random number into a safe range instead of throwing the run away. |
| 4 | **Invariants come from the maths** | The property to test is written from the AMM formula, not from reading the code line by line. |
| 5 | **`getPoolTokensToDepositBasedOnWeth`** | The pool itself tells you how many pool tokens match a WETH deposit, so the handler does not reimplement the ratio. |
| 6 | **Handlers can mint** | These are mock tokens, so the handler can hand the liquidity provider exactly the tokens it needs. |

### The constant product maths, in simple words

```
x * y = k        x = WETH reserve, y = pool token reserve
```

- The pool holds two tokens and keeps `x * y` the same. Take some of one out, you have to put enough of the other in to keep the product equal.
- **Price is just the ratio** `y / x`. Nobody sets the price, the reserves do.
- That is also why slippage exists: a big trade moves the ratio against you, so your average price is worse than the price you saw.
- Fees stay in the pool, so `k` slowly **grows**. That growth is the liquidity provider's profit.
- One line: **jitna ek token nikaloge, utna doosra daalna padega taaki `x * y` same rahe.**

### The `deposit` handler

Written in [`test/invariant/Handler.t.sol`](tswap/test/invariant/Handler.t.sol):

```solidity
function deposit(uint256 _wethAmount) public {
    _wethAmount = bound(_wethAmount, 0, type(uint64).max);
    expectedDeltaY = _wethAmount;
    expectedDeltaX = pool.getPoolTokensToDepositBasedOnWeth(_wethAmount);

    vm.startPrank(liquidityProvider);
    wethToken.mint(liquidityProvider, expectedDeltaY);
    poolToken.mint(liquidityProvider, expectedDeltaX);
    wethToken.approve(address(pool), type(uint256).max);
    poolToken.approve(address(pool), type(uint256).max);

    pool.deposit(expectedDeltaY, 0, expectedDeltaX, uint64(block.timestamp));
    vm.stopPrank();
}
```

Line by line, in simple words:

| Line | What it does |
|---|---|
| `bound(_wethAmount, 0, type(uint64).max)` | Fuzzer ka random number leta hai aur safe range mein le aata hai, taaki run reject na ho. |
| `expectedDeltaY = _wethAmount` | Kitna WETH jaayega, yaad rakha. |
| `getPoolTokensToDepositBasedOnWeth` | Pool se pooch liya ki is WETH ke saath kitne pool tokens chahiye, ratio maintain rakhne ke liye. |
| `startPrank(liquidityProvider)` | Ab aage ke saare calls LP ki taraf se honge. |
| `mint` + `approve` | LP ko exact tokens diye aur pool ko permission di ki wo unhein le sake. |
| `pool.deposit(..., 0, ...)` | Actual deposit. Doosra param `0` hai kyunki handler slippage check nahi kar raha, uska kaam sirf realistic call banana hai. |

> Swap handler kal (Day 14) likhna hai, aur uske baad invariant function aur `targetContract` wiring.

### What I actually did

1. **Read the client repo and found it has unit tests only**, zero invariant tests
2. **Created `test/invariant/`** with [`Invariant.t.sol`](tswap/test/invariant/Invariant.t.sol) (pool setup, `STARTING_X` / `STARTING_Y`) and [`Handler.t.sol`](tswap/test/invariant/Handler.t.sol)
3. **Wrote the `deposit` handler** with a bounded WETH amount and a liquidity provider address
4. **Learned the constant product maths** behind the invariants, so the property comes from the formula
5. **Logged the first observations** in [`audit_notes.md`](audit_notes.md): thin test coverage, no invariant tests at all, and no deadline check in `deposit`

> Section 5 is still in progress. This was the first invariant test and handler, not the finished suite.

### Day 13 — Key takeaways

1. **No invariant tests is a finding in itself.** A protocol holding user funds with no invariant coverage is a red flag.
2. **A handler is the difference between fuzzing a protocol and fuzzing reverts.** Bound the inputs, keep the runs useful.
3. **Write invariants from the maths.** `x * y = k` gives you the property, the code only gives you the implementation.
4. **The pool can tell you the ratio.** `getPoolTokensToDepositBasedOnWeth` keeps the handler honest instead of duplicating the formula.
5. **The deadline in `deposit` is already suspicious.** `withdraw` and `swap` check it, `deposit` does not.

---

*Days 10–13 of my [smart contract security journey](../README.md). Section 5 — audit in progress.*
