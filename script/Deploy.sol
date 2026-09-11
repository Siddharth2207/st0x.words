// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.16.2/src/Script.sol";
import {ERC4626Words} from "../src/concrete/ERC4626Words.sol";
import {IMetaBoardV1_2} from "rain-metadata-0.1.0/src/interface/unstable/IMetaBoardV1_2.sol";
import {LibDescribedByMeta} from "rain-metadata-0.1.0/src/lib/LibDescribedByMeta.sol";
import {LibRainDeploy} from "rain-deploy-0.1.8/src/lib/LibRainDeploy.sol";
import {DEPLOYED_ADDRESS, BYTECODE_HASH} from "../src/generated/ERC4626Words.pointers.sol";

/// @dev Deterministic MetaBoard address deployed via Zoltu factory, identical
/// on every supported network.
/// https://github.com/rainlanguage/rain.metadata
address constant METABOARD_ADDRESS = 0x8fD50fF9Db9835ba1B61394752A26F53D721D2a1;

/// @title Deploy
/// Deploys `ERC4626Words` deterministically via the Zoltu factory to every
/// rain supported network and emits its described-by meta to the
/// MetaBoard in the same broadcast. There are no deploy-time choices: one
/// dispatch covers all networks, the target address and code hash are the
/// generated pointer constants of the source in this checkout, and an
/// already-deployed network is skipped idempotently (the meta was emitted when
/// it deployed).
///
/// This script is a manual dispatch only. Nothing in the repository asserts
/// that any network has been deployed, so no merge waits on a deploy.
contract Deploy is Script {
    /// The networks this contract deploys to: every rain supported network.
    /// Deployment is deterministic so the address is identical everywhere.
    function networks() internal pure returns (string[] memory nets) {
        nets = LibRainDeploy.supportedNetworks();
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");
        address deployer = vm.rememberKey(deployerPrivateKey);
        bytes memory subParserDescribedByMeta = vm.readFileBinary("meta/ERC4626Words.rain.meta");

        string[] memory nets = networks();
        for (uint256 i = 0; i < nets.length; i++) {
            // createSelectFork returns a fork id that is not needed here; bind
            // and reference it so the unused-return lint stays satisfied.
            uint256 forkId = vm.createSelectFork(nets[i]);
            (forkId);

            if (DEPLOYED_ADDRESS.code.length == 0) {
                if (LibRainDeploy.ZOLTU_FACTORY.code.length == 0) {
                    revert LibRainDeploy.MissingDependency(nets[i], LibRainDeploy.ZOLTU_FACTORY);
                }
                if (LibRainDeploy.ZOLTU_FACTORY.codehash != LibRainDeploy.ZOLTU_FACTORY_CODEHASH) {
                    revert LibRainDeploy.DependencyChanged(
                        nets[i],
                        LibRainDeploy.ZOLTU_FACTORY,
                        LibRainDeploy.ZOLTU_FACTORY_CODEHASH,
                        LibRainDeploy.ZOLTU_FACTORY.codehash
                    );
                }
                if (METABOARD_ADDRESS.code.length == 0) {
                    revert LibRainDeploy.MissingDependency(nets[i], METABOARD_ADDRESS);
                }

                vm.startBroadcast(deployer);
                address deployed = LibRainDeploy.deployZoltu(type(ERC4626Words).creationCode);
                if (deployed != DEPLOYED_ADDRESS) {
                    revert LibRainDeploy.UnexpectedDeployedAddress(DEPLOYED_ADDRESS, deployed);
                }
                LibDescribedByMeta.emitForDescribedAddress(
                    IMetaBoardV1_2(METABOARD_ADDRESS), ERC4626Words(deployed), subParserDescribedByMeta
                );
                vm.stopBroadcast();
            }

            if (DEPLOYED_ADDRESS.codehash != BYTECODE_HASH) {
                revert LibRainDeploy.UnexpectedDeployedCodeHash(BYTECODE_HASH, DEPLOYED_ADDRESS.codehash);
            }
        }
    }
}
