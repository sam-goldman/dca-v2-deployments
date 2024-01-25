// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { HelloSphinx } from "../src/HelloSphinx.sol";
import "@sphinx-labs/contracts/SphinxPlugin.sol";

contract HelloSphinxScript is Sphinx {
    HelloSphinx helloSphinx;

    function setUp() public virtual {
        sphinxConfig.owners = [0x4856e043a1F2CAA8aCEfd076328b4981Aca91000];
        sphinxConfig.orgId = "clksrkg1v0001l00815670lu8";
        sphinxConfig.threshold = 1;
        sphinxConfig.projectName = "My_First_Project";
        sphinxConfig.testnets = [
            Network.sepolia,
            Network.optimism_sepolia,
            Network.arbitrum_sepolia
        ];
    }

    function run() public sphinx {
        // Set the `CREATE2` salt to be the hash of the owner(s). Prevents
        // address collisions.
        bytes32 salt = keccak256(abi.encode(sphinxConfig.owners));
        helloSphinx = new HelloSphinx{ salt: salt }("Hi", 2);
        helloSphinx.add(8);
    }
}
