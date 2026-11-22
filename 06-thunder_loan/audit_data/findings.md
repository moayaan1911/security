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
