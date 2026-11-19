### [L-1] Wrong liquidity token symbol in `PoolFactory::createPool`, the symbol is built from the token name instead of the token symbol

**Description::**
`createPool` builds the LP token name and it is correct, but the symbol is also built from `name()` instead of `symbol()`:

```javascript
string memory liquidityTokenName = string.concat("T-Swap ", IERC20(tokenAddress).name());
string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
```

So a USDT pool would mint LP tokens with the symbol `tsTether USD` instead of `tsUSDT`.

**Impact::**
Every pool gets a wrong and overlong symbol. The LP token is meant to read as `ts` + the underlying symbol, so wallets, DEX interfaces and scripts that display `symbol()` show the wrong value. No funds are at risk.

**Proof of Concept::**
The pool is an ERC20 whose symbol comes straight from the constructor:

```javascript
constructor(
    address poolToken,
    address wethToken,
    string memory liquidityTokenName,
    string memory liquidityTokenSymbol
) ERC20(liquidityTokenName, liquidityTokenSymbol) {
```

Deploy a pool for any token and call `symbol()` on it, the value is `"ts"` + the token's full name, not its symbol.

**Recommended Solution::**

```diff
-        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
+        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol());
```
___
### [I-1] State change after external calls in `PoolFactory::createPool`, the reentrancy Aderyn reports as High has no impact

**Description::**
`createPool` calls `IERC20(tokenAddress).name()` twice and deploys the pool before it writes `s_pools` and `s_tokens`, so Aderyn's `reentrancy-state-change` detector reports it as High. A malicious token can re-enter `createPool` from `name()`, and because the duplicate guard reads `s_pools[tokenAddress]`, which is still empty during that re-entrant call, a second pool can be created for the same token and left unregistered.

**Impact::**
No funds are at risk: the factory holds no ETH or tokens, `createPool` is permissionless, and the only caller who can be harmed is the attacker, who pays the gas. The worst case is a ghost pool that no one can reach through `getPool`, so this is informational and not High.

**Recommended Solution::**
1. If the pattern should be closed, make `createPool` `nonReentrant` with OpenZeppelin's `ReentrancyGuard`, which blocks the re-entrant second pool.

2. Since there is no fund flow through the factory, this is optional hardening rather than a required fix.