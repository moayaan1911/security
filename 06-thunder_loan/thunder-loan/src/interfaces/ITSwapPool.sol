// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// @AUDIT-q:: why are we only using the price of one pool token in wEth? why not other tokens?
interface ITSwapPool {
    // @AUDIT-info:: no natspec comments!
    function getPriceOfOnePoolTokenInWeth() external view returns (uint256);
}
