// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std-1.16.2/src/Script.sol";
import {LibERC4626SubParser} from "src/lib/parse/LibERC4626SubParser.sol";

/// @title ERC4626 SubParser Authoring Meta
/// @notice Writes the raw authoring meta to file so it can be wrapped in CBOR
/// by the rain CLI and emitted on metaboard.
/// Run via the erc4626-words-prelude nix task which also handles the CBOR wrapping.
contract BuildAuthoringMeta is Script {
    function run() external {
        vm.writeFileBinary("meta/ERC4626SubParserAuthoringMeta.rain.meta", LibERC4626SubParser.authoringMetaV2());
    }
}
