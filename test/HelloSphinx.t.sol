// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { HelloSphinxScript } from "../script/HelloSphinx.s.sol";

contract HelloSphinxTest is Test, HelloSphinxScript {
    function setUp() public override {
        HelloSphinxScript.setUp();
        run();
    }

    function testDidDeploy() public {
        assertEq(helloSphinx.greeting(), "Hi");
        assertEq(helloSphinx.number(), 10);
    }

    function testAdd() public {
        helloSphinx.add(1);
        assertEq(helloSphinx.number(), 11);
    }
}
