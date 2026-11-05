// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.32;

import {Test, console} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    function test_Supply() public {
        MyToken t = new MyToken();
        console.log("decimals  ", uint256(t.decimals()));
        console.log("totalSupply", t.totalSupply());
        console.log("1000e18   ", uint256(1000 * 10 ** 18));
        assertEq(t.totalSupply(), 1000 * 10 ** 18, "supply mismatch");
    }
}
