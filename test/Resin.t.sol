pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Resin.sol";

contract ResinTest is Test {
    Resin r;

    function setUp() public {
        vm.warp(1);
        r = new Resin();
    }

    function testBalanceOf() public {
        (uint16 b, uint16 rb) = r.balanceOf(Address("Alice"));
        assertEq(b, 220);
        assertEq(rb, 0);

        (b, rb) = r.balanceOf(Address("Bob"));
        assertEq(b, 220);
        assertEq(rb, 0);
    }

    function testConsume() public {
        (uint16 b, uint16 rb) = r.balanceOf(Address("Alice"));

        assertEq(b, 220);
        assertEq(rb, 0);

        r.consumeFrom(Address("Alice"), 220);

        (b, rb) = r.balanceOf(Address("Alice"));

        assertEq(b, 0);
        assertEq(rb, 0);
    }

    function testRecovery() public {
        r.consumeFrom(Address("Alice"), 220);

        (uint16 b, uint16 rb) = r.balanceOf(Address("Alice"));
        assertEq(b, 0);
        assertEq(rb, 0);

        vm.warp(1 + (220 * 8 minutes));
        (b, rb) = r.balanceOf(Address("Alice"));
        assertEq(b, 220);
        assertEq(rb, 0);

        vm.warp((1 + (220 * 8 minutes)) + (1400 * 15 minutes));
        (b, rb) = r.balanceOf(Address("Alice"));
        assertEq(b, 220);
        assertEq(rb, 1400);

        vm.warp((1 + (220 * 8 minutes)) + (1399 * 15 minutes));
        (b, rb) = r.balanceOf(Address("Alice"));
        assertEq(b, 220);
        assertEq(rb, 1399);

        vm.warp((1 + (220 * 8 minutes)) + (9999 * 15 minutes));
        (b, rb) = r.balanceOf(Address("Alice"));
        assertEq(b, 220);
        assertEq(rb, 1400);
    }

    function testRecharge() public {
        r.consumeFrom(Address("Alice"), 220);
        vm.warp((1 + (220 * 8 minutes)) + (1399 * 15 minutes));
        (uint16 b, uint16 rb) = r.balanceOf(Address("Alice"));
        assertEq(b, 220);
        assertEq(rb, 1399);

        r.consumeFrom(Address("Alice"), 110);
        vm.prank(Address("Alice"));
        r.recharge();

        (b, rb) = r.balanceOf(Address("Alice"));
        assertEq(b, 220);
        assertEq(rb, 1289);
    }

    // for Debug
    function Address(string memory name) internal returns (address ret) {
        ret = address(uint160(uint256(keccak256(abi.encode(name)))));
        vm.label(ret, name);
    }
}
