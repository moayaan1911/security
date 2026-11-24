// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {ITSwapPool} from "../interfaces/ITSwapPool.sol";
import {IPoolFactory} from "../interfaces/IPoolFactory.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract OracleUpgradeable is Initializable {
    address private s_poolFactory;

    // @AUDIT-info:: should do zero address check
    // @AUDIT-info:: no natspec comments!
    function __Oracle_init(
        address poolFactoryAddress
    ) internal onlyInitializing {
        __Oracle_init_unchained(poolFactoryAddress);
    }

    // @AUDIT-info:: no natspec comments!
    function __Oracle_init_unchained(
        address poolFactoryAddress
    ) internal onlyInitializing {
        s_poolFactory = poolFactoryAddress;
    }

    // @AUDIT-info:: no natspec comments!
    function getPriceInWeth(address token) public view returns (uint256) {
        address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
        return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
    }

    // @AUDIT-info:: no natspec comments!
    function getPrice(address token) external view returns (uint256) {
        return getPriceInWeth(token);
    }

    // @AUDIT-info:: no natspec comments!
    function getPoolFactoryAddress() external view returns (address) {
        return s_poolFactory;
    }
}
