// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
contract Invariant is StdInvariant, Test {
    ERC20Mock public poolToken;
    ERC20Mock public wethToken;

    // PoolFactory and TSwapPool instances
    PoolFactory public poolFactory;
    TSwapPool public pool;

    // Declaration of constants for starting balances
    uint256 constant STARTING_X = 100e18;
    uint256 constant STARTING_Y = 50e18;

    function setUp() public {
        wethToken = new ERC20Mock();
        poolToken = new ERC20Mock();

        // Deploy the PoolFactory
        poolFactory = new PoolFactory(address(wethToken));

        pool = TSwapPool(poolFactory.createPool(address(poolToken)));

        poolToken.mint(address(this), STARTING_X);
        wethToken.mint(address(this), STARTING_Y);

        poolToken.approve(address(pool), type(uint256).max);
        wethToken.approve(address(pool), type(uint256).max);

        pool.deposit(
            uint256(STARTING_Y),
            uint256(STARTING_Y),
            uint256(STARTING_X),
            uint64(block.timestamp)
        );
    }

    function invariant_constantProductFormulaStaysSame_AUDIT() public {}
}
