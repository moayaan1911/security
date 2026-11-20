### [H-1] Wrong fee in `TSwapPool::getInputAmountBasedOnOutput`, exact output swaps charge the caller about 10x the fair input

**Description::**
`getInputAmountBasedOnOutput` works out how much input a caller must pay for an exact output amount, but the fee multiplier is `10000` where it should be `1000`:

```javascript
return
    ((inputReserves * outputAmount) * 10000) /
    ((outputReserves - outputAmount) * 997);
```

The mirror function, `getOutputAmountBasedOnInput`, uses the correct `997 / 1000` fee pair, which is what makes the mistake obvious:

```javascript
uint256 inputAmountMinusFee = inputAmount * 997;
uint256 denominator = (inputReserves * 1000) + inputAmountMinusFee;
```

So the required input comes out roughly **10x** too large.

**Impact::**
Every caller of `swapExactOutput` is overcharged about 10x, and `sellPoolTokens` routes through the same function. The extra tokens stay in the pool, so the caller loses real funds on every exact output swap while the liquidity providers gain at their expense. It also makes the pool's own invariant (`x * y = k`) blow up in the pool's favour instead of holding.

**Proof of Concept::**
Check the `test_SwapExactOutputOvercharges_AUDIT` test in the `TSwapPool.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the HIGH: getInputAmountBasedOnOutput multiplies by 10000 instead of 1000,
    // so an exact output swap charges the caller roughly 10x the fair input
    function test_SwapExactOutputOvercharges_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 wethReserves = weth.balanceOf(address(pool));
        uint256 poolTokenReserves = poolToken.balanceOf(address(pool));
        uint256 outputWeth = 0.5e18;

        // the same formula with the fee applied once, which is what the caller should pay
        uint256 fairInput = (poolTokenReserves * outputWeth * 1000) /
            ((wethReserves - outputWeth) * 997);

        // what the pool actually asks for
        uint256 quotedInput = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolTokenReserves,
            wethReserves
        );

        console.log("charged input:", quotedInput);
        console.log("fair input:", fairInput);

        assertGt(quotedInput, fairInput * 9);

        // and it is what the caller really pays
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        uint256 balanceBefore = poolToken.balanceOf(user);
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        uint256 paid = balanceBefore - poolToken.balanceOf(user);
        vm.stopPrank();

        console.log("actually paid:", paid);
        assertEq(paid, quotedInput);
        assertGt(paid, fairInput * 9);
    }
```

</details>
You can run it via

```bash
forge test --mt test_SwapExactOutputOvercharges_AUDIT -vv
```
and you will see something like this:

```text
Logs:
  charged input: 5040246367242430810
  fair input: 504024636724243081
  actually paid: 5040246367242430810
```
The caller pays `5.04e18` pool tokens for `0.5e18` WETH, where the fair price is `0.504e18`. A clean 10x, and the pool really takes that much, it is not just the quote function.

**Recommended Solution::**
1. Use `1000` in the numerator, so the fee is applied once like every other AMM:

```diff
-        return
-            ((inputReserves * outputAmount) * 10000) /
-            ((outputReserves - outputAmount) * 997);
+        return
+            ((inputReserves * outputAmount) * 1000) /
+            ((outputReserves - outputAmount) * 997);
```

2. Replace the `997`, `1000` and `10000` literals with named constants in both pricing functions, so the fee is defined once and the two functions cannot drift apart again:

```diff
+    uint256 private constant FEE_MULTIPLIER = 997;
+    uint256 private constant FEE_BASE = 1000;
```
The names matter: `997/1000` is the fee factor, and the exact output formula uses its inverse (`FEE_BASE / FEE_MULTIPLIER`), so naming them after the fee factor avoids repeating this mistake.
___
### [H-2] Swap incentive in `TSwapPool::_swap` pays out 1e18 of the output token every 10th swap, breaking the `x * y = k` invariant

**Description::**
Every tenth swap, `_swap` sends the caller an extra `1e18` of the output token, straight out of the pool's reserves:

```javascript
swap_count++;
if (swap_count >= SWAP_COUNT_MAX) {
    swap_count = 0;
    outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
}
```

The pool pays that token out without receiving any input for it, so it is a direct transfer from the liquidity providers to the caller.

**Impact::**
The pool's `x * y = k` falls every tenth swap instead of holding or growing, which means liquidity providers lose value on a fixed schedule. It is also farmable, since the bonus is a flat `1e18` regardless of swap size, so anyone can make nine dust swaps and take `1e18` on the tenth. And because the transfer happens before the swap is settled, a pool holding less than `1e18` of the output token cannot complete its tenth swap at all, it reverts. In the PoC the bonus is `1.0978e18` WETH received against an expected `0.0978e18`, and `k` drops from `1.0000269e40` to `9.899298e39`.

**Proof of Concept::**
Check the `test_SwapIncentiveBreaksInvariant_AUDIT` test in the `TSwapPool.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the H-2: every 10th swap pays the caller 1e18 of the output token for free, which drops
    // the pool's x * y = k instead of holding it
    function test_SwapIncentiveBreaksInvariant_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);

        // nine normal swaps, the tenth is the one that pays the bonus
        for (uint256 i = 0; i < 9; i++) {
            pool.swapExactInput(
                poolToken,
                0.1e18,
                weth,
                0,
                uint64(block.timestamp)
            );
        }

        uint256 wethReserves = weth.balanceOf(address(pool));
        uint256 poolTokenReserves = poolToken.balanceOf(address(pool));
        uint256 kBefore = wethReserves * poolTokenReserves;

        // what the pool itself says this swap should pay out
        uint256 expectedOut = pool.getOutputAmountBasedOnInput(
            0.1e18,
            poolTokenReserves,
            wethReserves
        );

        uint256 wethBefore = weth.balanceOf(user);
        pool.swapExactInput(poolToken, 0.1e18, weth, 0, uint64(block.timestamp));
        uint256 received = weth.balanceOf(user) - wethBefore;
        vm.stopPrank();

        uint256 kAfter = weth.balanceOf(address(pool)) *
            poolToken.balanceOf(address(pool));

        console.log("expected out:", expectedOut);
        console.log("actually received:", received);
        console.log("k before:", kBefore);
        console.log("k after:", kAfter);

        // the caller got 1e18 free on top of the swap
        assertEq(received, expectedOut + 1e18);

        // and the pool's product dropped instead of holding
        assertLt(kAfter, kBefore);
    }
```

</details>
You can run it via

```bash
forge test --mt test_SwapIncentiveBreaksInvariant_AUDIT -vv
```
and you will see something like this:

```text
Logs:
  expected out: 97835298857383282
  actually received: 1097835298857383282
  k before: 10000268662499607603075500000000000000000
  k after: 9899298366356141334213000000000000000000
```
The pool paid out 1e18 it never received, and the product dropped with it.

**Recommended Solution::**
1. Remove the bonus from the swap path entirely. A pool's reserves should only ever move by the swap maths.

```diff
-    uint256 private swap_count = 0;
-    uint256 private constant SWAP_COUNT_MAX = 10;

...
-        swap_count++;
-        if (swap_count >= SWAP_COUNT_MAX) {
-            swap_count = 0;
-            outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
-        }
```
Removing the bonus leaves `swap_count` and `SWAP_COUNT_MAX` dead, so delete both declarations for clarity. No compiler warning is involved, `solc` does not warn about unused state variables.

2. If the incentive is a product requirement, fund it from a separate rewards contract or an owner funded balance, so paying it never touches LP reserves, and make it proportional to the swap size so it cannot be farmed with dust swaps.

3. The PoC has to change with the fix. It asserts `received == expectedOut + 1e18`, which only holds while the bonus is paid, so after removing the bonus it should assert `received == expectedOut` and that `k` no longer falls.
___
### [M-1] No maximum input check in `TSwapPool::swapExactOutput`, a caller can be charged an input far above the fair price

**Description::**
`swapExactInput` takes a `minOutputAmount` so the caller can bound their slippage, but `swapExactOutput` has no equivalent. It works out the input itself from `getInputAmountBasedOnOutput` and then swaps straight away, so the caller has no parameter to say "I will not pay more than X":

```javascript
inputAmount = getInputAmountBasedOnOutput(
    outputAmount,
    inputReserves,
    outputReserves
);

_swap(inputToken, inputAmount, outputToken, outputAmount);
```

**Impact::**
A caller who submits an exact output swap can be sandwiched, or simply have their transaction land after the price has moved, and the swap still goes through at the worse price. Nothing reverts and there is no way to protect themselves. In the PoC the same `1e18` WETH output costs `10.13` pool tokens at first and `22.88` pool tokens after one big swap, a 2.26x overpay that the caller cannot stop.

**Proof of Concept::**
Check the `test_SwapExactOutputNoMaxInput_AUDIT` test in the `TSwapPool.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the M-1: swapExactOutput has no max input parameter, so a caller can be charged a much
    // worse price and has nothing to protect them (swapExactInput has minOutputAmount)
    function test_SwapExactOutputNoMaxInput_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 outputWeth = 1e18;

        // what the caller would pay at the current price
        uint256 inputBefore = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );

        // someone swaps first and makes WETH scarcer, moving the price against the caller
        poolToken.mint(user, 100e18);
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactInput(poolToken, 50e18, weth, 0, uint64(block.timestamp));
        vm.stopPrank();

        uint256 inputAfter = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );

        console.log("input before the price move:", inputBefore);
        console.log("input after the price move:", inputAfter);
        assertGt(inputAfter, inputBefore);

        // the swap still goes through at the worse price, there is no max input to set
        poolToken.mint(user, inputAfter);
        vm.startPrank(user);
        uint256 balanceBefore = poolToken.balanceOf(user);
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        uint256 paid = balanceBefore - poolToken.balanceOf(user);
        vm.stopPrank();

        console.log("paid at the worse price:", paid);
        assertEq(paid, inputAfter);
    }
```

</details>
You can run it via

```bash
forge test --mt test_SwapExactOutputNoMaxInput_AUDIT -vv
```
and you will see something like this:

```text
Logs:
  input before the price move: 10131404313951956880
  input after the price move: 22888113791382523076
  paid at the worse price: 22888113791382523076
```
The price moved against the caller and the exact output swap executed anyway, at more than double the input.

**Recommended Solution::**
1. Take a `maxInputAmount` and revert when the pool asks for more, the mirror of `minOutputAmount` in `swapExactInput`:

```diff
+    error TSwapPool__InputTooHigh(uint256 inputAmount, uint256 maxInputAmount);
+
     function swapExactOutput(
         IERC20 inputToken,
         IERC20 outputToken,
         uint256 outputAmount,
+        uint256 maxInputAmount,
         uint64 deadline
     )
...
         inputAmount = getInputAmountBasedOnOutput(
             outputAmount,
             inputReserves,
             outputReserves
         );
 
+        if (inputAmount > maxInputAmount) {
+            revert TSwapPool__InputTooHigh(inputAmount, maxInputAmount);
+        }
+
         _swap(inputToken, inputAmount, outputToken, outputAmount);
```

2. This adds a parameter to a public function, so `sellPoolTokens` and any integrator calling `swapExactOutput` has to be updated in the same change.
___
### [M-2] Wrong amount semantics in `TSwapPool::sellPoolTokens`, the amount to sell is used as the exact WETH output

**Description::**
`sellPoolTokens` is documented as "sell this many pool tokens for WETH", but it forwards the amount to `swapExactOutput` as the **output**:

```javascript
function sellPoolTokens(uint256 poolTokenAmount) external returns (uint256 wethAmount) {
    return
        swapExactOutput(
            i_poolToken,
            i_wethToken,
            poolTokenAmount,
            uint64(block.timestamp)
        );
}
```

So the caller receives exactly `poolTokenAmount` in WETH, and pays whatever number of pool tokens the pool decides it needs for that. The value it returns as `wethAmount` is also wrong: `swapExactOutput` returns its computed **input**, so `wethAmount` is really the pool tokens that were spent.

**Impact::**
The caller gets a completely different trade than they asked for. In the PoC a seller asking to sell `5e18` pool tokens is charged `52.78e18` pool tokens to receive exactly `5e18` WETH, and a seller holding `10e18` pool tokens, twice what they intend to sell, still reverts because the pool tries to pull `52.78e18`. On top of that, the missing max input check from `M-1` and the deadline hardcoded to `block.timestamp` mean the caller has no slippage protection at all on this path.

**Proof of Concept::**
Check the `test_SellPoolTokensWrongAmount_AUDIT` test in the `TSwapPool.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the M-2: sellPoolTokens passes the amount to sell as the exact WETH output, so the
    // caller pays a completely different amount of pool tokens than they asked to sell
    function test_SellPoolTokensWrongAmount_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 amountToSell = 5e18;

        // an honest seller holding more than 5 pool tokens cannot sell them either
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        vm.expectRevert();
        pool.sellPoolTokens(amountToSell);
        vm.stopPrank();

        // with a lot more tokens funded, the real behaviour shows up
        poolToken.mint(user, 200e18);
        vm.startPrank(user);
        uint256 poolTokensBefore = poolToken.balanceOf(user);
        uint256 wethBefore = weth.balanceOf(user);
        pool.sellPoolTokens(amountToSell);
        uint256 poolTokensSpent = poolTokensBefore - poolToken.balanceOf(user);
        uint256 wethReceived = weth.balanceOf(user) - wethBefore;
        vm.stopPrank();

        console.log("asked to sell:", amountToSell);
        console.log("pool tokens actually spent:", poolTokensSpent);
        console.log("weth actually received:", wethReceived);

        // the caller receives exactly the number they passed in, and pays a different amount
        assertEq(wethReceived, amountToSell);
        assertGt(poolTokensSpent, amountToSell);
    }
```

</details>
You can run it via

```bash
forge test --mt test_SellPoolTokensWrongAmount_AUDIT -vv
```
and you will see something like this:

```text
Logs:
  asked to sell: 5000000000000000000
  pool tokens actually spent: 52789948793749670062
  weth actually received: 5000000000000000000
```
The seller asked to sell `5e18` pool tokens and paid `52.78e18` of them instead.

**Recommended Solution::**
1. Use the input based swap and let the caller set the minimum WETH they will accept, which is what "sell" means:

```diff
-    function sellPoolTokens(uint256 poolTokenAmount) external returns (uint256 wethAmount) {
-        return
-            swapExactOutput(
-                i_poolToken,
-                i_wethToken,
-                poolTokenAmount,
-                uint64(block.timestamp)
-            );
-    }
+    function sellPoolTokens(
+        uint256 poolTokenAmount,
+        uint256 minWethToReceive,
+        uint64 deadline
+    ) external returns (uint256 wethAmount) {
+        wethAmount = swapExactInput(
+            i_poolToken,
+            poolTokenAmount,
+            i_wethToken,
+            minWethToReceive,
+            deadline
+        );
+    }
```

2. Taking a real `deadline` also fixes the hardcoded `uint64(block.timestamp)` in the current version, which makes the deadline check on this path meaningless.

3. `swapExactInput` currently returns a hardcoded `0`, because its named return is never assigned. That is logged as a separate Informational finding, and it has to be fixed before this return value can be trusted.
___
### [L-1] Missing deadline check in `TSwapPool::deposit`, an expired transaction can still be executed

**Description::**
`deposit` takes a `deadline` and the natspec even documents it, but the `revertIfDeadlinePassed` modifier is never applied, so the parameter is not read at all:

```javascript
function deposit(
    uint256 wethToDeposit,
    uint256 minimumLiquidityTokensToMint,
    uint256 maximumPoolTokensToDeposit,
    uint64 deadline
)
    external
    revertIfZero(wethToDeposit)
    returns (uint256 liquidityTokensToMint)
```

That modifier already exists in the contract, and `withdraw`, `swapExactInput` and `swapExactOutput` all use it.

**Impact::**
A deposit transaction can sit in the mempool and be included at any later time, whatever deadline the user set, and the user has no way to invalidate it. On a normal deposit the pricing damage is bounded, because `minimumLiquidityTokensToMint` and `maximumPoolTokensToDeposit` are both checked there, which is why this is Low and not higher. Note that the first deposit does not check the minimum at all, which is logged as `I-6`. What is missing either way is the deadline the user asked for.

**Proof of Concept::**
Check the `test_DepositIgnoresDeadline_AUDIT` test in the `TSwapPool.t.sol` file:
<details>
<summary>Here's the full code</summary>

```javascript
    // the L-1: deposit takes a deadline but never checks it, so an expired deadline is accepted
    function test_DepositIgnoresDeadline_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);

        // a deadline that has already passed
        uint64 expiredDeadline = uint64(block.timestamp - 1);

        // deposit does not look at the deadline, so it goes through
        pool.deposit(100e18, 100e18, 100e18, expiredDeadline);
        console.log(
            "lp tokens minted with an expired deadline:",
            pool.balanceOf(liquidityProvider)
        );
        assertEq(pool.balanceOf(liquidityProvider), 100e18);

        // the same expired deadline is rejected by withdraw
        vm.expectRevert(
            abi.encodeWithSelector(
                TSwapPool.TSwapPool__DeadlineHasPassed.selector,
                expiredDeadline
            )
        );
        pool.withdraw(100e18, 100e18, 100e18, expiredDeadline);
        vm.stopPrank();
    }
```

</details>
You can run it via

```bash
forge test --mt test_DepositIgnoresDeadline_AUDIT -vv
```
and you will see something like this:

```text
Logs:
  lp tokens minted with an expired deadline: 100000000000000000000
```
An expired deadline is accepted by `deposit` and rejected by `withdraw`, in the same run.

**Recommended Solution::**
1. Apply the modifier that already exists in the contract:

```diff
     function deposit(
         uint256 wethToDeposit,
         uint256 minimumLiquidityTokensToMint,
         uint256 maximumPoolTokensToDeposit,
         uint64 deadline
     )
         external
+        revertIfDeadlinePassed(deadline)
         revertIfZero(wethToDeposit)
         returns (uint256 liquidityTokensToMint)
```

2. The PoC has to be flipped after the fix: it currently asserts that the expired deposit succeeds, and it should expect `TSwapPool__DeadlineHasPassed` instead.
___
### [I-1] `0.8.20` is compiled for Shanghai in `TSwapPool` and `PoolFactory`, PUSH0 can break deployment on some chains

**Description::**
Both contracts are pinned to `0.8.20`, and that version defaults to the Shanghai EVM version, so the compiler emits `PUSH0` opcodes. Any chain that does not support PUSH0 will fail to deploy the bytecode, and Slither's `pragma` detector also reports that the repo mixes pragma ranges across the imported interfaces.

**Recommended Solution::**
1. Pin the EVM version for the build if any target chain lacks PUSH0, instead of relying on the compiler default:

```diff
 [profile.default]
 src = "src"
 out = "out"
+evm_version = "paris"
```

2. If PUSH0 is acceptable on every target chain, this can be closed as acknowledged, but it is worth writing down which chains were checked.
___
### [I-2] Magic numbers and large literals in `TSwapPool`, the fee values should be named constants and `MINIMUM_WETH_LIQUIDITY` written as `1e9`

**Description::**
The fee pair and the minimum liquidity are written as bare literals. `MINIMUM_WETH_LIQUIDITY = 1_000_000_000` should be `1e9`, and the pricing functions use `997`, `1000` and `1e18` inline. Aderyn reports both `large-numeric-literal` and `literal-instead-of-constant` for these lines, and the mistake in `H-1` came from exactly this kind of hand written number.

**Recommended Solution::**
1. Use scientific notation for the large literal:

```diff
-    uint256 private constant MINIMUM_WETH_LIQUIDITY = 1_000_000_000;
+    uint256 private constant MINIMUM_WETH_LIQUIDITY = 1e9;
```

2. Name the fee pair once, so both pricing functions read from the same definition:

```diff
+    uint256 private constant FEE_MULTIPLIER = 997;
+    uint256 private constant FEE_BASE = 1000;
+    uint256 private constant ONE_E18 = 1e18;
...
-        uint256 inputAmountMinusFee = inputAmount * 997;
-        uint256 denominator = (inputReserves * 1000) + inputAmountMinusFee;
+        uint256 inputAmountMinusFee = inputAmount * FEE_MULTIPLIER;
+        uint256 denominator = (inputReserves * FEE_BASE) + inputAmountMinusFee;

...
-        return
-            ((inputReserves * outputAmount) * 10000) /
-            ((outputReserves - outputAmount) * 997);
+        return
+            ((inputReserves * outputAmount) * FEE_BASE) /
+            ((outputReserves - outputAmount) * FEE_MULTIPLIER);
```
The second hunk is the same numerator fix that `H-1` requires, and `H-1` already introduces the `FEE_MULTIPLIER` and `FEE_BASE` declarations, so declare those constants once when applying both findings.

3. Replace the `1e18` in `getPriceOfOneWethInPoolTokens` and `getPriceOfOnePoolTokenInWeth` with `ONE_E18`.
___
### [I-3] Event address parameters are not indexed in `TSwapPool::Swap`, which makes logs harder to filter

**Description::**
`tokenIn` and `tokenOut` are plain parameters while only `swapper` is indexed, so an indexer cannot filter swaps by token without scanning and decoding every log.

```javascript
event Swap(
    address indexed swapper,
    IERC20 tokenIn,
    uint256 amountTokenIn,
    IERC20 tokenOut,
    uint256 amountTokenOut
);
```

**Recommended Solution::**
1. Index both token addresses:

```diff
-        IERC20 tokenIn,
+        IERC20 indexed tokenIn,
         uint256 amountTokenIn,
-        IERC20 tokenOut,
+        IERC20 indexed tokenOut,
         uint256 amountTokenOut
```
___
### [I-4] Missing zero address checks in the `TSwapPool` and `PoolFactory` constructors

**Description::**
Neither constructor validates its address arguments, and both are stored in `immutable` variables, so a zero address can never be corrected after deployment. A pool deployed with a zero `wethToken` or `poolToken` is broken for its whole lifetime. Slither reports this as `missing-zero-check`.

**Recommended Solution::**
1. Reject zero addresses in the pool constructor, reusing the error that already exists:

```diff
     ) ERC20(liquidityTokenName, liquidityTokenSymbol) {
+        if (poolToken == address(0) || wethToken == address(0)) {
+            revert TSwapPool__InvalidToken();
+        }
         i_wethToken = IERC20(wethToken);
```

2. Do the same for the factory:

```diff
+    error PoolFactory__InvalidWethToken();
+
     constructor(address wethToken) {
+        if (wethToken == address(0)) {
+            revert PoolFactory__InvalidWethToken();
+        }
         i_wethToken = wethToken;
```
___
### [I-5] The first deposit uses `maximumPoolTokensToDeposit` as the exact amount to pull in `TSwapPool::deposit`

**Description::**
In the first deposit branch the pool passes `maximumPoolTokensToDeposit` straight into the transfer, so the parameter stops being a maximum and becomes the exact amount taken from the caller:

```javascript
_addLiquidityMintAndTransfer(
    wethToDeposit,
    maximumPoolTokensToDeposit,
    wethToDeposit
);
```

Every later deposit treats the same parameter as a ceiling, so the meaning changes with the pool state, and a caller who sets a loose ceiling to be safe ends up depositing all of it.

**Recommended Solution::**
1. Stop overloading the parameter. The cleanest split is a separate `initialPoolTokensToDeposit` parameter, used only by the first deposit, while `maximumPoolTokensToDeposit` stays a bound for every later one:

```diff
     function deposit(
         uint256 wethToDeposit,
         uint256 minimumLiquidityTokensToMint,
         uint256 maximumPoolTokensToDeposit,
+        uint256 initialPoolTokensToDeposit,
         uint64 deadline
     )
...
-            _addLiquidityMintAndTransfer(
-                wethToDeposit,
-                maximumPoolTokensToDeposit,
-                wethToDeposit
-            );
+            _addLiquidityMintAndTransfer(
+                wethToDeposit,
+                initialPoolTokensToDeposit,
+                wethToDeposit
+            );
```

2. This adds a parameter to a public function, so every `deposit` caller has to be updated in the same change, including the unit tests, the invariant setup and the handler.

3. If the parameter has to keep both meanings, document it on the natspec and validate it, so nobody passes `type(uint256).max` expecting a ceiling.
___
### [I-6] `minimumLiquidityTokensToMint` is ignored on the first deposit in `TSwapPool::deposit`

**Description::**
The first deposit branch mints one liquidity token per wei of WETH and never compares the result with the caller's minimum, so the slippage parameter the caller passed is silently dropped:

```javascript
liquidityTokensToMint = wethToDeposit;
```

The other branch does check it.

**Recommended Solution::**
1. Apply the same check on the first deposit, using the error that already exists:

```diff
             liquidityTokensToMint = wethToDeposit;
+            if (liquidityTokensToMint < minimumLiquidityTokensToMint) {
+                revert TSwapPool__MinLiquidityTokensToMintTooLow(
+                    minimumLiquidityTokensToMint,
+                    liquidityTokensToMint
+                );
+            }
```
___
### [I-7] Swapped arguments in the `LiquidityAdded` event in `TSwapPool::_addLiquidityMintAndTransfer`

**Description::**
The event declares the amounts as `(wethDeposited, poolTokensDeposited)` but the emit passes them the other way round, so every indexer reading this event records the two amounts swapped:

```javascript
event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
...
emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
```

The mirror event `LiquidityRemoved` is emitted in the right order, so only this one is wrong.

**Recommended Solution::**
1. Match the emit to the declaration:

```diff
-        emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
+        emit LiquidityAdded(msg.sender, wethToDeposit, poolTokensToDeposit);
```
___
### [I-8] No check that `outputAmount < outputReserves` in `TSwapPool::getInputAmountBasedOnOutput`

**Description::**
The subtraction `outputReserves - outputAmount` underflows when the caller asks for the whole reserve or more, so the call reverts with an arithmetic panic rather than a clear protocol error. `getOutputAmountBasedOnInput` at least rejects a zero reserve, this function does not check the relation at all.

**Recommended Solution::**
1. Reject the case explicitly, with an error the caller can read:

```diff
         revertIfZero(outputAmount)
         revertIfZero(outputReserves)
         returns (uint256 inputAmount)
     {
+        if (outputAmount >= outputReserves) {
+            revert TSwapPool__OutputTooLow(outputAmount, outputReserves - 1);
+        }
         return
```
___
### [I-9] `TSwapPool::swapExactInput` is public but is only called externally

**Description::**
The function is never used inside the contract, so `external` would be cheaper and clearer about its role. Aderyn reports this as `public-function-not-used-internally`.

**Recommended Solution::**
1. Mark it `external`:

```diff
-        public
+        external
         revertIfZero(inputAmount)
         revertIfDeadlinePassed(deadline)
```

2. Note the interaction with `M-2`: the recommended fix there calls `swapExactInput` from `sellPoolTokens`, so if that fix is applied this function has to stay `public`.
___
### [I-10] `TSwapPool::swapExactInput` always returns `0`, the named return is never assigned

**Description::**
The function promises a return value and then never sets it, so every successful swap reports `0` back to the caller:

```javascript
returns (
    uint256 output
)
{
    ...
    _swap(inputToken, inputAmount, outputToken, outputAmount);
}
```

Any integrator that uses the return value accounts the swap as zero output, and the value is silently wrong rather than reverting.

**Recommended Solution::**
1. Assign the computed output before returning:

```diff
         _swap(inputToken, inputAmount, outputToken, outputAmount);
+        output = outputAmount;
     }
```
___
### [I-11] Hardcoded deadline in `TSwapPool::sellPoolTokens`, the deadline check can never fire

**Description::**
The function passes `uint64(block.timestamp)` as the deadline, so `revertIfDeadlinePassed` compares the deadline against the same timestamp and always passes. The caller cannot express when the trade stops being valid.

**Recommended Solution::**
1. Take the deadline from the caller and pass it through:

```diff
-    function sellPoolTokens(uint256 poolTokenAmount) external returns (uint256 wethAmount) {
+    function sellPoolTokens(
+        uint256 poolTokenAmount,
+        uint64 deadline
+    ) external returns (uint256 wethAmount) {
         return
             swapExactOutput(
                 i_poolToken,
                 i_wethToken,
                 poolTokenAmount,
-                uint64(block.timestamp)
+                deadline
             );
     }
```

2. This is also covered by the rewrite in `M-2`.
___
### [I-12] `TSwapPool::getPoolTokensToDepositBasedOnWeth` reverts on a pool with no WETH

**Description::**
The function divides by `wethReserves`, so on a pool that has not been funded yet, or one that has been fully withdrawn, the division is by zero and the call reverts. Internally it is only reached when liquidity tokens exist, but the function is public and callable at any time.

```javascript
return (wethToDeposit * poolTokenReserves) / wethReserves;
```

**Recommended Solution::**
1. Return `0` for an empty pool instead of reverting, so the helper stays usable off-chain:

```diff
         uint256 poolTokenReserves = i_poolToken.balanceOf(address(this));
         uint256 wethReserves = i_wethToken.balanceOf(address(this));
+        if (wethReserves == 0) {
+            return 0;
+        }
         return (wethToDeposit * poolTokenReserves) / wethReserves;
```
___
### [I-13] Unused error `PoolFactory__PoolDoesNotExist` in `PoolFactory`

**Description::**
The error is declared and never used, so nothing in the factory ever tells a caller that a pool does not exist. Aderyn reports this as `unused-error`.

**Recommended Solution::**
1. Use it where the factory currently returns `address(0)` for an unknown pool:

```diff
     function getPool(address tokenAddress) external view returns (address) {
-        return s_pools[tokenAddress];
+        address pool = s_pools[tokenAddress];
+        if (pool == address(0)) {
+            revert PoolFactory__PoolDoesNotExist(tokenAddress);
+        }
+        return pool;
     }
```

2. Or remove the declaration. Note that option 1 changes the behaviour of a `view` function, so any caller that checks for `address(0)` has to be updated.
___
### [I-14] `PoolFactory::createPool` does not reject `tokenAddress == wethToken`

**Description::**
The factory accepts the WETH address as the pool token, so a WETH/WETH pool can be created and registered. Every swap on it reverts with `TSwapPool__InvalidToken` because `inputToken == outputToken`, so the pool is unusable while still showing up in the registry.

**Recommended Solution::**
1. Reject the WETH token when creating a pool:

```diff
 contract PoolFactory {
     error PoolFactory__PoolAlreadyExists(address tokenAddress);
+    error PoolFactory__InvalidWethToken();
 
+...
     function createPool(address tokenAddress) external returns (address) {
+        if (tokenAddress == i_wethToken) {
+            revert PoolFactory__InvalidWethToken();
+        }
         if (s_pools[tokenAddress] != address(0)) {
             revert PoolFactory__PoolAlreadyExists(tokenAddress);
         }
```
The same error is introduced in `I-4`, so declare it once if both findings are applied.
___
### [I-15] State is written after the external calls in `PoolFactory::createPool`, Aderyn reports it as a High reentrancy with no impact

**Description::**
`createPool` calls `IERC20(tokenAddress).name()` twice and deploys the pool before it writes `s_pools` and `s_tokens`, so Aderyn's `reentrancy-state-change` detector reports it as a High. A malicious token can re-enter `createPool` from `name()`, and because the duplicate guard reads `s_pools[tokenAddress]`, which is still empty during that call, a second pool can be deployed and then overwritten, leaving an unregistered ghost pool. No funds are at risk: the factory holds no ETH or tokens, `createPool` is permissionless, and the only caller who can be harmed is the attacker, who pays the gas. That is why this is filed as informational rather than High.

**Recommended Solution::**
1. If the pattern should be closed anyway, make `createPool` `nonReentrant` with OpenZeppelin's `ReentrancyGuard`, which blocks the re-entrant second deployment:

```diff
+import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
 
-contract PoolFactory {
+contract PoolFactory is ReentrancyGuard {
...
-    function createPool(address tokenAddress) external returns (address) {
+    function createPool(address tokenAddress) external nonReentrant returns (address) {
```

2. Since there is no fund flow through the factory, this is optional hardening rather than a required fix.
___
### [I-16] `PoolFactory::createPool` reverts for any token whose `name()` reverts

**Description::**
The factory reads the token metadata with no `try/catch` and no check that the contract implements the metadata extension, so a token without `name()` can never get a pool, and the caller only sees a low level revert. This may be intended, but it is not documented anywhere.

**Recommended Solution::**
1. Handle the case explicitly, so the failure is a clear protocol error:

```diff
+import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
+
...
-        string memory liquidityTokenName = string.concat("T-Swap ", IERC20(tokenAddress).name());
+        string memory tokenName;
+        try IERC20Metadata(tokenAddress).name() returns (string memory name_) {
+            tokenName = name_;
+        } catch {
+            revert PoolFactory__PoolDoesNotExist(tokenAddress);
+        }
+        string memory liquidityTokenName = string.concat("T-Swap ", tokenName);
```

2. The next line makes a second metadata call for the symbol. It is left alone here because `I-17` changes it to `symbol()`, so guard that read the same way when `I-17` is applied, otherwise a token that reverts on `symbol()` can still brick `createPool`.
___
### [I-17] LP token symbol is built from the token name in `PoolFactory::createPool`

**Description::**
The name is built from `name()`, which is correct, but the symbol is built from `name()` as well instead of `symbol()`:

```javascript
string memory liquidityTokenName = string.concat("T-Swap ", IERC20(tokenAddress).name());
string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
```

A USDT pool therefore mints LP tokens with the symbol `tsTether USD` instead of `tsUSDT`.

**Recommended Solution::**
1. Read the symbol for the symbol:

```diff
-        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
+        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol());
```
