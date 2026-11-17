// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool public pool;

    ERC20Mock public poolToken;
    ERC20Mock public wethToken;

    uint256 startingY;
    uint256 startingX;
    uint256 expectedDeltaY;
    uint256 expectedDeltaX;

    address liquidityProvider = makeAddr("liquidityProvider");

    constructor(TSwapPool _pool) {
        pool = _pool;
        poolToken = ERC20Mock(pool.getPoolToken());
        wethToken = ERC20Mock(pool.getWeth());
    }

    // will deposit a "reasonable" amount of WETH into the pool so that no overflow occurs
    function deposit(uint256 _wethAmount) public {
        _wethAmount = bound(_wethAmount, 0, type(uint64).max);
        expectedDeltaY = _wethAmount;
        expectedDeltaX = pool.getPoolTokensToDepositBasedOnWeth(_wethAmount);

        startingY = wethToken.balanceOf(address(this));
        startingX = poolToken.balanceOf(address(this));

        vm.startPrank(liquidityProvider);
        wethToken.mint(liquidityProvider, expectedDeltaY);
        poolToken.mint(liquidityProvider, expectedDeltaX);
        wethToken.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(
            expectedDeltaY,
            0,
            expectedDeltaX,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // assert that the balances have changed as expected
    }
}
