# Protocol
TSwap - fork of Uniswap V1

# Findings
- too less coverage in tests verified via forge coverage
- no invariant test at all! Absolute red flag. Writing invariant test myself to find bugs
- no check for deadline in the deposit function, will return back at it later
- Aderyn H-1 (reentrancy, state change after external call in PoolFactory.createPool) is a false positive on severity: no funds, permissionless, ghost pool at worst. Logged as I-1.
- PoolFactory.createPool builds the LP symbol from name() instead of symbol() -> L-1.
