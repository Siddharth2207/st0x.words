// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibRainDeploy} from "rain-deploy-0.1.8/src/lib/LibRainDeploy.sol";
import {ERC4626Words} from "../../../src/concrete/ERC4626Words.sol";
import {
    BYTECODE_HASH,
    DEPLOYED_ADDRESS,
    OPCODE_FUNCTION_POINTERS,
    INTEGRITY_FUNCTION_POINTERS,
    SUB_PARSER_WORD_PARSERS,
    OPERAND_HANDLER_FUNCTION_POINTERS
} from "../../../src/generated/ERC4626Words.pointers.sol";

/// @notice Asserts committed pointer constants equal freshly-built equivalents.
/// Covers HIGH issues: pointer/integrity dispatch tables can silently drift
/// when build functions and committed constants disagree.
contract ERC4626WordsPointersTest is Test {
    ERC4626Words internal words;

    function setUp() external {
        words = new ERC4626Words();
    }

    function testBytecodeHashMatchesDeployedCode() external view {
        assertEq(address(words).codehash, BYTECODE_HASH, "BYTECODE_HASH is stale");
    }

    /// @notice The committed deploy address is the Zoltu address of the source
    /// in this checkout. Deploying the current creation code through an etched
    /// Zoltu factory must land on exactly the committed constant, so the deploy
    /// script's target and the source it deploys can never disagree. Local
    /// only: no fork, no chain, no assertion about any network.
    function testDeployedAddressMatchesCurrentSource() external {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(type(ERC4626Words).creationCode);
        assertEq(deployed, DEPLOYED_ADDRESS, "DEPLOYED_ADDRESS is stale");
        assertEq(deployed.codehash, BYTECODE_HASH, "BYTECODE_HASH is stale for the Zoltu deploy");
    }

    function testOpcodeFunctionPointersMatchCommitted() external view {
        assertEq(
            words.buildOpcodeFunctionPointers(), OPCODE_FUNCTION_POINTERS, "opcode pointers drifted from committed"
        );
    }

    function testIntegrityFunctionPointersMatchCommitted() external view {
        assertEq(
            words.buildIntegrityFunctionPointers(),
            INTEGRITY_FUNCTION_POINTERS,
            "integrity pointers drifted from committed"
        );
    }

    function testSubParserWordParsersMatchCommitted() external view {
        assertEq(
            words.buildSubParserWordParsers(), SUB_PARSER_WORD_PARSERS, "sub-parser word parsers drifted from committed"
        );
    }

    function testOperandHandlerFunctionPointersMatchCommitted() external view {
        assertEq(
            words.buildOperandHandlerFunctionPointers(),
            OPERAND_HANDLER_FUNCTION_POINTERS,
            "operand handler pointers drifted from committed"
        );
    }

    function testLiteralParserFunctionPointersEmpty() external view {
        assertEq(words.buildLiteralParserFunctionPointers(), bytes(""), "literal parser pointers must be empty");
    }

    function testOpcodeFunctionPointersLengthIsNonZero() external pure {
        assertTrue(OPCODE_FUNCTION_POINTERS.length > 0, "OPCODE_FUNCTION_POINTERS must not be empty");
    }

    function testIntegrityFunctionPointersLengthIsNonZero() external pure {
        assertTrue(INTEGRITY_FUNCTION_POINTERS.length > 0, "INTEGRITY_FUNCTION_POINTERS must not be empty");
    }

    function testOpcodeAndIntegrityPointerLengthsMatch() external pure {
        assertEq(
            OPCODE_FUNCTION_POINTERS.length,
            INTEGRITY_FUNCTION_POINTERS.length,
            "opcode and integrity pointer arrays must have equal length"
        );
    }

    function testSubParserAndOperandHandlerLengthsMatch() external pure {
        assertEq(
            SUB_PARSER_WORD_PARSERS.length,
            OPERAND_HANDLER_FUNCTION_POINTERS.length,
            "sub-parser word parsers and operand handler arrays must have equal length"
        );
    }
}
