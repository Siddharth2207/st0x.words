// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {ERC4626Words} from "../../../src/concrete/ERC4626Words.sol";
import {
    OPCODE_FUNCTION_POINTERS,
    INTEGRITY_FUNCTION_POINTERS,
    SUB_PARSER_WORD_PARSERS,
    OPERAND_HANDLER_FUNCTION_POINTERS
} from "../../../src/generated/ERC4626Words.pointers.sol";
import {OPCODE_FUNCTION_POINTERS_LENGTH} from "../../../src/abstract/ERC4626Extern.sol";
import {LibOpERC4626ConvertToAssets} from "../../../src/lib/op/erc4626/LibOpERC4626ConvertToAssets.sol";
import {LibOpERC4626ConvertToShares} from "../../../src/lib/op/erc4626/LibOpERC4626ConvertToShares.sol";
import {OperandV2} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";

contract ERC4626WordsExternPointersTest is Test {
    ERC4626Words internal words;

    function setUp() external {
        words = new ERC4626Words();
    }

    function testOpcodePointersMatchCommitted() external {
        assertEq(
            words.buildOpcodeFunctionPointers(),
            OPCODE_FUNCTION_POINTERS,
            "committed OPCODE_FUNCTION_POINTERS drifted from freshly-built table"
        );
    }

    function testIntegrityPointersMatchCommitted() external {
        assertEq(
            words.buildIntegrityFunctionPointers(),
            INTEGRITY_FUNCTION_POINTERS,
            "committed INTEGRITY_FUNCTION_POINTERS drifted from freshly-built table"
        );
    }

    function testSubParserWordParsersMatchCommitted() external {
        assertEq(
            words.buildSubParserWordParsers(),
            SUB_PARSER_WORD_PARSERS,
            "committed SUB_PARSER_WORD_PARSERS drifted from freshly-built table"
        );
    }

    function testOperandHandlerPointersMatchCommitted() external {
        assertEq(
            words.buildOperandHandlerFunctionPointers(),
            OPERAND_HANDLER_FUNCTION_POINTERS,
            "committed OPERAND_HANDLER_FUNCTION_POINTERS drifted from freshly-built table"
        );
    }

    /// @dev Each 2-byte integrity slot must be non-zero; zero means an opcode
    /// was never assigned. Slot values are NOT pairwise distinct: both words'
    /// integrity functions are extensionally identical (2 inputs, 1 output),
    /// so the compiler deduplicates them to a single function pointer and the
    /// table legitimately repeats one value. Wrong-wiring between the two is
    /// covered behaviorally by the bad-arity parse tests in
    /// ERC4626Words.parse.t.sol.
    function testIntegritySlotsAreAssigned() external view {
        bytes memory pointers = words.buildIntegrityFunctionPointers();
        assertEq(pointers.length, OPCODE_FUNCTION_POINTERS_LENGTH * 2, "integrity table wrong length");
        for (uint256 i = 0; i < OPCODE_FUNCTION_POINTERS_LENGTH; i++) {
            uint16 slot = (uint16(uint8(pointers[i * 2])) << 8) | uint16(uint8(pointers[i * 2 + 1]));
            assertTrue(slot != 0, "integrity slot must be non-zero (opcode not assigned)");
        }
    }

    /// @dev convertToAssets integrity must return exactly (inputs=2, outputs=1).
    function testIntegrityConvertToAssetsReturns2Inputs1Output() external pure {
        (uint256 inputs, uint256 outputs) = LibOpERC4626ConvertToAssets.integrity(OperandV2.wrap(0), 0, 0);
        assertEq(inputs, 2, "convertToAssets integrity: must declare 2 inputs");
        assertEq(outputs, 1, "convertToAssets integrity: must declare 1 output");
    }

    /// @dev convertToShares integrity must return exactly (inputs=2, outputs=1).
    function testIntegrityConvertToSharesReturns2Inputs1Output() external pure {
        (uint256 inputs, uint256 outputs) = LibOpERC4626ConvertToShares.integrity(OperandV2.wrap(0), 0, 0);
        assertEq(inputs, 2, "convertToShares integrity: must declare 2 inputs");
        assertEq(outputs, 1, "convertToShares integrity: must declare 1 output");
    }
}
