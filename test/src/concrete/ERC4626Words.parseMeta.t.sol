// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {AuthoringMetaV2} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {LibGenParseMeta} from "rain-interpreter-interface-0.1.0/src/lib/codegen/LibGenParseMeta.sol";
import {LibERC4626SubParser} from "../../../src/lib/parse/LibERC4626SubParser.sol";
import {PARSE_META_BUILD_DEPTH as PARSE_META_BUILD_DEPTH_SUBPARSER} from "../../../src/abstract/ERC4626SubParser.sol";
import {
    PARSE_META_BUILD_DEPTH as PARSE_META_BUILD_DEPTH_GENERATED,
    PARSE_META
} from "../../../src/generated/ERC4626Words.pointers.sol";

/// @notice Asserts the two separately-defined PARSE_META_BUILD_DEPTH constants agree.
/// Covers HIGH issue: PARSE_META_BUILD_DEPTH lives in two hand/generated sources
/// that must agree but nothing enforces it.
contract ERC4626WordsParseMetaTest is Test {
    function testParseMetaBuildDepthConstantsAgreeAcrossFiles() external pure {
        assertEq(
            uint256(PARSE_META_BUILD_DEPTH_SUBPARSER),
            uint256(PARSE_META_BUILD_DEPTH_GENERATED),
            "PARSE_META_BUILD_DEPTH in ERC4626SubParser must equal generated constant"
        );
    }

    function testParseMetaBytesLengthMatchesBuildDepth() external pure {
        // PARSE_META format: 2 header bytes + 32*buildDepth bloom bytes + 4*numWords item bytes
        // Header: depth byte + seed byte = 2 bytes
        // Bloom filters: 32 bytes each, one per build depth
        // Items: 4 bytes each, one per word (2 words)
        uint256 expectedMinLength = 2 + 32 * uint256(PARSE_META_BUILD_DEPTH_GENERATED) + 4 * 2;
        assertTrue(
            PARSE_META.length >= expectedMinLength, "PARSE_META must be at least as long as its declared structure"
        );
    }

    function testParseMetaFirstBytMatchesBuildDepth() external pure {
        assertEq(
            uint8(PARSE_META[0]), PARSE_META_BUILD_DEPTH_GENERATED, "first byte of PARSE_META must equal build depth"
        );
    }

    function testParseMetaMatchesDynamicBuild() external pure {
        bytes memory encodedMeta = LibERC4626SubParser.authoringMetaV2();
        AuthoringMetaV2[] memory authoringMeta = abi.decode(encodedMeta, (AuthoringMetaV2[]));
        bytes memory rebuilt = LibGenParseMeta.buildParseMetaV2(authoringMeta, PARSE_META_BUILD_DEPTH_GENERATED);
        assertEq(rebuilt, PARSE_META, "PARSE_META must match dynamically rebuilt parse meta from authoringMetaV2");
    }
}
