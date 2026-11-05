// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Target, FallbackOnly, Bare} from "../src/FallbackDemo.sol";

contract FallbackDemoTest is Test {
    Target target;
    FallbackOnly fallbackOnly;
    Bare bare;

    function setUp() public {
        target = new Target();
        fallbackOnly = new FallbackOnly();
        bare = new Bare();
        vm.deal(address(this), 100 ether);
    }

    /// 1. Empty calldata + ETH  ->  receive()
    function test_EmptyCalldata_GoesToReceive() public {
        (bool ok,) = address(target).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(target.lastCalled(), "receive");
        assertEq(address(target).balance, 1 ether);
    }

    /// 2. Calldata with an UNKNOWN selector + ETH  ->  fallback()
    function test_UnknownSelector_GoesToFallback() public {
        (bool ok,) = address(target).call{value: 1 ether}(
            abi.encodeWithSignature("doesNotExist()")
        );
        assertTrue(ok);
        assertEq(target.lastCalled(), "fallback");
        assertEq(address(target).balance, 1 ether);
    }

    /// 3. Calldata with a KNOWN selector + ETH  ->  the real function, NOT fallback()
    ///    ^^^ this is the case you asked about
    function test_KnownSelector_GoesToRealFunction() public {
        (bool ok,) = address(target).call{value: 1 ether}(
            abi.encodeWithSignature("known()")
        );
        assertTrue(ok);
        assertEq(target.lastCalled(), "known"); // NOT "fallback"
        assertEq(address(target).balance, 1 ether);
    }

    /// 4. KNOWN selector but the function is NOT payable + ETH  ->  revert
    function test_KnownSelector_NotPayable_Reverts() public {
        (bool ok,) = address(target).call{value: 1 ether}(
            abi.encodeWithSignature("knownNotPayable()")
        );
        assertFalse(ok, "sending ETH to a non-payable function must revert");
    }

    /// 5. No receive(), empty calldata  ->  fallback() is the backup
    function test_NoReceive_EmptyCalldata_FallsBackToFallback() public {
        (bool ok,) = address(fallbackOnly).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(fallbackOnly.lastCalled(), "fallback");
        assertEq(address(fallbackOnly).balance, 1 ether);
    }

    /// 6. Neither receive() nor fallback()  ->  ETH transfer fails
    function test_NeitherExists_Reverts() public {
        (bool ok,) = address(bare).call{value: 1 ether}("");
        assertFalse(ok, "contract with no receive/fallback cannot accept ETH");
    }
}
