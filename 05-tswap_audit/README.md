# Section 5 — TSwap Audit

**Status:** ✅ Complete &nbsp;·&nbsp; **Days:** 10–16 &nbsp;·&nbsp; **Type:** Hands-on audit
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

## Day 14 — Swap handler, fuzzer wiring & a breaking invariant

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Handler wiring** | `new Handler(pool)` plus `targetSelector` and `targetContract` is how the fuzzer learns which contract and which functions it is allowed to call. |
| 2 | **`targetSelector` vs `targetContract`** | One says which functions may be called on the handler, the other says the handler is the contract under test. |
| 3 | **Exact output swap** | `swapExactOutput` asks for a fixed amount out, and pays whatever input the pool quotes for it. |
| 4 | **Early return beats revert** | A handler should `return` when a run is not viable, so the fuzzer does not waste runs on reverts. |
| 5 | **Phase 1 invariant** | Compare expected vs actual deltas first. If the accounting does not match, that is where the bug is. |
| 6 | **A failing invariant is a lead** | Breaking is expected here, but the reason it breaks has to be understood before it becomes a finding. |

### The wiring, line by line

This is the part that looked confusing, from [`Invariant.t.sol`](tswap/test/invariant/Invariant.t.sol):

```solidity
handler = new Handler(pool);

bytes4[] memory selectors = new bytes4[](2);
selectors[0] = handler.deposit.selector;
selectors[1] = handler.swapPoolTokenForWethBasedOnOutputWeth.selector;

targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
targetContract(address(handler));
```

| Line | Simple matlab |
|---|---|
| `new Handler(pool)` | Handler ko pool de diya, ab handler sirf usi pool pe kaam karega. |
| `bytes4[] memory selectors = new bytes4[](2)` | Do functions ke IDs rakhne ke liye khaali list banayi. |
| `handler.deposit.selector` | Us function ka 4 byte ID. Function ko naam se nahi, is ID se bulaya jata hai. |
| `targetSelector(FuzzSelector({...}))` | Fuzzer ko bataya: is handler pe **sirf ye do functions** call karne hain. |
| `targetContract(address(handler))` | Fuzzer ko bataya: target contract handler hai, pool ko seedha call nahi karna. |

Kyun zaruri hai: bina iske fuzzer `setUp` ke baaki contracts (pool, factory, tokens) pe bhi random calls maar sakta hai, aur aisi calls karega jo hamesha revert hongi. Wiring se fuzzing realistic rehti hai.

### The swap handler

From [`Handler.t.sol`](tswap/test/invariant/Handler.t.sol):

```solidity
function swapPoolTokenForWethBasedOnOutputWeth(uint256 _outputWeth) public {
    _outputWeth = bound(_outputWeth, 0, type(uint64).max);

    if (_outputWeth > wethToken.balanceOf(address(pool))) {
        return;
    }

    uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
        _outputWeth,
        poolToken.balanceOf(address(pool)),
        wethToken.balanceOf(address(pool))
    );

    if (poolTokenAmount > type(uint64).max) {
        return;
    }

    expectedDeltaY = int256(-1) * int256(_outputWeth);
    expectedDeltaX = int256(pool.getPoolTokensToDepositBasedOnWeth(poolTokenAmount));

    if (poolToken.balanceOf(swapper) < poolTokenAmount) {
        poolToken.mint(swapper, poolTokenAmount - poolToken.balanceOf(swapper) + 1);
    }

    vm.startPrank(swapper);
    poolToken.approve(address(pool), type(uint256).max);
    pool.swapExactOutput(poolToken, wethToken, _outputWeth, uint64(block.timestamp));
    vm.stopPrank();
}
```

Simple words:

| Step | Kya ho raha hai |
|---|---|
| `bound(...)` | Fuzzer ka random number uint64 range mein le aaye, warna overflow. |
| `return` if output > pool balance | Pool ke paas itna WETH nahi hai, to run chhod do. Revert nahi, warna poora run waste. |
| `getInputAmountBasedOnOutput` | Pool se pooch liya: is output ke liye kitne pool tokens chahiye. |
| `expectedDeltaY / X` | Handler ka hisaab: kitna WETH bahar jayega (negative) aur kitna pool token andar aayega. |
| `mint` to swapper | Mock tokens hain, to swapper ko jitne chahiye utne de diye. |
| `swapExactOutput` | Swapper ki taraf se swap: exact WETH out chahiye, input pool decide karega. |

### The invariant and the phase 1 result

```solidity
function invariant_constantProductFormulaStaysSame_AUDIT() public view {
    assertEq(handler.actualDeltaX(), handler.expectedDeltaX());
}
```

First run was breaking, exactly as expected. After fixing the handler it passes:

```text
forge test --mt invariant_constantProductFormulaStaysSame_AUDIT -vvv

[PASS] invariant_constantProductFormulaStaysSame_AUDIT() (runs: 256, calls: 8192, reverts: 0)

| Contract | Selector                              | Calls | Reverts | Discards |
| Handler  | deposit                               | 4044  | 0       | 0        |
| Handler  | swapPoolTokenForWethBasedOnOutputWeth | 4148  | 0       | 0        |
```

The fix was in the handler, not in the pool. What changed:

| Change | Kyun |
|---|---|
| `startingX/Y` and `endingX/Y` now read `address(pool)` | Pehle `address(this)` tha, yaani handler ka apna balance, jo kabhi move hi nahi karta. Ab actual delta matlab pool ne kitna receive kiya. |
| `expectedDeltaX = poolTokenAmount` | Pehle deposit wale formula se compare ho raha tha, ab wahi number jo pool ne khud quote kiya. |
| `bound(_amount, getMinimumWethDepositAmount(), ...)` | Pool ka minimum deposit hai, usse neeche har run revert ho jaati thi. |
| `_outputWeth` bounded by the pool's WETH balance, guard `>=` | Jo pool ke paas nahi hai wo maangna sirf run waste karta hai. |
| `view` on the invariant | Ye function state change nahi karta. |

**Par passing ka matlab bug nahi mila.** Ye invariant pool ke apne quote ko uske apne transfer se compare karta hai: handler `getInputAmountBasedOnOutput` call karta hai, aur pool bhi wahi function andar use karta hai. Dono taraf same formula, isliye check circular hai.

Asli asymmetry wahi hai jo phase 2 ko pakadni chahiye:

```solidity
// getOutputAmountBasedOnInput -> inputAmount * 997, denominator uses 1000
// getInputAmountBasedOnOutput -> (inputReserves * outputAmount) * 10000 / ((outputReserves - outputAmount) * 997)
```

Ek jagah `1000` hai, doosre jagah `10000`. Matlab `swapExactOutput` wale user se fair input ka **~10x** zyada liya ja raha hai. Ye abhi ek lead hai, finding nahi: agla invariant (reserves par `x * y = k`) isi ko surface karega.

### What I actually did

1. **Finished the swap handler** in `Handler.t.sol` (`swapPoolTokenForWethBasedOnOutputWeth`)
2. **Wired the handler into the fuzzer** with `targetSelector` and `targetContract` in `Invariant.t.sol`
3. **Wrote the phase 1 invariant**, saw it break, then **fixed the handler measurement** and got it passing: 256 runs, 8192 calls, 0 reverts, both handlers exercised
4. **Added short comments** to both files, especially around the wiring block and the handler initializer
5. **Spotted the `10000` vs `1000` asymmetry** between the two pricing functions, which is what the next invariant has to prove

> Section 5 is still in progress. Phase 1 passing is a consistency check, not proof. Phase 2 has to assert the reserves product.

### Day 14 — Key takeaways

1. **Wiring is the whole trick.** `targetSelector` picks the functions, `targetContract` picks the contract, and everything else stays out of the fuzz.
2. **A handler should return, not revert.** Early returns keep the fuzzer's budget on realistic states, and `bound(..., minDeposit, ...)` keeps runs in the pool's valid range.
3. **Handler bugs look exactly like protocol bugs.** The first failure was my measurement, not the pool. Always check the harness before writing a finding.
4. **A passing invariant proves less than it looks.** Compare the pool against its own quote and you have proven the transfer matches the quote, nothing more.
5. **The lead is the asymmetry.** `10000` in one pricing function and `1000` in the other is the thing to prove next.

---

## Day 15 — Tooling passes, triage & the manual review

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Two tools, two answers** | Slither found nothing serious on TSwap, Aderyn returned a High that Slither missed entirely. |
| 2 | **No red is not no bug** | Slither returned only yellow and green, which means "nothing screaming", not "nothing here". |
| 3 | **`incorrect-equality`** | Comparing balances or values with strict `==` is a known smell, and it is usually worth a manual look. |
| 4 | **`pragma`** | Mixed pragma directives across the repo, harmless here but worth noting. |
| 5 | **`unindexed-event-address`** | Event arguments that are not indexed are harder to filter off-chain. |
| 6 | **A tool's High is a lead, not a severity** | Aderyn's High is the state-after-external-call pattern, and it has no funds behind it. |
| 7 | **Manual review still wins** | The real bug of the day (the LP symbol) was not reported by either tool. |

### Slither

`make slither`, 13 contracts, 100 detectors, 4 results, no red:

| Detector | Colour | What it flags |
|---|---|---|
| `incorrect-equality` | yellow | strict `==` comparisons |
| `missing-zero-check` | yellow | constructor params with no zero address check |
| `pragma` | green | different pragma directives in the repo |
| `unindexed-event-address` | green | event address params that are not indexed |

Result line: `INFO:Slither:. analyzed (13 contracts with 100 detectors), 4 result(s) found`

Yellow and green only, so nothing that demands a stop. That is triage, not absolution.

### Aderyn

`aderyn .` wrote [`tswap/report.md`](tswap/report.md):

| Category | No. of issues |
|---|---|
| High | 1 |
| Low | 5 |

- **H-1** Reentrancy: state change after external call, in `PoolFactory.createPool` (lines 51 and 52)
- **L-1** Large numeric literal, **L-2** literal instead of constant, **L-3** PUSH0 opcode, **L-4** unused error, **L-5** public function not used internally

**The lesson of the day:** Aderyn's High is exactly the kind of finding Slither stayed silent on. One tool flagged it, the other did not, which is the whole argument for running both.

### The X and Y invariants

```solidity
function invariant_constantProductFormulaStaysSameX_AUDIT() public view {
    assertEq(handler.actualDeltaX(), handler.expectedDeltaX());
}

function invariant_constantProductFormulaStaysSameY_AUDIT() public view {
    assertEq(handler.actualDeltaY(), handler.expectedDeltaY());
}
```

In the course the Y test threw an error, here it passed. Worth remembering: passing means the deltas match **the pool's own quotes**, so it is a consistency check, not proof of fairness.

```text
forge test --mt invariant_constantProductFormulaStaysSameY_AUDIT -vvv
[PASS] invariant_constantProductFormulaStaysSameY_AUDIT()
```

### Findings so far

Written in [`audit_data/findings.md`](audit_data/findings.md):

| ID | Severity | Finding |
|---|---|---|
| `L-1` | Low | LP token symbol is built from `name()` instead of `symbol()` |
| `I-1` | Informational | State change after external calls in `createPool`, Aderyn's High reentrancy, no funds at risk |

Both live in the contract as tags too:

```solidity
// @AUDIT-info:: External call before the state writes, so a malicious token can re-enter createPool and leave a ghost pool. Aderyn calls it High, but the factory holds no funds.
// @AUDIT-LOW:: Wrong value! This takes the token NAME, not its SYMBOL. Consider using symbol().
```

### What I actually did

1. **Ran the Y invariant**, which passes here even though the course's run errored
2. **Ran `make slither`** and got only yellow and green, no red flags for human review
3. **Ran `aderyn .`** and generated the automated `report.md`
4. **Found the High that Slither missed**, which is the clearest argument for using multiple tools
5. **Triaged that High down to `I-1`**, because the factory holds no funds and `createPool` is permissionless
6. **Found the LP symbol bug by reading the code**, which neither tool reported, and wrote it up as `L-1`
7. **Completed the majority of the manual review** and started listing everything in `findings.md`

> Section 5 is still in progress. Tooling passes are done and the manual review is mostly done, the findings list still needs the rest of the review.

### Day 15 — Key takeaways

1. **Run both tools, every time.** Aderyn caught a pattern Slither never reported, on the same code.
2. **A tool's High is a lead, not a severity.** Read the impact before you copy the severity into your report.
3. **Green and yellow still get read.** `pragma` and `unindexed-event-address` are low value, but they cost two minutes.
4. **Manual review finds what tools cannot.** The symbol bug is invisible to a detector that only looks at call patterns.
5. **Progress, not completion.** Tooling is done, the manual review is mostly done, the findings list is not.

---

## Day 16 — Finishing Section 5: findings, tests & the report

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Manual review is the last mile** | The tools flagged patterns, but the bugs that mattered came from reading the maths and the business logic. |
| 2 | **Every High, Medium and Low needs a proof** | Each one has a Foundry test that demonstrates the issue instead of describing it. |
| 3 | **Severity follows impact, not intention** | The swap incentive was a documented feature, but it pays LP money out for free, so it is a High. |
| 4 | **Review the write-up as adversarially as the code** | Two review passes over the findings file found real errors, including a wrong tool attribution and a diff that would not have compiled. |
| 5 | **One source, three outputs** | `findings.md` feeds `report.md`, which feeds `report.html` and `report.pdf`, so they cannot drift apart. |
| 6 | **A report is a build** | Same pipeline as Section 4: markdown source, styled HTML with the logo, PDF with page headers and metadata. |

### The findings from this section

| ID | Severity | Finding |
|---|---|---|
| `H-1` | High | Wrong fee in `getInputAmountBasedOnOutput`, exact output swaps charge about 10x the fair input |
| `H-2` | High | Swap incentive in `_swap` pays 1e18 of the output token every 10th swap, breaking `x * y = k` |
| `M-1` | Medium | No maximum input check in `swapExactOutput` |
| `M-2` | Medium | `sellPoolTokens` uses the amount to sell as the exact WETH output |
| `L-1` | Low | `deposit` takes a deadline and never checks it |
| `I-1` – `I-17` | Informational | 17 notes across both contracts, from factory validation to dead code |

**2 High · 2 Medium · 1 Low · 17 Informational = 22 findings**, all in [`audit_data/findings.md`](audit_data/findings.md).

### Tests written to prove them

| Test | What it proves |
|---|---|
| `test_SwapExactOutputOvercharges_AUDIT` | The caller pays `5.04e18` pool tokens where the fair input is `0.504e18`, exactly 10x |
| `test_SwapExactOutputNoMaxInput_AUDIT` | The same output costs `10.13e18` and then `22.88e18` after a price move, and the swap still goes through |
| `test_SellPoolTokensWrongAmount_AUDIT` | Selling `5e18` pool tokens costs `52.79e18` of them, and a normal seller reverts |
| `test_SwapIncentiveBreaksInvariant_AUDIT` | The 10th swap pays `1e18` for free and the pool's `k` drops |
| `test_DepositIgnoresDeadline_AUDIT` | An expired deadline is accepted by `deposit` and rejected by `withdraw` |

Plus the invariant suite, `invariant_constantProductFormulaStaysSameX_AUDIT` and `...Y_AUDIT`, which pass through the handler.

### The report

| File | What it is |
|---|---|
| [`audit_data/report.md`](audit_data/report.md) | source, same template as Sections 3 and 4 |
| [`audit_data/report.html`](audit_data/report.html) | styled single file, logo embedded, every PoC code block open |
| [`audit_data/report.pdf`](audit_data/report.pdf) | the final client deliverable, 26 pages |

### What I actually did

1. **Finished the manual review** of both contracts and tagged every issue inline with `@AUDIT-*`
2. **Wrote a test for every High, Medium and Low** finding
3. **Ran two adversarial review passes** over the findings file and fixed what came out of them, including promoting the swap incentive from Medium to High (`H-2`) and dropping a wrong Slither attribution
4. **Wrote up all 22 findings** in `findings.md`, with Impact and Proof of Concept where the severity needs them
5. **Built the report**: `report.md` from the template, then `report.html` with the logo and open code blocks, then `report.pdf` with page headers, footers and metadata
6. **Verified the outputs**: full test suite green, all 37 table of contents links resolve, PDF cover clean with no duplicated headers

### Day 16 — Key takeaways

1. **A finding is only as good as its proof.** Every High, Medium and Low has a test that demonstrates it.
2. **Severity follows impact, not intention.** A documented feature that removes LP funds is still a High.
3. **Review the report like you review the code.** Both review passes found errors in the write-up, not in the contracts.
4. **Keep one source of truth.** `findings.md` to `report.md` to `report.html` to `report.pdf`, nothing retyped.
5. **Section 5 is done.** Two Highs, two Mediums, one Low and seventeen Informationals, with a test behind every serious one.

---

*Days 10–16 of my [smart contract security journey](../README.md). Section 5 complete.*
