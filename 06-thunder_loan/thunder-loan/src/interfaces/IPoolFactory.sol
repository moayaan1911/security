// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// @AUDIT-q:: why using TSwap? Why not using a more proven and mature protocol like uniswap or prisma or aave?
interface IPoolFactory {
    // @AUDIT-info:: no natspec comments!
    function getPool(address tokenAddress) external view returns (address);
}
