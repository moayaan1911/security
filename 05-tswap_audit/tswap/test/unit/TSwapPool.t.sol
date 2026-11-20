// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 10e18);
        poolToken.mint(user, 10e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + poolToken.balanceOf(liquidityProvider) > 400e18);
    }

    // the HIGH: getInputAmountBasedOnOutput multiplies by 10000 instead of 1000,
    // so an exact output swap charges the caller roughly 10x the fair input
    function test_SwapExactOutputOvercharges_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 wethReserves = weth.balanceOf(address(pool));
        uint256 poolTokenReserves = poolToken.balanceOf(address(pool));
        uint256 outputWeth = 0.5e18;

        // the same formula with the fee applied once, which is what the caller should pay
        uint256 fairInput = (poolTokenReserves * outputWeth * 1000) /
            ((wethReserves - outputWeth) * 997);

        // what the pool actually asks for
        uint256 quotedInput = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolTokenReserves,
            wethReserves
        );

        console.log("charged input:", quotedInput);
        console.log("fair input:", fairInput);

        assertGt(quotedInput, fairInput * 9);

        // and it is what the caller really pays
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        uint256 balanceBefore = poolToken.balanceOf(user);
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        uint256 paid = balanceBefore - poolToken.balanceOf(user);
        vm.stopPrank();

        console.log("actually paid:", paid);
        assertEq(paid, quotedInput);
        assertGt(paid, fairInput * 9);
    }

    // the M-1: swapExactOutput has no max input parameter, so a caller can be charged a much
    // worse price and has nothing to protect them (swapExactInput has minOutputAmount)
    function test_SwapExactOutputNoMaxInput_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 outputWeth = 1e18;

        // what the caller would pay at the current price
        uint256 inputBefore = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );

        // someone swaps first and makes WETH scarcer, moving the price against the caller
        poolToken.mint(user, 100e18);
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactInput(poolToken, 50e18, weth, 0, uint64(block.timestamp));
        vm.stopPrank();

        uint256 inputAfter = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );

        console.log("input before the price move:", inputBefore);
        console.log("input after the price move:", inputAfter);
        assertGt(inputAfter, inputBefore);

        // the swap still goes through at the worse price, there is no max input to set
        poolToken.mint(user, inputAfter);
        vm.startPrank(user);
        uint256 balanceBefore = poolToken.balanceOf(user);
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        uint256 paid = balanceBefore - poolToken.balanceOf(user);
        vm.stopPrank();

        console.log("paid at the worse price:", paid);
        assertEq(paid, inputAfter);
    }

    // the M-2: sellPoolTokens passes the amount to sell as the exact WETH output, so the
    // caller pays a completely different amount of pool tokens than they asked to sell
    function test_SellPoolTokensWrongAmount_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        uint256 amountToSell = 5e18;

        // an honest seller holding more than 5 pool tokens cannot sell them either
        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        vm.expectRevert();
        pool.sellPoolTokens(amountToSell);
        vm.stopPrank();

        // with a lot more tokens funded, the real behaviour shows up
        poolToken.mint(user, 200e18);
        vm.startPrank(user);
        uint256 poolTokensBefore = poolToken.balanceOf(user);
        uint256 wethBefore = weth.balanceOf(user);
        pool.sellPoolTokens(amountToSell);
        uint256 poolTokensSpent = poolTokensBefore - poolToken.balanceOf(user);
        uint256 wethReceived = weth.balanceOf(user) - wethBefore;
        vm.stopPrank();

        console.log("asked to sell:", amountToSell);
        console.log("pool tokens actually spent:", poolTokensSpent);
        console.log("weth actually received:", wethReceived);

        // the caller receives exactly the number they passed in, and pays a different amount
        assertEq(wethReceived, amountToSell);
        assertGt(poolTokensSpent, amountToSell);
    }

    // the H-2: every 10th swap pays the caller 1e18 of the output token for free, which drops
    // the pool's x * y = k instead of holding it
    function test_SwapIncentiveBreaksInvariant_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);

        // nine normal swaps, the tenth is the one that pays the bonus
        for (uint256 i = 0; i < 9; i++) {
            pool.swapExactInput(
                poolToken,
                0.1e18,
                weth,
                0,
                uint64(block.timestamp)
            );
        }

        uint256 wethReserves = weth.balanceOf(address(pool));
        uint256 poolTokenReserves = poolToken.balanceOf(address(pool));
        uint256 kBefore = wethReserves * poolTokenReserves;

        // what the pool itself says this swap should pay out
        uint256 expectedOut = pool.getOutputAmountBasedOnInput(
            0.1e18,
            poolTokenReserves,
            wethReserves
        );

        uint256 wethBefore = weth.balanceOf(user);
        pool.swapExactInput(poolToken, 0.1e18, weth, 0, uint64(block.timestamp));
        uint256 received = weth.balanceOf(user) - wethBefore;
        vm.stopPrank();

        uint256 kAfter = weth.balanceOf(address(pool)) *
            poolToken.balanceOf(address(pool));

        console.log("expected out:", expectedOut);
        console.log("actually received:", received);
        console.log("k before:", kBefore);
        console.log("k after:", kAfter);

        // the caller got 1e18 free on top of the swap
        assertEq(received, expectedOut + 1e18);

        // and the pool's product dropped instead of holding
        assertLt(kAfter, kBefore);
    }

    // the L-1: deposit takes a deadline but never checks it, so an expired deadline is accepted
    function test_DepositIgnoresDeadline_AUDIT() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);

        // a deadline that has already passed
        uint64 expiredDeadline = uint64(block.timestamp - 1);

        // deposit does not look at the deadline, so it goes through
        pool.deposit(100e18, 100e18, 100e18, expiredDeadline);
        console.log(
            "lp tokens minted with an expired deadline:",
            pool.balanceOf(liquidityProvider)
        );
        assertEq(pool.balanceOf(liquidityProvider), 100e18);

        // the same expired deadline is rejected by withdraw
        vm.expectRevert(
            abi.encodeWithSelector(
                TSwapPool.TSwapPool__DeadlineHasPassed.selector,
                expiredDeadline
            )
        );
        pool.withdraw(100e18, 100e18, 100e18, expiredDeadline);
        vm.stopPrank();
    }
}
