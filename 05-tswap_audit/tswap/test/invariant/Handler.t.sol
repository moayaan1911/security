// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool public pool;

    ERC20Mock public poolToken;
    ERC20Mock public wethToken;

    // expected vs actual balance changes, the invariant compares these
    int256 public startingY;
    int256 public startingX;
    int256 public expectedDeltaY;
    int256 public expectedDeltaX;
    int256 public actualDeltaY;
    int256 public actualDeltaX;

    // two actors so deposits and swaps come from different addresses
    address liquidityProvider = makeAddr("liquidityProvider");
    address swapper = makeAddr("swapper");

    // grab the pool and the two tokens it trades
    constructor(TSwapPool _pool) {
        pool = _pool;
        poolToken = ERC20Mock(pool.getPoolToken());
        wethToken = ERC20Mock(pool.getWeth());
    }

    // swap handler: swapper takes an exact amount of WETH out, paying pool tokens in
    function swapPoolTokenForWethBasedOnOutputWeth(uint256 _outputWeth) public {
        // keep the fuzzed output in a range the pool can handle
        _outputWeth = bound(_outputWeth, 0, type(uint64).max);

        // skip the run if the pool cannot cover this output
        if (_outputWeth > wethToken.balanceOf(address(pool))) {
            return;
        }

        // ask the pool what this output costs in pool tokens
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            _outputWeth,
            poolToken.balanceOf(address(pool)),
            wethToken.balanceOf(address(pool))
        );

        // skip if the price does not fit, the pool works with uint64
        if (poolTokenAmount > type(uint64).max) {
            return;
        }

        // what the handler expects to pay in and get out
        expectedDeltaY = int256(-1) * int256(_outputWeth);
        expectedDeltaX = int256(
            pool.getPoolTokensToDepositBasedOnWeth(poolTokenAmount)
        );

        startingY = int256(wethToken.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));

        // make sure the swapper can afford it
        if (poolToken.balanceOf(swapper) < poolTokenAmount) {
            poolToken.mint(
                swapper,
                poolTokenAmount - poolToken.balanceOf(swapper) + 1
            );
        }

        // swap as the swapper
        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(
            poolToken,
            wethToken,
            _outputWeth,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // what actually changed
        uint256 endingY = wethToken.balanceOf(address(this));
        uint256 endingX = poolToken.balanceOf(address(this));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }

    // will deposit a "reasonable" amount of WETH into the pool so that no overflow occurs
    function deposit(uint256 _wethAmount) public {
        _wethAmount = bound(_wethAmount, 0, type(uint64).max);
        expectedDeltaY = int256(_wethAmount);
        expectedDeltaX = int256(
            pool.getPoolTokensToDepositBasedOnWeth(_wethAmount)
        );

        startingY = int256(wethToken.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));

        // deposit as the liquidity provider
        vm.startPrank(liquidityProvider);
        wethToken.mint(liquidityProvider, uint256(expectedDeltaY));
        poolToken.mint(liquidityProvider, uint256(expectedDeltaX));
        wethToken.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(
            uint256(expectedDeltaY),
            0,
            uint256(expectedDeltaX),
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // what actually changed
        uint256 endingY = wethToken.balanceOf(address(this));
        uint256 endingX = poolToken.balanceOf(address(this));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }
}
