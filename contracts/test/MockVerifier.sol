// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract MockVerifier {
    bool public always;

    constructor(bool _always) { always = _always; }

    function set(bool v) external { always = v; }

    function isEligible(uint256 /*activityId*/, address /*user*/) external view returns (bool) {
        return always;
    }
}


