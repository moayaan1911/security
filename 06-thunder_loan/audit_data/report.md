<div class="cover">

<img src="profile.jpeg" alt="Logo" class="cover-logo" />

<h1 class="cover-title">Thunder Loan Audit Report</h1>

<p class="cover-version">Version 1.0</p>

<p class="cover-org"><em>Mohammad Ayaan</em><br/>moayaan.com</p>

<p class="cover-date">November 26, 2026</p>

</div>

<div class="page-break"></div>

Prepared by: [Mohammad Ayaan](https://moayaan.com)

Lead Auditors:

- Mohammad Ayaan

# Table of Contents

- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
- [High](#high)
  - [\[H-1\] The fee is denominated in WETH but treated as token units in `ThunderLoan::getCalculatedFee`, so every token is charged the wrong fee](#h-1-the-fee-is-denominated-in-weth-but-treated-as-token-units-in-thunderloangetcalculatedfee-so-every-token-is-charged-the-wrong-fee)
  - [\[H-2\] A plain deposit is charged a flash loan fee that was never paid in `ThunderLoan::deposit`, so the exchange rate inflates and the pool owes more than it holds](#h-2-a-plain-deposit-is-charged-a-flash-loan-fee-that-was-never-paid-in-thunderloandeposit-so-the-exchange-rate-inflates-and-the-pool-owes-more-than-it-holds)
- [Medium](#medium)
  - [\[M-1\] `ThunderLoanUpgraded` removes `s_feePrecision` as a storage variable, so upgrading the proxy shifts `s_flashLoanFee` into the old precision slot and leaves the protocol charging a 100% fee](#m-1-thunderloanupgraded-removes-s_feeprecision-as-a-storage-variable-so-upgrading-the-proxy-shifts-s_flashloanfee-into-the-old-precision-slot-and-leaves-the-protocol-charging-a-100-fee)
- [Low](#low)
  - [\[L-1\] Unprotected initializer in `ThunderLoan::initialize`, the proxy can be initialized by anyone and the deploy script never calls it](#l-1-unprotected-initializer-in-thunderloaninitialize-the-proxy-can-be-initialized-by-anyone-and-the-deploy-script-never-calls-it)
- [Question](#question)
  - [\[Q-1\] Every asset is priced only through its own TSwap WETH pool in `OracleUpgradeable::getPriceInWeth`, is a single price source the intended design?](#q-1-every-asset-is-priced-only-through-its-own-tswap-weth-pool-in-oracleupgradeablegetpriceinweth-is-a-single-price-source-the-intended-design)
  - [\[Q-2\] The protocol's fee maths depends on TSwap, is a less proven AMM the intended price source?](#q-2-the-protocols-fee-maths-depends-on-tswap-is-a-less-proven-amm-the-intended-price-source)
  - [\[Q-3\] Allowed tokens can be frozen by a centralized issuer, what happens if Circle blocks the protocol?](#q-3-allowed-tokens-can-be-frozen-by-a-centralized-issuer-what-happens-if-circle-blocks-the-protocol)
- [Informational](#informational)
  - [\[I-1\] Unused import in `IFlashLoanReceiver`, the interface imports `IThunderLoan` and never uses it](#i-1-unused-import-in-iflashloanreceiver-the-interface-imports-ithunderloan-and-never-uses-it)
  - [\[I-2\] Missing natspec on almost the whole public surface in the interfaces, `AssetToken`, `OracleUpgradeable`, `ThunderLoan` and `ThunderLoanUpgraded`](#i-2-missing-natspec-on-almost-the-whole-public-surface-in-the-interfaces-assettoken-oracleupgradeable-thunderloan-and-thunderloanupgraded)
  - [\[I-3\] `IThunderLoan` is never implemented and its `repay` type does not match `ThunderLoan`, so the interface cannot be trusted as the protocol ABI](#i-3-ithunderloan-is-never-implemented-and-its-repay-type-does-not-match-thunderloan-so-the-interface-cannot-be-trusted-as-the-protocol-abi)
  - [\[I-4\] Missing zero address check in `OracleUpgradeable::__Oracle_init`, a bad pool factory breaks all pricing instead of reverting at setup](#i-4-missing-zero-address-check-in-oracleupgradeable__oracle_init-a-bad-pool-factory-breaks-all-pricing-instead-of-reverting-at-setup)
  - [\[I-5\] `ThunderLoan__ExhangeRateCanOnlyIncrease` is declared but never used, the real check lives in `AssetToken`](#i-5-thunderloan__exhangeratecanonlyincrease-is-declared-but-never-used-the-real-check-lives-in-assettoken)
  - [\[I-6\] `ThunderLoan::updateFlashLoanFee` changes the fee with no event, so the change is invisible off-chain](#i-6-thunderloanupdateflashloanfee-changes-the-fee-with-no-event-so-the-change-is-invisible-off-chain)
- [Gas](#gas)

# Protocol Summary

Thunder Loan is an upgradeable flash loan protocol. Liquidity providers deposit an allowed ERC20 into the protocol, which mints an `AssetToken` wrapper for that asset; the wrapper's exchange rate rises as flash loan fees are paid, so depositors earn yield. Borrowers take a flash loan of an allowed token for a flat 0.3% fee, use the funds inside the same transaction and must repay the amount plus the fee before it ends, otherwise the whole call reverts. The fee is priced through TSwap: `OracleUpgradeable` asks the TSwap pool factory for the token's WETH pool and reads a single price, so protocol revenue depends on that AMM. The protocol runs behind an `ERC1967Proxy`, and the owner can allow tokens, change the fee and upgrade the implementation, which puts the storage layout across upgrades in scope as well.

# Disclaimer

Mohammad Ayaan makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details

**The findings described in this document correspond to the following commit hash:**

```
8803f851f6b37e99eab2e94b4690c8b70e26b3f6
```

## Scope

```
./src/
├── interfaces/
│   ├── IFlashLoanReceiver.sol
│   ├── IPoolFactory.sol
│   ├── ITSwapPool.sol
│   └── IThunderLoan.sol
├── protocol/
│   ├── AssetToken.sol
│   ├── OracleUpgradeable.sol
│   └── ThunderLoan.sol
└── upgradedProtocol/
    └── ThunderLoanUpgraded.sol
```

## Roles

- **Owner:** allows and removes tokens, updates the flash loan fee, and is the upgrade authority for the implementation.
- **Liquidity providers:** deposit an allowed token, receive the matching `AssetToken`, and redeem it later at the current exchange rate to take their share of the fees.
- **Borrowers / flash loan receivers:** take an allowed token as a flash loan and must repay the amount plus the 0.3% fee inside the same transaction.

# Executive Summary

This was a time-boxed review of Thunder Loan, using static analysis with Slither and Aderyn, a manual review of every in-scope contract, and Foundry proof-of-concept tests written during the review. The review found 2 High, 1 Medium, 1 Low, 3 Question and 6 Informational findings. Both Highs are accounting bugs that neither tool can flag: `getCalculatedFee` returns the fee in WETH while `flashloan` checks the repayment in token units, so every token not worth exactly 1 WETH is charged the wrong fee, and `deposit` charges itself a flash loan fee that nobody pays, which inflates the exchange rate and leaves the pool owing more than it holds. The Medium is upgrade safety: `ThunderLoanUpgraded` stops declaring `s_feePrecision`, so upgrading the proxy shifts `s_flashLoanFee` into the old `1e18` precision slot and the protocol charges a 100% fee. Every High and the Medium has a working Foundry test as proof of concept, and the suite passes 14 tests. Slither returned only reentrancy and missing-event results, all triaged as false positives or informational, while Aderyn's two Highs were a false positive on `repay` (it moves ERC20, not ETH) and the known reentrancy pattern in `flashloan`.

## Issues found

| Severity      | Number of issues found |
| ------------- | ---------------------- |
| High          | 2                      |
| Medium        | 1                      |
| Low           | 1                      |
| Question      | 3                      |
| Informational | 6                      |
| Gas           | 0                      |
| **Total**     | **13**                  |

# Findings

# High

### [H-1] The fee is denominated in WETH but treated as token units in `ThunderLoan::getCalculatedFee`, so every token is charged the wrong fee

**Description:**
`getCalculatedFee` converts the borrowed amount into WETH value and takes the fee from that value:

```javascript
uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
```

The fee that comes out is an amount of **WETH**, but `flashloan` uses it as if it were an amount of the borrowed **token**:

```javascript
uint256 fee = getCalculatedFee(token, amount);
...
uint256 endingBalance = token.balanceOf(address(assetToken));
if (endingBalance < startingBalance + fee) {
    revert ThunderLoan__NotPaidBack(startingBalance + fee, endingBalance);
}
```

The repayment check, the `FlashLoan` event and `assetToken.updateExchangeRate(fee)` all treat the number as token units, so the two only agree when the token is worth exactly `1e18`. The client's `MockTSwapPool` hardcodes a price of `1e18`, which is why the existing tests never caught it.

The same code is in the upgraded implementation, `upgradedProtocol/ThunderLoanUpgraded.sol` (`getCalculatedFee`, lines 262-266), so this finding applies to both in-scope contracts and fixing only `ThunderLoan` would leave the bug in the upgrade.

**Impact:**
Every token that is not worth exactly 1 WETH is charged the wrong fee. A token worth `0.01` WETH is charged 100x less than the advertised 0.3%, so the borrower pays almost nothing and the liquidity providers lose the yield, while a token worth more than 1 WETH is charged far more than 0.3%. In the PoC the fee on a 10 token loan comes out as `0.0003` tokens instead of `0.03`.

**Proof of Concept:**
Check the `test_CalculatedFeeIsDenominatedInWeth_AUDIT` test in the `ThunderLoanTest.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the H-1: getCalculatedFee returns the fee in WETH value, but flashloan expects it in token units
    function test_CalculatedFeeIsDenominatedInWeth_AUDIT() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT;

        // the mock pool hardcodes a price of 1e18, which hides the bug, so set a real one:
        // this token is worth 0.01 WETH, not 1 WETH
        uint256 price = 0.01e18;
        MockTSwapPool pool = MockTSwapPool(mockPoolFactory.getPool(address(tokenA)));
        vm.mockCall(
            address(pool),
            abi.encodeWithSelector(MockTSwapPool.getPriceOfOnePoolTokenInWeth.selector),
            abi.encode(price)
        );

        uint256 fee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);

        // the fee should be 0.3% of the borrowed token amount
        uint256 intendedFee = (amountToBorrow * thunderLoan.getFee()) / thunderLoan.getFeePrecision();

        // instead it is 0.3% of the WETH value, treated as if it were tokens
        uint256 valueInWeth = (amountToBorrow * price) / thunderLoan.getFeePrecision();
        uint256 wronglyDenominatedFee = (valueInWeth * thunderLoan.getFee()) / thunderLoan.getFeePrecision();

        console2.log("intended fee in token units:", intendedFee);
        console2.log("fee the contract charges:", fee);
        assertEq(fee, wronglyDenominatedFee);
        assertEq(fee, intendedFee / 100);

        // and the protocol really accepts this reduced fee on a real flash loan
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);
        console2.log("asset token balance after the loan:", tokenA.balanceOf(address(assetToken)));
        console2.log("receiver paid in fees:", AMOUNT - mockFlashLoanReceiver.getBalanceAfter());

        // the pool grew by the wrongly denominated fee, not by the intended one
        assertEq(
            tokenA.balanceOf(address(assetToken)),
            DEPOSIT_AMOUNT + fee
        );
        assertEq(AMOUNT - mockFlashLoanReceiver.getBalanceAfter(), fee);
        assertLt(fee, intendedFee);
    }
```

</details>
You can run it via

```bash
forge test --mt test_CalculatedFeeIsDenominatedInWeth_AUDIT -vv
```
and you will see something like this:

```text
Logs:
  intended fee in token units: 30000000000000000
  fee the contract charges: 300000000000000
  asset token balance after the loan: 1000000300000000000000
  receiver paid in fees: 300000000000000
```
A 10 token loan should cost `0.03` tokens in fees and the protocol charges `0.0003`, and the live flash loan in the same test accepts that reduced repayment.

**Recommended Mitigation:**
1. Take the fee as a percentage of the borrowed amount, in the token's own units, and drop the price conversion from the fee path:

```diff
-        uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
-        fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
+        fee = (amount * s_flashLoanFee) / s_feePrecision;
```

2. If the fee is meant to be collected in WETH terms instead, then the repayment check, the event and the exchange rate update all have to be denominated in WETH too, and the natspec has to say which unit the fee is in.

### [H-2] A plain deposit is charged a flash loan fee that was never paid in `ThunderLoan::deposit`, so the exchange rate inflates and the pool owes more than it holds

**Description:**
`deposit` charges the depositor a flash loan fee and adds it to the exchange rate, even though no loan was taken and no fee was paid:

```javascript
assetToken.mint(msg.sender, mintAmount);
uint256 calculatedFee = getCalculatedFee(token, amount);
assetToken.updateExchangeRate(calculatedFee);
token.safeTransferFrom(msg.sender, address(assetToken), amount);
```

`updateExchangeRate` credits that fee to every existing holder by scaling the rate:

```javascript
uint256 newExchangeRate = (s_exchangeRate * (totalSupply() + fee)) / totalSupply();
```

On a flash loan that is correct, because the borrower actually pays the fee and the repayment check (`endingBalance < startingBalance + fee`) enforces it. On a deposit nobody pays anything, the only tokens that enter the pool are the depositor's own `amount`, and the rate still goes up, so the AssetToken ends up claiming underlying that does not exist. The block was copied from the flash loan path where the same two lines are legitimate.

The same two lines are in the upgraded implementation, `upgradedProtocol/ThunderLoanUpgraded.sol` (`deposit`, lines 154-155), so this finding applies to both in-scope contracts.

**Impact:**
The exchange rate inflates on a plain deposit by the fee that was never paid, so the pool is immediately insolvent: in the PoC a `100e18` deposit mints `100e18` asset tokens and pushes the rate from `1e18` to `1.003e18`, which makes `100.3e18` underlying redeemable while only `100e18` is held. The value is credited to whoever holds asset tokens first, so the first depositor redeems more than they put in and the shortfall is taken from the next depositor: the first depositor puts in `100e18` and takes out `100.4506753369945082e18`, while the victim's `100e18` deposit is left with `99.5493246630054918e18` of underlying against a `100.150224663005491723e18` claim, and their own `redeem` reverts. Every deposit repeats the inflation, so the protocol can never become solvent again and the last liquidity provider out cannot withdraw. On a live protocol the first-in advantage can be sandwiched around any large deposit.

**Proof of Concept:**
Check the `test_DepositChargesItsOwnFee_AUDIT` and `test_DepositExchangeRateInflationStealsFromNextDepositor_AUDIT` tests in the `ThunderLoanTest.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the H-2: deposit charges itself a flash loan fee that was never paid and adds it to the
    // exchange rate, so a plain deposit with no loan in the transaction inflates the rate
    function test_DepositChargesItsOwnFee_AUDIT() public setAllowedToken {
        uint256 depositAmount = 100e18;
        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);

        uint256 rateBefore = assetToken.getExchangeRate();

        tokenA.mint(liquidityProvider, depositAmount);
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), depositAmount);
        thunderLoan.deposit(tokenA, depositAmount);
        vm.stopPrank();

        uint256 rateAfter = assetToken.getExchangeRate();
        uint256 minted = assetToken.totalSupply();
        uint256 held = tokenA.balanceOf(address(assetToken));
        uint256 redeemable = (minted * rateAfter) /
            assetToken.EXCHANGE_RATE_PRECISION();

        console2.log("exchange rate before:", rateBefore);
        console2.log("exchange rate after a plain deposit:", rateAfter);
        console2.log("asset tokens minted:", minted);
        console2.log("underlying held by the pool:", held);
        console2.log("underlying redeemable at the new rate:", redeemable);

        // no flash loan happened, so the rate should never have moved
        assertEq(rateBefore, 1e18);
        assertGt(rateAfter, rateBefore);

        // and the protocol already owes more underlying than it holds
        assertGt(redeemable, held);
    }

    // the H-2 impact: the inflation is credited to whoever deposited first, so the first
    // depositor redeems more than they put in and the next depositor cannot exit
    function test_DepositExchangeRateInflationStealsFromNextDepositor_AUDIT()
        public
        setAllowedToken
    {
        uint256 depositAmount = 100e18;
        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);
        address victim = makeAddr("victim");

        // first depositor
        tokenA.mint(liquidityProvider, depositAmount);
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), depositAmount);
        thunderLoan.deposit(tokenA, depositAmount);
        vm.stopPrank();

        // an honest second depositor puts in the same amount
        tokenA.mint(victim, depositAmount);
        vm.startPrank(victim);
        tokenA.approve(address(thunderLoan), depositAmount);
        thunderLoan.deposit(tokenA, depositAmount);
        vm.stopPrank();

        uint256 victimAssetTokens = assetToken.balanceOf(victim);
        uint256 rate = assetToken.getExchangeRate();
        uint256 victimRedeemable = (victimAssetTokens * rate) /
            assetToken.EXCHANGE_RATE_PRECISION();

        // the first depositor exits with everything
        // (read the balance first, a call inside the args would eat the prank)
        uint256 firstDepositorAssetTokens = assetToken.balanceOf(
            liquidityProvider
        );
        vm.prank(liquidityProvider);
        thunderLoan.redeem(tokenA, firstDepositorAssetTokens);

        uint256 firstDepositorOut = tokenA.balanceOf(liquidityProvider);
        uint256 leftForVictim = tokenA.balanceOf(address(assetToken));

        console2.log("first depositor put in:", depositAmount);
        console2.log("first depositor took out:", firstDepositorOut);
        console2.log(
            "first depositor profit:",
            firstDepositorOut - depositAmount
        );
        console2.log("victim asset tokens:", victimAssetTokens);
        console2.log("victim redeemable at the rate:", victimRedeemable);
        console2.log("underlying left for the victim:", leftForVictim);

        // the first depositor made a profit with no risk
        assertGt(firstDepositorOut, depositAmount);

        // the victim cannot redeem what the exchange rate promises them
        assertLt(leftForVictim, victimRedeemable);

        // their own redeem reverts, the deposit is stuck behind the inflated rate
        vm.prank(victim);
        vm.expectRevert();
        thunderLoan.redeem(tokenA, type(uint256).max);
    }
```

</details>
You can run it via

```bash
forge test --mt test_Deposit -vv
```
and you will see something like this:

```text
Logs:
  exchange rate before: 1000000000000000000
  exchange rate after a plain deposit: 1003000000000000000
  asset tokens minted: 100000000000000000000
  underlying held by the pool: 100000000000000000000
  underlying redeemable at the new rate: 100300000000000000000
Logs:
  first depositor put in: 100000000000000000000
  first depositor took out: 100450675336994508200
  first depositor profit: 450675336994508200
  victim asset tokens: 99700897308075772681
  victim redeemable at the rate: 100150224663005491723
  underlying left for the victim: 99549324663005491800
```
A deposit with no loan anywhere moves the rate from `1e18` to `1.003e18` and leaves `100.3e18` redeemable against the `100e18` that is actually held, so the pool is insolvent after the very first deposit. In the second test the first depositor walks away with `0.45e18` of profit and the next depositor's `redeem` reverts.

**Recommended Mitigation:**
1. Remove the fee accounting from `deposit`. The fee is only ever paid on a flash loan, so the deposit path must not touch the exchange rate:

```diff
         assetToken.mint(msg.sender, mintAmount);
-        uint256 calculatedFee = getCalculatedFee(token, amount);
-        assetToken.updateExchangeRate(calculatedFee);
         token.safeTransferFrom(msg.sender, address(assetToken), amount);
```

2. Keep the `updateExchangeRate` call on the flash loan path, where the repayment check guarantees the fee was actually received. The rate should only move when the protocol has the tokens to back it.

3. Both PoCs have to be flipped after the fix: the rate must stay at `1e18` on a deposit and the first depositor must stop profiting, so the `assertGt` calls become `assertEq` on those values.

# Medium

### [M-1] `ThunderLoanUpgraded` removes `s_feePrecision` as a storage variable, so upgrading the proxy shifts `s_flashLoanFee` into the old precision slot and leaves the protocol charging a 100% fee

**Description:**
`ThunderLoanUpgraded` is the next implementation for the same proxy, but it changes the storage layout. The original declares its variables in this order:

```javascript
mapping(IERC20 => AssetToken) public s_tokenToAssetToken;
uint256 private s_feePrecision;
uint256 private s_flashLoanFee;
mapping(IERC20 token => bool currentlyFlashLoaning) private s_currentlyFlashLoaning;
```

The upgraded contract drops `s_feePrecision` and turns the precision into a constant, so every variable declared after it moves up one slot:

```javascript
mapping(IERC20 => AssetToken) public s_tokenToAssetToken;
uint256 private s_flashLoanFee;
uint256 public constant FEE_PRECISION = 1e18;
mapping(IERC20 token => bool currentlyFlashLoaning) private s_currentlyFlashLoaning;
```

After the upgrade `s_flashLoanFee` reads the slot that used to hold `s_feePrecision`, which `initialize` set to `1e18`. The upgraded `initialize` cannot correct it, because the proxy's `initializer` modifier is already spent, so the fee stays at `1e18` until an owner calls `updateFlashLoanFee`. Nothing in the repo upgrades the proxy and no test or script references this contract, so it has never been exercised.

**Impact:**
A fee of `1e18` against a precision of `1e18` is a **100% fee**, so the protocol charges twice the borrowed amount until the owner notices and fixes it. In the PoC the fee goes from `3e15` (0.3%) to `1e18` the moment the proxy is upgraded, and a `100e18` loan is charged a `100e18` fee. Flash loans are unusable for borrowers in that window, and the contract is in scope, so the upgrade is the audit surface even though it is not wired up yet.

**Proof of Concept:**
Check the `test_UpgradeShiftsFeeToHundredPercent_AUDIT` test in the `ThunderLoanTest.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the M-1: ThunderLoanUpgraded drops s_feePrecision as a storage variable, so every
    // variable declared after it shifts up one slot and s_flashLoanFee inherits the old 1e18
    function test_UpgradeShiftsFeeToHundredPercent_AUDIT() public setAllowedToken {
        uint256 feeBefore = thunderLoan.getFee();
        assertEq(feeBefore, 3e15);

        // upgrade the same proxy to the contract the upgradedProtocol folder exists for
        ThunderLoanUpgraded upgraded = new ThunderLoanUpgraded();
        thunderLoan.upgradeToAndCall(address(upgraded), "");

        // s_flashLoanFee now reads the slot that used to hold s_feePrecision, which was 1e18
        uint256 feeAfter = ThunderLoanUpgraded(address(proxy)).getFee();
        console2.log("fee before the upgrade:", feeBefore);
        console2.log("fee after the upgrade:", feeAfter);

        assertEq(feeAfter, 1e18);
        assertGt(feeAfter, feeBefore);

        // and it really charges 100%: a 100e18 loan is charged a 100e18 fee
        uint256 amountToBorrow = 100e18;
        uint256 fee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        console2.log("fee charged on a 100e18 loan:", fee);
        assertEq(fee, amountToBorrow);
    }
```

</details>
You can run it via

```bash
forge test --mt test_UpgradeShiftsFeeToHundredPercent_AUDIT -vv
```
and you will see something like this:

```text
Logs:
  fee before the upgrade: 3000000000000000
  fee after the upgrade: 1000000000000000000
  fee charged on a 100e18 loan: 100000000000000000000
```
The fee jumps from `0.3%` to `100%` on the upgrade itself, and a `100e18` loan is charged `100e18`.

**Recommended Mitigation:**
1. Keep the storage layout identical. Leave `s_feePrecision` as a storage variable, in its original position, instead of replacing it with a constant:

```diff
-    uint256 private s_flashLoanFee; // 0.3% ETH fee
-    uint256 public constant FEE_PRECISION = 1e18;
+    uint256 private s_feePrecision;
+    uint256 private s_flashLoanFee; // 0.3% ETH fee
```

2. If the precision really has to become a constant, do not remove the storage variable. Keep it in place as a deprecated slot and read the constant everywhere else, so nothing already written to storage moves:

```diff
-    uint256 private s_feePrecision;
+    // @deprecated left in place so the storage layout does not shift on upgrade
+    uint256 private s_feePrecision;
+    uint256 public constant FEE_PRECISION = 1e18;
```

3. Add an upgrade test to the suite that upgrades the proxy and asserts the fee and the exchange rate are unchanged, and diff `forge inspect ThunderLoan storageLayout` against `forge inspect ThunderLoanUpgraded storageLayout` before every upgrade.

# Low

### [L-1] Unprotected initializer in `ThunderLoan::initialize`, the proxy can be initialized by anyone and the deploy script never calls it

**Description:**
`initialize` is external with no access control, and it sets both the owner and the pool factory the fee maths depends on:

```javascript
function initialize(address tswapAddress) external initializer {
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
    __Oracle_init(tswapAddress);
    s_feePrecision = 1e18;
    s_flashLoanFee = 3e15; // 0.3% ETH fee
}
```

Until it is called, any address can call it on the proxy, and that caller becomes the owner and picks the pool factory. The `_disableInitializers()` in the constructor only protects the implementation contract, not the proxy, and the deploy script never initializes the proxy at all:

```javascript
ThunderLoan thunderLoan = new ThunderLoan();
new ERC1967Proxy(address(thunderLoan), "");
```

The empty init data means no initialization happens at deployment, so the proxy stays open.

**Impact:**
The first caller becomes the owner of the protocol, can point the oracle at a pool factory they control, change the flash loan fee, allow tokens, and because the owner is also the upgrade authority, replace the implementation entirely.

**Proof of Concept:**
Check the `test_AnyoneCanInitializeProxy_AUDIT` test in the `ThunderLoanTest.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the L-1: the deploy script never calls initialize, so anyone can initialize the proxy,
    // become the owner and replace the implementation
    function test_AnyoneCanInitializeProxy_AUDIT() public {
        // exactly what script/DeployThunderLoan.s.sol does, no initialize call
        ThunderLoan implementation = new ThunderLoan();
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(implementation), "");
        ThunderLoan uninitializedProxy = ThunderLoan(address(freshProxy));

        // the proxy is live, but it has no owner and no pool factory
        console.log("owner before:", uninitializedProxy.owner());
        console.log("pool factory before:", uninitializedProxy.getPoolFactoryAddress());
        assertEq(uninitializedProxy.owner(), address(0));
        assertEq(uninitializedProxy.getPoolFactoryAddress(), address(0));

        // an attacker initializes it first and becomes the owner
        address attacker = makeAddr("attacker");
        MockPoolFactory attackerFactory = new MockPoolFactory();

        vm.prank(attacker);
        uninitializedProxy.initialize(address(attackerFactory));

        console.log("owner after:", uninitializedProxy.owner());
        assertEq(uninitializedProxy.owner(), attacker);
        assertEq(
            uninitializedProxy.getPoolFactoryAddress(),
            address(attackerFactory)
        );

        // the deployer can never take it back, the initializer is spent
        vm.expectRevert();
        uninitializedProxy.initialize(address(mockPoolFactory));

        // and the attacker owns every onlyOwner function, the fee for example
        vm.prank(attacker);
        uninitializedProxy.updateFlashLoanFee(1e18);
        console2.log("fee set by attacker:", uninitializedProxy.getFee());
        assertEq(uninitializedProxy.getFee(), 1e18);

        // the owner is also the upgrade authority, so the implementation can be replaced
        ThunderLoan maliciousImplementation = new ThunderLoan();
        vm.prank(attacker);
        uninitializedProxy.upgradeToAndCall(address(maliciousImplementation), "");

        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address newImplementation = address(
            uint160(uint256(vm.load(address(freshProxy), implementationSlot)))
        );
        console.log("implementation after attacker upgrade:", newImplementation);
        assertEq(newImplementation, address(maliciousImplementation));
    }
```

</details>
You can run it via

```bash
forge test --mt test_AnyoneCanInitializeProxy_AUDIT -vv
```
and you will see something like this:

```text
Logs:
  owner before: 0x0000000000000000000000000000000000000000
  pool factory before: 0x0000000000000000000000000000000000000000
  owner after: 0x9dF0C6b0066D5317aA5b38B36850548DaCCa6B4e
  fee set by attacker: 1000000000000000000
  implementation after attacker upgrade: 0x212224D2F2d262cd093eE13240ca4873fcCBbA3C
```
The proxy starts with no owner and no pool factory, the attacker initializes it first and becomes the owner, the deployer can no longer initialize it, and the attacker then sets the fee and replaces the implementation through `upgradeToAndCall`.

**Recommended Mitigation:**
1. Initialize the proxy in the same transaction as its deployment, instead of leaving it open:

```diff
-        ThunderLoan thunderLoan = new ThunderLoan();
-        new ERC1967Proxy(address(thunderLoan), "");
+        ThunderLoan thunderLoan = new ThunderLoan();
+        new ERC1967Proxy(
+            address(thunderLoan),
+            abi.encodeCall(ThunderLoan.initialize, (tswapAddress))
+        );
```

2. Keep the `_disableInitializers()` in the constructor, it is correct and stops the implementation contract itself from being initialized.

# Question

### [Q-1] Every asset is priced only through its own TSwap WETH pool in `OracleUpgradeable::getPriceInWeth`, is a single price source the intended design?

**Description:**
`getPriceInWeth` asks the factory for the token's pool and then reads exactly one price from it:

```javascript
address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
```

So every allowed token is priced by its own TSwap WETH pool, and that single number feeds `getCalculatedFee`. There is no second source, no freshness check and no check on how deep that pool is. Is pricing every asset this way the intended design, and what should happen for a token whose WETH pool is thin, or whose pool does not exist yet?

### [Q-2] The protocol's fee maths depends on TSwap, is a less proven AMM the intended price source?

**Description:**
`IPoolFactory` is TSwap's factory, and the protocol routes all of its pricing through it. The fee for every flash loan is derived from that price:

```javascript
uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
```

That makes protocol revenue depend on an AMM that is newer and smaller than Uniswap, and on the `s_poolFactory` address chosen in `initialize`. Why was TSwap chosen over a more established venue, and is the team comfortable with a single young AMM as the price source for the fee?

### [Q-3] Allowed tokens can be frozen by a centralized issuer, what happens if Circle blocks the protocol?

**Description:**
The protocol holds the underlying token inside the `AssetToken` contract and moves it with `safeTransfer`:

```javascript
function transferUnderlyingTo(address to, uint256 amount) external onlyThunderLoan {
    i_underlying.safeTransfer(to, amount);
}
```

For a token like USDC the issuer can blacklist an address, and a blocked address can neither send nor receive. If Circle blocks the `AssetToken` or a flash loan receiver, every transfer for that asset reverts, which stops deposits, flash loans and repayments for that token while the rest of the protocol keeps working. The client's known issues list mentions weird ERC20s, but not a token with a freeze function. Should tokens that can freeze addresses be allowed at all, and is there a plan for that case?

# Informational

### [I-1] Unused import in `IFlashLoanReceiver`, the interface imports `IThunderLoan` and never uses it

**Description:**
The interface imports a contract it never references, so the import is dead code:

```javascript
import {IThunderLoan} from "./IThunderLoan.sol";
```

`IFlashLoanReceiver` only declares `executeOperation`, so `IThunderLoan` adds nothing here.

### [I-2] Missing natspec on almost the whole public surface in the interfaces, `AssetToken`, `OracleUpgradeable`, `ThunderLoan` and `ThunderLoanUpgraded`

**Description:**
Only a handful of functions carry `///` documentation. Everywhere else the parameters and return values are undefined, so an integrator or a reviewer has to read the body to guess what they mean. The callback is the clearest example, and none of its parameters are described:

```javascript
function executeOperation(
    address token,
    uint256 amount,
    uint256 fee,
    address initiator,
    bytes calldata params
) external returns (bool);
```

Nothing says whether `amount` is the borrowed amount or the borrowed amount plus the fee, or what `initiator` and `params` are for. The same gap runs through the rest of the protocol:

| File | Functions with no natspec |
|---|---|
| `interfaces/IFlashLoanReceiver.sol` | `executeOperation` |
| `interfaces/IPoolFactory.sol` | `getPool` |
| `interfaces/ITSwapPool.sol` | `getPriceOfOnePoolTokenInWeth` |
| `interfaces/IThunderLoan.sol` | `repay` |
| `protocol/AssetToken.sol` | `mint`, `burn`, `transferUnderlyingTo`, `updateExchangeRate`, `getExchangeRate`, `getUnderlying` |
| `protocol/OracleUpgradeable.sol` | `__Oracle_init`, `__Oracle_init_unchained`, `getPriceInWeth`, `getPrice`, `getPoolFactoryAddress` |
| `protocol/ThunderLoan.sol` | `deposit`, `flashloan`, `repay`, `setAllowedToken`, `getCalculatedFee`, `updateFlashLoanFee`, `isAllowedToken`, `getAssetFromToken`, `isCurrentlyFlashLoaning`, `getFee`, `getFeePrecision`, `_authorizeUpgrade` |
| `upgradedProtocol/ThunderLoanUpgraded.sol` | the same public surface as `ThunderLoan` |

That is 38 functions across five files with nothing describing their inputs, their outputs or why they exist. The protocol is upgradeable and integrates with external flash loan receivers, so the missing docs hit both the integrators and the team that has to review the next upgrade.

### [I-3] `IThunderLoan` is never implemented and its `repay` type does not match `ThunderLoan`, so the interface cannot be trusted as the protocol ABI

**Description:**
The interface declares:

```javascript
function repay(address token, uint256 amount) external;
```

but nothing implements it. `ThunderLoan` inherits `Initializable, OwnableUpgradeable, UUPSUpgradeable, OracleUpgradeable`, not `IThunderLoan`, and its own function takes a different type:

```javascript
function repay(IERC20 token, uint256 amount) public {
```

The ABI selector ends up the same because `IERC20` encodes as `address`, so the mismatch is invisible on-chain, but no compiler check keeps the interface and the contract in sync. Either make `ThunderLoan` implement `IThunderLoan`, or align the type and treat the interface as the source of truth.

### [I-4] Missing zero address check in `OracleUpgradeable::__Oracle_init`, a bad pool factory breaks all pricing instead of reverting at setup

**Description:**
The initializer stores the pool factory with no validation:

```javascript
function __Oracle_init_unchained(
    address poolFactoryAddress
) internal onlyInitializing {
    s_poolFactory = poolFactoryAddress;
}
```

So a zero or wrong address is accepted while the protocol is being set up. Every price read afterwards goes through it:

```javascript
address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
```

which means `getPriceInWeth`, and therefore the fee calculation used on deposits and flash loans, fails for every token. Validating the address at initialization turns a silent misconfiguration into a revert at setup time.

### [I-5] `ThunderLoan__ExhangeRateCanOnlyIncrease` is declared but never used, the real check lives in `AssetToken`

**Description:**
The error is declared on `ThunderLoan` and never thrown:

```javascript
error ThunderLoan__ExhangeRateCanOnlyIncrease();
```

`AssetToken::updateExchangeRate` has its own `AssetToken__ExhangeRateCanOnlyIncrease` and reverts with that one, so the copy on `ThunderLoan` is dead code. Both names are also misspelled (`Exhange` instead of `Exchange`), which makes the two easy to confuse when reading a revert.

**Recommended Mitigation:**
1. Remove the unused declaration from both implementations:

```diff
-    error ThunderLoan__ExhangeRateCanOnlyIncrease();
```

2. If the intent is to keep an error at the `ThunderLoan` level, use it where the call is made instead, and fix the `Exhange` spelling on both sides while you are there.

### [I-6] `ThunderLoan::updateFlashLoanFee` changes the fee with no event, so the change is invisible off-chain

**Description:**
`updateFlashLoanFee` writes `s_flashLoanFee` and emits nothing:

```javascript
function updateFlashLoanFee(uint256 newFee) external onlyOwner {
    if (newFee > s_feePrecision) {
        revert ThunderLoan__BadNewFee();
    }
    s_flashLoanFee = newFee;
}
```

The fee is a protocol-wide parameter that borrowers price every flash loan against, so an indexer or front end has no way to see the change except by polling `getFee()`. Slither reports it as `events-maths` and Aderyn as `L-4`, and the upgraded implementation has the identical function.

**Recommended Mitigation:**
1. Emit an event with both the old and the new value:

```diff
+    event FlashLoanFeeUpdated(uint256 oldFee, uint256 newFee);
+
     function updateFlashLoanFee(uint256 newFee) external onlyOwner {
         if (newFee > s_feePrecision) {
             revert ThunderLoan__BadNewFee();
         }
+        uint256 oldFee = s_flashLoanFee;
         s_flashLoanFee = newFee;
+        emit FlashLoanFeeUpdated(oldFee, newFee);
     }
```

2. Apply the same change to `upgradedProtocol/ThunderLoanUpgraded.sol`, which has the same handler guarded by `FEE_PRECISION` instead of `s_feePrecision`.

# Gas

No gas findings.
