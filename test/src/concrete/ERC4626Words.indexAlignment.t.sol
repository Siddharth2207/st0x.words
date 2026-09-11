// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {
    OPCODE_ERC4626_CONVERT_TO_ASSETS,
    OPCODE_ERC4626_CONVERT_TO_SHARES,
    OPCODE_FUNCTION_POINTERS_LENGTH
} from "../../../src/abstract/ERC4626Extern.sol";
import {
    SUB_PARSER_WORD_ERC4626_CONVERT_TO_ASSETS,
    SUB_PARSER_WORD_ERC4626_CONVERT_TO_SHARES,
    SUB_PARSER_WORD_PARSERS_LENGTH
} from "../../../src/lib/parse/LibERC4626SubParser.sol";
import {
    OPCODE_FUNCTION_POINTERS,
    INTEGRITY_FUNCTION_POINTERS,
    SUB_PARSER_WORD_PARSERS,
    OPERAND_HANDLER_FUNCTION_POINTERS
} from "../../../src/generated/ERC4626Words.pointers.sol";

/// @notice Asserts the five parallel opcode/word index constants all agree.
/// Covers HIGH issue: word-name -> opcode-index binding is hand-replicated
/// across multiple files with no test cross-checking them.
contract ERC4626WordsIndexAlignmentTest is Test {
    function testConvertToAssetsOpcodeMatchesSubParserWordIndex() external pure {
        assertEq(
            OPCODE_ERC4626_CONVERT_TO_ASSETS,
            SUB_PARSER_WORD_ERC4626_CONVERT_TO_ASSETS,
            "convert-to-assets opcode index must equal sub-parser word index"
        );
    }

    function testConvertToSharesOpcodeMatchesSubParserWordIndex() external pure {
        assertEq(
            OPCODE_ERC4626_CONVERT_TO_SHARES,
            SUB_PARSER_WORD_ERC4626_CONVERT_TO_SHARES,
            "convert-to-shares opcode index must equal sub-parser word index"
        );
    }

    function testOpcodeLengthMatchesSubParserWordLength() external pure {
        assertEq(
            OPCODE_FUNCTION_POINTERS_LENGTH,
            SUB_PARSER_WORD_PARSERS_LENGTH,
            "OPCODE_FUNCTION_POINTERS_LENGTH must equal SUB_PARSER_WORD_PARSERS_LENGTH"
        );
    }

    function testConvertToAssetsAndSharesIndexesAreDistinct() external pure {
        assertTrue(
            OPCODE_ERC4626_CONVERT_TO_ASSETS != OPCODE_ERC4626_CONVERT_TO_SHARES,
            "convert-to-assets and convert-to-shares must have different opcode indexes"
        );
    }

    function testOpcodeFunctionPointersByteLengthMatchesCount() external pure {
        assertEq(
            OPCODE_FUNCTION_POINTERS.length,
            OPCODE_FUNCTION_POINTERS_LENGTH * 2,
            "OPCODE_FUNCTION_POINTERS must be exactly 2 bytes per opcode"
        );
    }

    function testIntegrityFunctionPointersByteLengthMatchesCount() external pure {
        assertEq(
            INTEGRITY_FUNCTION_POINTERS.length,
            OPCODE_FUNCTION_POINTERS_LENGTH * 2,
            "INTEGRITY_FUNCTION_POINTERS must be exactly 2 bytes per opcode"
        );
    }

    function testSubParserWordParsersByteLengthMatchesCount() external pure {
        assertEq(
            SUB_PARSER_WORD_PARSERS.length,
            SUB_PARSER_WORD_PARSERS_LENGTH * 2,
            "SUB_PARSER_WORD_PARSERS must be exactly 2 bytes per word"
        );
    }

    function testOperandHandlerPointersByteLengthMatchesCount() external pure {
        assertEq(
            OPERAND_HANDLER_FUNCTION_POINTERS.length,
            SUB_PARSER_WORD_PARSERS_LENGTH * 2,
            "OPERAND_HANDLER_FUNCTION_POINTERS must be exactly 2 bytes per word"
        );
    }
}
