// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { Sphinx, Network } from "@sphinx-labs/contracts/SphinxPlugin.sol";
import { Simulator } from "@call-simulation/Simulator.sol";
import { IUniswapV3Adapter } from "@mean-finance/oracles/solidity/interfaces/adapters/IUniswapV3Adapter.sol";
import { IStaticOracle } from '@mean-finance/uniswap-v3-oracle/solidity/interfaces/IStaticOracle.sol';
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
        sphinxConfig.owners = [address(0)];
        sphinxConfig.orgId = "";
        sphinxConfig.mainnets = [Network.optimism];
        sphinxConfig.testnets = [Network.optimism_sepolia];
        sphinxConfig.threshold = 0;
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

        // Call Simulation
        address simulatorAddress = vm.computeCreate2Address(SIMULATOR_SALT, keccak256(type(Simulator).creationCode));
        if (simulatorAddress.code.length == 0) {
            Simulator simulator = new Simulator{salt: SIMULATOR_SALT}();
            require(simulatorAddress == address(simulator), "Simulator address mismatch.");
        }

        // Permit2 Adapter
        address permit2AdapterAddress = vm.computeCreate2Address(ZERO_SALT, keccak256(abi.encodePacked(type(UniversalPermit2Adapter).creationCode, abi.encode(PERMIT2))));
        if (permit2AdapterAddress.code.length == 0) {
            UniversalPermit2Adapter permit2Adapter = new UniversalPermit2Adapter{ salt: ZERO_SALT }(PERMIT2);
            require(permit2AdapterAddress == address(permit2Adapter), "UniversalPermit2Adapter address mismatch.");
        }

        // NFT Descriptors
        address tokenDescriptor = deployCreate3({
            _name: "DCAHubPositionDescriptor",
            _salt: 'MF-DCAHubPositionDescriptor-V1',
            _args: hex""
        });

        // Chainlink Registry
        address chainlinkFeedRegistry;
        // On Ethereum, we use the `ChainlinkRegistry` operated by Chainlink.
        if (block.chainid == 1) {
            chainlinkFeedRegistry = 0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf;
        } else {
            chainlinkFeedRegistry = deployCreate3({
                _name: "ChainlinkRegistry",
                _salt: 'MF-Chainlink-Feed-Registry-V1',
                _args: abi.encode(msig, msigArray)
            });
        }

        // Transformers
        deployCreate3({_name: "ERC4626Transformer", _salt: 'MF-ERC4626-Transformer-V1', _args: abi.encode(msig)});
        deployCreate3({_name: "ProtocolTokenWrapperTransformer", _salt: 'MF-Protocol-Transformer-V1', _args: abi.encode(msig)});
        address transformerRegistry = deployCreate3({_name: "TransformerRegistry", _salt: 'MF-Transformer-Registry-V1', _args: abi.encode(msig)});
        if (block.chainid == 1) {
            address stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
            deployCreate3({_name: "wstETHTransformer", _salt: 'MF-wstETH-Transformer-V1', _args: abi.encode(stETH, msig)});
        }

        // Oracles
        address transformerOracle = deployOracles({
            _transformerRegistry: transformerRegistry,
            _chainlinkFeedRegistry: chainlinkFeedRegistry
        });

        // DCA V2 Core
        address permissionsManager = deployCreate3({_name: 'DCAPermissionsManager', _salt: 'MF-DCAV2-PermissionsManager-V1', _args:  abi.encode(msig, tokenDescriptor)});
        address timelock = deployCreate3({_name: "TimelockController", _salt: 'MF-DCAV2-Timelock-V1', _args: abi.encode(3 days, msigArray, msigArray)});
        address dcaHub = deployCreate3({_name: "DCAHub", _salt: 'MF-DCAV2-DCAHub-V1', _args: abi.encode(msig, timelock, transformerOracle, permissionsManager)});

        // Swappers
        address swapperRegistry = deployCreate3({_name: "SwapperRegistry", _salt: 'MF-Swapper-Registry-V1', _args: abi.encode(new address[](0), new address[](0), msig, msigArray)});
        deployCreate3({_name: 'SwapProxy', _salt: 'MF-Swap-Proxy-V1', _args: abi.encode(swapperRegistry, msig)});

        // DCA V2 Periphery
        deployCreate3({_name: 'DCAHubCompanion', _salt: 'MF-DCAV2-DCAHubCompanion-V5', _args: abi.encode(permit2AdapterAddress, permit2AdapterAddress, msig, PERMIT2)});
        deployCreate3({_name: 'CallerOnlyDCAHubSwapper', _salt: 'MF-DCAV2-CallerDCAHubSwapper-V2', _args: hex""});
        deployCreate3({_name: 'ThirdPartyDCAHubSwapper', _salt: 'MF-DCAV2-3PartySwapper-V3', _args: hex""});
        deployCreate3({_name: 'DCAFeeManager', _salt: 'MF-DCAV2-DCAFeeManager-V3', _args: abi.encode(msig, msigArray)});
        if (block.chainid == 1) {
            address keep3r = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;
            deployCreate3({_name: 'DCAKeep3rJob', _salt: 'MF-DCAV2-Keep3rJob-V2', _args: abi.encode(keep3r, dcaHub, msig, new address[](0))});
        }
    }

    /// @dev Deploys the Oracle contracts. We use a separate function to prevent a "Stack too deep"
    /// Solidity compiler error, which would occur if we put these deployments in the main `run`
    /// function.
    function deployOracles(address _transformerRegistry, address _chainlinkFeedRegistry) internal returns (address transformerOracle) {
        address chainlinkOracle = deployCreate3({_name: "StatefulChainlinkOracle", _salt: 'MF-StatefulChainlink-Oracle-V2', _args: abi.encode(_chainlinkFeedRegistry, msig, msigArray)});
        address uniswapV3Oracle = 0xB210CE856631EeEB767eFa666EC7C1C57738d438;
        address uniswapV3Adapter;
        if (uniswapV3Oracle.code.length > 0) {
            IUniswapV3Adapter.InitialConfig memory uniswapV3AdapterArgs = IUniswapV3Adapter.InitialConfig({
                uniswapV3Oracle: IStaticOracle(uniswapV3Oracle),
                maxPeriod: 45 minutes,
                minPeriod: 5 minutes,
                initialPeriod: 10 minutes,
                superAdmin: msig,
                initialAdmins: msigArray
            });
            deployCreate3({_name: "UniswapV3Adapter", _salt: 'MF-Uniswap-V3-Adapter-V1', _args: abi.encode(uniswapV3AdapterArgs)});
        }
        address identityOracle = deployCreate3({_name: 'IdentityOracle', _salt: 'MF-Identity-Oracle-V1', _args: hex""});
        address[] memory oracles;
        if (address(uniswapV3Adapter) == address(0)) {
            oracles = new address[](2);
            oracles[0] = identityOracle;
            oracles[1] = chainlinkOracle;
        } else {
            oracles = new address[](3);
            oracles[0] = identityOracle;
            oracles[1] = chainlinkOracle;
            oracles[2] = uniswapV3Adapter;
        }
        address oracleAggregator = deployCreate3({_name: 'OracleAggregator', _salt: 'MF-Oracle-Aggregator-V1', _args: abi.encode(oracles, msig, msigArray)});
        transformerOracle = deployCreate3({_name: 'TransformerOracle', _salt: 'MF-Transformer-Oracle-V2', _args: abi.encode(_transformerRegistry, oracleAggregator, msig, msigArray)});
        deployCreate3({_name: 'API3ChainlinkAdapterFactory', _salt: 'MF-API3-Adapter-Factory-V2', _args: hex""});
        deployCreate3({_name: 'DIAChainlinkAdapterFactory', _salt: 'MF-DIA-Adapter-Factory-V2', _args: hex""});
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
