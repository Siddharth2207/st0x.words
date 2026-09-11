// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {AuthoringMetaV2} from "rain-interpreter-interface-0.1.0/src/interface/deprecated/v1/IParserV1.sol";
import {
    LibERC4626SubParser,
    SUB_PARSER_WORD_ERC4626_CONVERT_TO_ASSETS,
    SUB_PARSER_WORD_ERC4626_CONVERT_TO_SHARES,
    SUB_PARSER_WORD_PARSERS_LENGTH
} from "../../../../src/lib/parse/LibERC4626SubParser.sol";

contract LibERC4626SubParserTest is Test {
    function testAuthoringMetaV2Length() external pure {
        AuthoringMetaV2[] memory meta = abi.decode(LibERC4626SubParser.authoringMetaV2(), (AuthoringMetaV2[]));
        assertEq(meta.length, SUB_PARSER_WORD_PARSERS_LENGTH, "meta must have one entry per word");
        assertEq(meta.length, 2, "meta must have exactly 2 entries");
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

    function testAuthoringMetaV2WordOrderMatchesOpcodeConstants() external pure {
        assertEq(SUB_PARSER_WORD_ERC4626_CONVERT_TO_ASSETS, 0, "convert-to-assets must be opcode 0");
        assertEq(SUB_PARSER_WORD_ERC4626_CONVERT_TO_SHARES, 1, "convert-to-shares must be opcode 1");
        AuthoringMetaV2[] memory meta = abi.decode(LibERC4626SubParser.authoringMetaV2(), (AuthoringMetaV2[]));
        assertEq(
            meta[0].word,
            bytes32("erc4626-convert-to-assets"),
            "opcode 0 must map to convert-to-assets, not convert-to-shares"
        );
        assertEq(
            meta[1].word,
            bytes32("erc4626-convert-to-shares"),
            "opcode 1 must map to convert-to-shares, not convert-to-assets"
        );
    }
}
