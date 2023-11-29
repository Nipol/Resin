//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IResin {
    function consumeFrom(address user, uint16 amount) external;
    function recharge() external;
}
