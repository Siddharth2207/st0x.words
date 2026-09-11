// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {PARSE_META_BUILD_DEPTH as SOURCE_DEPTH} from "../../../src/abstract/ERC4626SubParser.sol";
import {PARSE_META_BUILD_DEPTH as GENERATED_DEPTH} from "../../../src/generated/ERC4626Words.pointers.sol";

contract ERC4626WordsParseMetaDepthTest is Test {
    function testParseMetaBuildDepthConstantsAgree() external pure {
        assertEq(
            uint256(SOURCE_DEPTH),
            uint256(GENERATED_DEPTH),
            "PARSE_META_BUILD_DEPTH in ERC4626SubParser.sol and ERC4626Words.pointers.sol must agree"
        );
    }
}
