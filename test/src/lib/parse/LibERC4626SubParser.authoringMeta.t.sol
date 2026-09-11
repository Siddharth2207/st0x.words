// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {AuthoringMetaV2} from "rain-interpreter-interface-0.1.0/src/interface/deprecated/v1/IParserV1.sol";
import {LibERC4626SubParser, SUB_PARSER_WORD_PARSERS_LENGTH} from "../../../../src/lib/parse/LibERC4626SubParser.sol";
import {
    SUB_PARSER_WORD_ERC4626_CONVERT_TO_ASSETS,
    SUB_PARSER_WORD_ERC4626_CONVERT_TO_SHARES
} from "../../../../src/lib/parse/LibERC4626SubParser.sol";
import {DESCRIBED_BY_META_HASH} from "../../../../src/generated/ERC4626Words.pointers.sol";

/// @notice Tests that authoringMetaV2() is well-formed and consistent with committed artifacts.
contract LibERC4626SubParserAuthoringMetaTest is Test {
    function testAuthoringMetaV2DecodesSuccessfully() external pure {
        bytes memory encoded = LibERC4626SubParser.authoringMetaV2();
        AuthoringMetaV2[] memory meta = abi.decode(encoded, (AuthoringMetaV2[]));
        assertEq(meta.length, SUB_PARSER_WORD_PARSERS_LENGTH, "must have one entry per word");
    }

    function testAuthoringMetaV2WordNames() external pure {
        AuthoringMetaV2[] memory meta = abi.decode(LibERC4626SubParser.authoringMetaV2(), (AuthoringMetaV2[]));
        assertEq(
            meta[SUB_PARSER_WORD_ERC4626_CONVERT_TO_ASSETS].word,
            bytes32("erc4626-convert-to-assets"),
            "index 0 must be erc4626-convert-to-assets"
        );
        assertEq(
            meta[SUB_PARSER_WORD_ERC4626_CONVERT_TO_SHARES].word,
            bytes32("erc4626-convert-to-shares"),
            "index 1 must be erc4626-convert-to-shares"
        );
    }

    function testAuthoringMetaV2WordIndexOrdering() external pure {
        AuthoringMetaV2[] memory meta = abi.decode(LibERC4626SubParser.authoringMetaV2(), (AuthoringMetaV2[]));
        assertTrue(
            meta[0].word != meta[1].word, "word names must be distinct (a swapped index would produce identical words)"
        );
        assertTrue(
            meta[SUB_PARSER_WORD_ERC4626_CONVERT_TO_ASSETS].word
                != meta[SUB_PARSER_WORD_ERC4626_CONVERT_TO_SHARES].word,
            "convert-to-assets and convert-to-shares must be at different indexes"
        );
    }

    function testAuthoringMetaV2DescriptionsNonEmpty() external pure {
        AuthoringMetaV2[] memory meta = abi.decode(LibERC4626SubParser.authoringMetaV2(), (AuthoringMetaV2[]));
        assertTrue(bytes(meta[0].description).length > 0, "convert-to-assets description must not be empty");
        assertTrue(bytes(meta[1].description).length > 0, "convert-to-shares description must not be empty");
    }

    function testDescribedByMetaHashMatchesMetaFile() external view {
        bytes memory metaContent = vm.readFileBinary("meta/ERC4626Words.rain.meta");
        assertEq(
            keccak256(metaContent),
            DESCRIBED_BY_META_HASH,
            "DESCRIBED_BY_META_HASH must equal keccak256 of committed meta file"
        );
    }
}
