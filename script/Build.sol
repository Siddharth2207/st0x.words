// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.16.2/src/Script.sol";
import {ERC4626Words} from "src/concrete/ERC4626Words.sol";
import {LibFs} from "rain-sol-codegen-0.1.0/src/lib/LibFs.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.0/src/lib/LibCodeGen.sol";
import {LibGenParseMeta} from "rain-interpreter-interface-0.1.0/src/lib/codegen/LibGenParseMeta.sol";
import {LibERC4626SubParser} from "src/lib/parse/LibERC4626SubParser.sol";
import {PARSE_META_BUILD_DEPTH} from "src/abstract/ERC4626SubParser.sol";
import {LibRainDeploy} from "rain-deploy-0.1.8/src/lib/LibRainDeploy.sol";

contract Build is Script {
    /// @notice Generates the Solidity constant declaration for the
    /// deterministic Zoltu deploy address.
    function addressConstantString(address addr) internal pure returns (string memory) {
        return string.concat(
            "\n",
            "/// @dev The deterministic deploy address of the contract when deployed via\n",
            "/// the Zoltu factory.\n",
            "address constant DEPLOYED_ADDRESS = address(",
            vm.toString(addr),
            ");\n"
        );
    }

    function buildERC4626WordsPointers() internal {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(type(ERC4626Words).creationCode);
        ERC4626Words erc4626Words = ERC4626Words(deployed);

        string memory name = "ERC4626Words";

        string memory body = addressConstantString(deployed);
        body = string.concat(body, LibCodeGen.describedByMetaHashConstantString(vm, name));
        body = string.concat(
            body,
            LibGenParseMeta.parseMetaConstantString(vm, LibERC4626SubParser.authoringMetaV2(), PARSE_META_BUILD_DEPTH)
        );
        body = string.concat(body, LibCodeGen.subParserWordParsersConstantString(vm, erc4626Words));
        body = string.concat(body, LibCodeGen.operandHandlerFunctionPointersConstantString(vm, erc4626Words));
        body = string.concat(body, LibCodeGen.integrityFunctionPointersConstantString(vm, erc4626Words));
        body = string.concat(body, LibCodeGen.opcodeFunctionPointersConstantString(vm, erc4626Words));

        LibFs.buildFileForContract(vm, address(erc4626Words), name, body);
    }

    function run() external {
        buildERC4626WordsPointers();
    }
}
