# Section 6 — Thunder Loan Audit

**Status:** 🚧 Work in progress &nbsp;·&nbsp; **Days:** 17–21 &nbsp;·&nbsp; **Type:** Hands-on audit
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

## Day 19 — Manual review: the protocol contracts & the failure to initialize bug

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Failure to initialize** | A proxy is deployed without calling `initialize`, so it keeps default state and the first caller can initialize it and take ownership. |
| 2 | **The teaching file** | [`FailureToInitialize.sol`](FailureToInitialize.sol) shows the shape: `initialize` sets the value, nothing checks that it ran, and the rest of the contract happily works on default state. |
| 3 | **`_disableInitializers()` protects the implementation, not the proxy** | ThunderLoan's constructor disables initializers on the implementation, which is right, but the proxy still has to be initialized by the deployer. |
| 4 | **On upgradeable protocols the impact is ownership** | The initializer sets the owner, and the owner is the upgrade authority, so an open initializer is a takeover, not a configuration bug. |
| 5 | **Deploy scripts are in scope** | The bug was not in the contract but in the script: `new ERC1967Proxy(address(thunderLoan), "")` never calls `initialize`. |
| 6 | **Zero address checks belong in initializers** | A bad address stored at setup has no second chance, so the check has to be there rather than at every read. |

### Failure to initialize, in one line

> A proxy is deployed but never initialized, so the contract runs on default state and the first caller of `initialize()` becomes the owner and configures it however they want.

**Example, from this repo:** [`script/DeployThunderLoan.s.sol`](thunder-loan/script/DeployThunderLoan.s.sol) deploys the proxy with empty init data and never calls `initialize`, so anyone can call `initialize(theirOwnPoolFactory)`, become the owner, and then upgrade the implementation to anything.

References for the topic: [OpenZeppelin forum, proxy initialize front-running risk](https://forum.openzeppelin.com/t/risk-on-proxy-initialize-front-running-risk/27280) and a real finding of the same shape in the [Sherlock Sophon judging repo](https://github.com/sherlock-audit/2024-05-sophon-judging/issues/194).

### Findings from today

| ID | Type | Finding |
|---|---|---|
| `L-1` | Low | unprotected `ThunderLoan::initialize`, the proxy can be initialized by anyone and the deploy script never calls it |
| `I-4` | Informational | `OracleUpgradeable::__Oracle_init` has no zero address check on the pool factory |

Both live in [`audit_data/findings.md`](audit_data/findings.md), now ordered `L` above `Q` above `I`.

### What I actually did

1. **Read the teaching file** [`FailureToInitialize.sol`](FailureToInitialize.sol) to learn the bug class properly
2. **Reviewed [`thunder-loan/src/protocol/ThunderLoan.sol`](thunder-loan/src/protocol/ThunderLoan.sol)** and found the unprotected `initialize`, then checked the deploy script and saw it never initializes the proxy at all
3. **Reviewed [`thunder-loan/src/protocol/OracleUpgradeable.sol`](thunder-loan/src/protocol/OracleUpgradeable.sol)** and tagged the missing zero address check in `__Oracle_init`
4. **Reviewed [`thunder-loan/src/protocol/AssetToken.sol`](thunder-loan/src/protocol/AssetToken.sol)** with no issue worth a tag
5. **Wrote both findings up**, the Low above the two Questions, and added the topic to this README with references

### Day 19 — Key takeaways

1. **Deployment scripts are part of the audit surface.** This bug lived in the script while the contract looked fine.
2. **A proxy that is never initialized is an open contract.** Anyone can take ownership before the deployer does.
3. **`_disableInitializers()` is necessary but not sufficient.** It protects the implementation, not the proxy.
4. **Initializers are the last place with sensible defaults.** Check addresses there, because there is no later point that can.
5. **Learn the bug class, then look for it.** Reading the teaching file first is what made the deploy script obvious.

---

## Day 20 — The fee denomination High 🔴 & finishing the manual audit

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **Denomination bugs** | A value computed in one unit and used in another is a bug even when the maths looks right. The fee came out in WETH and was checked in tokens. |
| 2 | **Mocks can hide bugs** | The client's `MockTSwapPool` hardcodes the price at `1e18`, and at exactly 1 WETH the wrong fee happens to be the right one. Change the price and the bug appears. |
| 3 | **`vm.mockCall` for a targeted proof** | Instead of writing a new mock, `vm.mockCall` overrides one function's return value on the existing mock, so the PoC stays small. |
| 4 | **Atomicity protects against over-charging only** | A borrower who is overcharged can revert the whole transaction, but a protocol that undercharges can never get the money back. |
| 5 | **Tag every instance, file one finding** | 38 functions got their own natspec tag, but they stay a single Informational finding so the report does not drown in duplicates. |
| 6 | **Centralization is a question, not a code bug** | A frozen USDC stops that asset dead, and no code change can fix it, so it goes to the team as a question. |

### The High 🔴

`getCalculatedFee` returns the fee in **WETH**:

```javascript
uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
```

but `flashloan` checks the repayment in **token units** (`endingBalance < startingBalance + fee`). So a token worth `0.01` WETH is charged 100x less than the advertised 0.3%, and a token worth more than 1 WETH is charged more.

Proven by `test_CalculatedFeeIsDenominatedInWeth_AUDIT`:

```text
intended fee in token units: 30000000000000000
fee the contract charges: 300000000000000
```

`0.03` tokens should have been charged, `0.0003` was, and the live flash loan in the same test accepted the reduced repayment.

### Findings after today

| ID | Type | Finding |
|---|---|---|
| `H-1` | High 🔴 | fee is WETH-denominated but treated as token units |
| `L-1` | Low | unprotected initializer, the proxy can be taken over, now with a PoC |
| `Q-1` | Question | every asset priced through a single TSwap WETH pool |
| `Q-2` | Question | the fee maths depends on TSwap |
| `Q-3` | Question | a frozen USDC (Circle) stops the asset |
| `I-1` | Informational | unused import in `IFlashLoanReceiver` |
| `I-2` | Informational | 38 functions with no natspec, across five files |
| `I-3` | Informational | `IThunderLoan` is never implemented and its `repay` type differs |
| `I-4` | Informational | no zero address check in `__Oracle_init` |

All nine in [`audit_data/findings.md`](audit_data/findings.md).

### What I actually did

1. **Finished the manual review of [`thunder-loan/src/protocol/ThunderLoan.sol`](thunder-loan/src/protocol/ThunderLoan.sol)** and found the fee denomination bug
2. **Wrote `test_CalculatedFeeIsDenominatedInWeth_AUDIT`**, using `vm.mockCall` to give the mock pool a realistic price, proving both the wrong fee and a live flash loan accepting it
3. **Added the PoC for `L-1`**, which shows the proxy being taken over, the fee being set and the implementation being replaced
4. **Expanded `I-2` to every missing-natspec function** (38 across five files) and tagged each one inline
5. **Wrote both new findings** (`H-1`, `Q-3`) into `findings.md`

### Day 20 — Key takeaways

1. **Check the unit of every value that crosses a function boundary.** This bug is one line of arithmetic with no wrong number in it.
2. **A convenient mock value can hide a real bug.** The price of exactly 1 WETH made the wrong fee correct.
3. **`vm.mockCall` is the smallest possible proof.** No new mock contract, just the one return value that matters.
4. **Atomicity limits over-charging, not under-charging.** The protocol can only lose here.
5. **One finding per root cause.** 38 tags, one Informational entry, and every tag still greps.

---

## Day 21 — The deposit fee-inflation High 🔴

### What I learnt

| # | Concept | One-liner |
|---|---------|-----------|
| 1 | **A deposit is not a flash loan** | `deposit` carried the same two fee lines as `flashloan`, where they are correct, so a copy-paste turned the depositor into a fee payer who never paid. |
| 2 | **Passing tests are not proof of correct accounting** | The existing deposit test asserted the mint and the transfer, and never read the exchange rate, so the value that was wrong was the one value it never looked at. |
| 3 | **The exchange rate formula credits everyone** | `newRate = oldRate * (totalSupply + fee) / totalSupply` hands the fee to every existing holder, which is only fair if the fee was really received. |
| 4 | **Insolvency is a state, not an event** | One plain deposit made `100.3e18` redeemable against `100e18` held, so the pool was already broken before any attacker did anything. |
| 5 | **First in, first out** | The inflation is credited to whoever already holds asset tokens, so the first depositor exits with a profit and the next depositor cannot exit at all. |
| 6 | **A call inside the arguments eats the prank** | `redeem(tokenA, assetToken.balanceOf(lp))` consumed the `vm.prank`, so the redeem ran as the test contract and burned nothing. |
| 7 | **Fuzz is not the answer to every bug** | The bug is deterministic, two plain deposits show it, so fuzzing would only walk the same path again. The invariant is the permanent guard, not the proof. |

### The High 🔴

`deposit` charges the depositor a flash loan fee and adds it to the exchange rate, even though no loan was taken and no fee was ever paid:

```javascript
assetToken.mint(msg.sender, mintAmount);
uint256 calculatedFee = getCalculatedFee(token, amount);
assetToken.updateExchangeRate(calculatedFee);
token.safeTransferFrom(msg.sender, address(assetToken), amount);
```

`updateExchangeRate` scales the rate by `(totalSupply + fee) / totalSupply`, which credits that fee to every existing holder. That is correct in `flashloan`, because the repayment check makes the borrower actually pay it. On a deposit nobody pays anything, so the rate rises against tokens that do not exist and the pool ends up owing more than it holds.

Proven by `test_DepositChargesItsOwnFee_AUDIT` and `test_DepositExchangeRateInflationStealsFromNextDepositor_AUDIT`:

```text
exchange rate before: 1000000000000000000
exchange rate after a plain deposit: 1003000000000000000
underlying held by the pool: 100000000000000000000
underlying redeemable at the new rate: 100300000000000000000
first depositor profit: 450675336994508200
underlying left for the victim: 99549324663005491800
```

A `100e18` deposit with no loan anywhere in the transaction moves the rate from `1e18` to `1.003e18`, which makes `100.3e18` redeemable against the `100e18` that is actually held. The first depositor walks away with `0.45e18`, and the next depositor's `redeem` reverts.

### Findings after today

| ID | Type | Finding |
|---|---|---|
| `H-1` | High 🔴 | fee is WETH-denominated but treated as token units |
| `H-2` | High 🔴 | a deposit is charged a fee that was never paid, inflating the exchange rate |
| `L-1` | Low | unprotected initializer, the proxy can be taken over |
| `Q-1` | Question | every asset priced through a single TSwap WETH pool |
| `Q-2` | Question | the fee maths depends on TSwap |
| `Q-3` | Question | a frozen USDC (Circle) stops the asset |
| `I-1` | Informational | unused import in `IFlashLoanReceiver` |
| `I-2` | Informational | 38 functions with no natspec, across five files |
| `I-3` | Informational | `IThunderLoan` is never implemented and its `repay` type differs |
| `I-4` | Informational | no zero address check in `__Oracle_init` |

All ten in [`audit_data/findings.md`](audit_data/findings.md).

### What I actually did

1. **Went back over [`thunder-loan/src/protocol/ThunderLoan.sol`](thunder-loan/src/protocol/ThunderLoan.sol)** during the manual review and caught the deposit fee lines that had been copied from `flashloan`
2. **Checked why the existing deposit test still passed** and confirmed it never reads `getExchangeRate()`, so the inflated value was never asserted on
3. **Wrote two `_AUDIT` unit tests**, the first proving the rate moves on a plain deposit, the second proving the first depositor profits while the next depositor's `redeem` reverts
4. **Tagged the contract** with `// @AUDIT-HIGH::` above the two lines and wrote `H-2` up in [`audit_data/findings.md`](audit_data/findings.md)
5. **Normalised every audit tag in the repo** to the canonical set (`HIGH`, `Medium`, `Low`, `info`, `q`) in a separate commit

### Day 21 — Key takeaways

1. **Copy-paste across functions is a bug class of its own.** The same two lines are correct in `flashloan` and wrong in `deposit`, and nothing in the compiler tells the two apart.
2. **Read the test before you trust it.** A green test proves the path runs, not that the numbers it never reads are right.
3. **Follow the value, not the call.** The mint and the transfer were both fine, the exchange rate was not.
4. **Insolvency can start on deposit one.** Check the protocol's own claim against its own balance after a single user action.
5. **Prove with the smallest tool that works.** Two deterministic unit tests prove it; the invariant belongs in the suite that will guard the whole class.

---

*Days 17–21 of my [smart contract security journey](../README.md). Section 6 — audit in progress.*
