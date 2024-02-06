// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { Sphinx, Network } from "@sphinx-labs/contracts/SphinxPlugin.sol";
import { IPermit2, UniversalPermit2Adapter } from '@mean-finance/permit2-adapter/UniversalPermit2Adapter.sol';

bytes32 constant SIMULATOR_SALT = bytes32(
  uint256(56_695_679_612_138_000_431_577_699_311_877_947_994_212_843_972_045_166_829_844_248_425_940_608_660_468)
);

IPermit2 constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

contract DCA_v2 is Sphinx, Script {

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev Address of the Gnosis Safe that executes the deployment.
    address internal msig;

    /// @dev An array that contains a single element: the address of the Gnosis Safe that executes
    /// the deployment. It's convenient to store this as a state variable because it's used 
    /// throughout this script as a constructor argument for deployed contracts.
    address[] internal msigArray;

    /// @dev Address of the `DeterministicFactory` contract.
    address internal deterministicFactory;

    function setUp() public virtual {
        // Sphinx config options
        sphinxConfig.owners = [0xEF7CBca28a2F0f028dd82fF62f92C3b4065Ec200];
        sphinxConfig.orgId = "cloepk9wp0001l809rbsegymp";
        sphinxConfig.mainnets = [ Network.optimism ];
        sphinxConfig.testnets = [ Network.optimism_sepolia];
        sphinxConfig.threshold = 1;
        sphinxConfig.projectName = "DCA_v2";

        msig = safeAddress();
        msigArray.push(msig);
    }

    /// @dev Deploys the DCA v2 contracts. This script is idempotent, which means it reaches the
    /// same end state on each chain regardless of how many times it's executed. Particularly, it
    /// won't attempt to deploy a contract if code already exists at the `CREATE2` or `CREATE3`
    /// address.
    ///
    /// You'll notice that this script uses `vm.getCode` to load the creation code for most contracts
    /// instead of importing the source files. This is necessary because most of the Mean Finance
    /// repositories use different compiler settings and different versions of OpenZeppelin
    /// contracts. Since Forge Scripts can only use a single set of compiler settings and a single
    /// version of OpenZeppelin's contracts at one time, this script won't compile if we use standard
    /// imports for the contracts. Instead, we compile the repositories separately using
    /// their original compiler settings then load in the creation code using `vm.getCode`. This
    /// preserves the original compiler settings. Using `vm.getCode` doesn't worsen the type safety
    /// of the deployments very much because the majority of the deployments use `CREATE3`, which
    /// requires us to encode the creation code and constructor args using `abi.encodePacked`
    /// regardless of how we load the creation code. In other words, the type safety of `CREATE3`
    /// deployments isn't strong regardless.
    function run() public sphinx {
        
        // Deterministic Factory
        bytes memory deterministicFactoryCreationCode = abi.encodePacked(vm.getCode("DeterministicFactory.sol"), abi.encode(msig, msig));
        deterministicFactory = vm.computeCreate2Address(ZERO_SALT, keccak256(deterministicFactoryCreationCode));
        if (deterministicFactory.code.length == 0) {
            (bool success, ) = CREATE2_FACTORY.call(abi.encodePacked(ZERO_SALT, deterministicFactoryCreationCode));
            require(success, "DeterministicFactory deployment failed.");
            require(deterministicFactory.code.length > 0, "DeterministicFactory address mismatch.");
        }


        //Permit2 Adapter
       address permit2AdapterAddress=  deployCreate3({
            _name: "UniversalPermit2Adapter",
            _salt: 'MF-UniversalPermit2Adapter-V1',
            _args: abi.encode(PERMIT2, msig, msigArray)
        });

        //Swap Proxy
        deployCreate3({
            _name: "SwapProxy",
            _salt: 'MF-SwapProxy-V1',
            _args: abi.encode(permit2AdapterAddress, msig, msigArray)
        });


    }

    /// @dev Deploys a contract via the `DeterministicFactory`. Skips the deployment if a contract is already
    /// deployed at the `CREATE3` address.
    function deployCreate3(string memory _name, string memory _salt, bytes memory _args) internal returns (address) {
        require(deterministicFactory.code.length > 0, "DeterministicFactory is not deployed.");

        address create3Address = getCreate3Address(_salt);
        if (create3Address.code.length > 0) return create3Address;

        string memory contractNameWithSuffix = string(abi.encodePacked(_name, ".sol"));
        bytes memory creationCode = vm.getCode(contractNameWithSuffix);
        bytes memory creationCodeWithArgs = abi.encodePacked(creationCode, _args);

        // We must use a low-level call instead of interacting with the `IDeterministicFactory`
        // because this interface has a strict Solidity compiler version of 0.8.7, which is
        // incompatible with the contracts that we import in this file.
        bytes memory deployData = abi.encodeWithSignature(
            "deploy(bytes32,bytes,uint256)",
            bytes32(bytes(_salt)),
            creationCodeWithArgs,
            0
        );
        (bool success, bytes memory retdata) = deterministicFactory.call(deployData);
        require(success, string(retdata));

        address deployedCreate3Address = abi.decode(retdata, (address));
        require(create3Address == deployedCreate3Address, "CREATE3 address mismatch.");

        return create3Address;
    }

    function getCreate3Address(string memory _salt) internal view returns (address) {
        require(deterministicFactory.code.length > 0, "DeterministicFactory is not deployed.");

        // We must use a low-level staticcall instead of interacting with the
        // `IDeterministicFactory` because this interface has a strict Solidity compiler version of
        // 0.8.7, which is incompatible with the contracts that we import in this file.
        bytes memory data = abi.encodeWithSignature("getDeployed(bytes32)", bytes32(bytes(_salt)));
        (bool success, bytes memory retdata) = deterministicFactory.staticcall(data);
        require(success, string(retdata));

        return abi.decode(retdata, (address));
    }

    

}
