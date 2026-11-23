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
### [I-1] Unused import in `IFlashLoanReceiver`, the interface imports `IThunderLoan` and never uses it

**Description::**
The interface imports a contract it never references, so the import is dead code:

```javascript
import {IThunderLoan} from "./IThunderLoan.sol";
```

`IFlashLoanReceiver` only declares `executeOperation`, so `IThunderLoan` adds nothing here.
___
### [I-2] Missing natspec on `IFlashLoanReceiver::executeOperation`, the parameters are undocumented

**Description::**
The only documentation is a `@dev` line pointing at Aave, and none of the parameters are described:

```javascript
function executeOperation(
    address token,
    uint256 amount,
    uint256 fee,
    address initiator,
    bytes calldata params
) external returns (bool);
```

A receiver author has to guess whether `amount` is the borrowed amount or the amount plus fee, and what `initiator` and `params` are for. This is the interface every flash loan receiver implements, so unclear parameters turn into integrator bugs.
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
