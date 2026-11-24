// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// @AUDIT-info:: This should be implemented by thunderloan contract! you are implementing repay function in the contract which is DIFFERENT than this interface!
interface IThunderLoan {
    // @AUDIT-info:: no natspec comments!
    function repay(address token, uint256 amount) external;
}
