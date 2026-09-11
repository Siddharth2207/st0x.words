// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {OPCODE_FUNCTION_POINTERS_LENGTH} from "../../../src/abstract/ERC4626Extern.sol";
import {SUB_PARSER_WORD_PARSERS_LENGTH} from "../../../src/lib/parse/LibERC4626SubParser.sol";
import {
    OPCODE_FUNCTION_POINTERS,
    INTEGRITY_FUNCTION_POINTERS,
    SUB_PARSER_WORD_PARSERS,
    OPERAND_HANDLER_FUNCTION_POINTERS
} from "../../../src/generated/ERC4626Words.pointers.sol";

contract ERC4626WordsLengthConstantsTest is Test {
    function testOpcodeLengthEqualsSubParserLength() external pure {
        assertEq(
            OPCODE_FUNCTION_POINTERS_LENGTH,
            SUB_PARSER_WORD_PARSERS_LENGTH,
            "OPCODE_FUNCTION_POINTERS_LENGTH and SUB_PARSER_WORD_PARSERS_LENGTH must be equal"
        );
    }

    function testGeneratedBytesMeetLengthConstants() external pure {
        assertEq(
            OPCODE_FUNCTION_POINTERS.length / 2,
            OPCODE_FUNCTION_POINTERS_LENGTH,
            "OPCODE_FUNCTION_POINTERS byte count must match OPCODE_FUNCTION_POINTERS_LENGTH"
        );
        assertEq(
            INTEGRITY_FUNCTION_POINTERS.length / 2,
            OPCODE_FUNCTION_POINTERS_LENGTH,
            "INTEGRITY_FUNCTION_POINTERS byte count must match OPCODE_FUNCTION_POINTERS_LENGTH"
        );
        assertEq(
            SUB_PARSER_WORD_PARSERS.length / 2,
            SUB_PARSER_WORD_PARSERS_LENGTH,
            "SUB_PARSER_WORD_PARSERS byte count must match SUB_PARSER_WORD_PARSERS_LENGTH"
        );
        assertEq(
            OPERAND_HANDLER_FUNCTION_POINTERS.length / 2,
            SUB_PARSER_WORD_PARSERS_LENGTH,
            "OPERAND_HANDLER_FUNCTION_POINTERS byte count must match SUB_PARSER_WORD_PARSERS_LENGTH"
        );
    }
}
