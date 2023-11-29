//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IResin.sol";

contract Consume {
    IResin r;

    constructor(address resin) {
        r = IResin(resin);
    }

    function mint() external {
        r.consumeFrom(msg.sender, 40);
    }
}
