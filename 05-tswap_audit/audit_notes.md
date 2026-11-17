# Protocol
TSwap - fork of Uniswap V1

# Findings
- too less coverage in tests verified via forge coverage
- no invariant test at all! Absolute red flag. Writing invariant test myself to find bugs
- no check for deadline in the deposit function, will return back at it later