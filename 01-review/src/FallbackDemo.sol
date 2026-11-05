// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @notice Learning contract: which function runs for which kind of call?
/// Records which one fired so tests can assert on it.
contract Target {
    string public lastCalled;
    uint256 public valueReceived;

    /// Runs ONLY when calldata is completely empty.
    receive() external payable {
        lastCalled = "receive";
        valueReceived = msg.value;
    }

    /// Runs when NO function matches the calldata (or when receive() is absent).
    fallback() external payable {
        lastCalled = "fallback";
        valueReceived = msg.value;
    }

    /// A real function, payable -> can accept ETH.
    function known() external payable {
        lastCalled = "known";
        valueReceived = msg.value;
    }

    /// A real function, NOT payable -> reverts if ETH is attached.
    function knownNotPayable() external {
        lastCalled = "knownNotPayable";
    }
}

/// @notice Has fallback() but NO receive().
contract FallbackOnly {
    string public lastCalled;

    fallback() external payable {
        lastCalled = "fallback";
    }
}

/// @notice Has neither -> cannot receive ETH at all.
contract Bare {}
