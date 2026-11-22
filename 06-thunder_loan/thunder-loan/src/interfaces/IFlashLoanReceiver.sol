// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.20;

// @AUDIT-info:: unused import? comment it out
import {IThunderLoan} from "./IThunderLoan.sol";

/**
 * @dev Inspired by Aave:
 * https://github.com/aave/aave-v3-core/blob/master/contracts/flashloan/interfaces/IFlashLoanReceiver.sol
 */
interface IFlashLoanReceiver {
    // @AUDIT-info:: where is natspec comments? What is amount? what is token? is that the token being borrowed?
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}
