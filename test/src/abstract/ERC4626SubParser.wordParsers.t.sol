// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {OperandV2} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {
    IInterpreterExternV4,
    EncodedExternDispatchV2
} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterExternV4.sol";
import {LibExtern} from "rainlang-0.1.2/src/lib/extern/LibExtern.sol";
import {
    OPCODE_ERC4626_CONVERT_TO_ASSETS,
    OPCODE_ERC4626_CONVERT_TO_SHARES
} from "../../../src/abstract/ERC4626Extern.sol";
import {ERC4626SubParserWordParsersWrapper} from "./ERC4626SubParser.wordParsers.wrapper.sol";

/// @notice Pins that erc4626ConvertToAssetsSubParser and erc4626ConvertToSharesSubParser
/// emit the correct ExternDispatchV2 constant — i.e., the extern address and opcode index
/// are encoded exactly as LibExtern.encodeExternCall(encodeExternDispatch(opcode, operand)).
/// Catches opcode transposition (assets index vs shares index swapped), wrong extern address,
/// or a future encoding change that silently breaks eval dispatch. Covers issue #46.
contract ERC4626SubParserWordParsersTest is Test {
    ERC4626SubParserWordParsersWrapper internal words;

    uint256 constant CONSTANTS_HEIGHT = 0;
    uint256 constant IO_BYTE = 0x21;
    OperandV2 constant OPERAND = OperandV2.wrap(0);

    function setUp() external {
        words = new ERC4626SubParserWordParsersWrapper();
    }

    function testConvertToAssetsDispatchEncoding() external view {
        (,, bytes32[] memory constants) = words.convertToAssetsSubParserPublic(CONSTANTS_HEIGHT, IO_BYTE, OPERAND);

        bytes32 expected = EncodedExternDispatchV2.unwrap(
            LibExtern.encodeExternCall(
                IInterpreterExternV4(address(words)),
                LibExtern.encodeExternDispatch(OPCODE_ERC4626_CONVERT_TO_ASSETS, OPERAND)
            )
        );

        assertEq(constants.length, 1, "constants length must be 1");
        assertEq(constants[0], expected, "assets: wrong ExternDispatchV2 encoding");
    }

    function testConvertToSharesDispatchEncoding() external view {
        (,, bytes32[] memory constants) = words.convertToSharesSubParserPublic(CONSTANTS_HEIGHT, IO_BYTE, OPERAND);

        bytes32 expected = EncodedExternDispatchV2.unwrap(
            LibExtern.encodeExternCall(
                IInterpreterExternV4(address(words)),
                LibExtern.encodeExternDispatch(OPCODE_ERC4626_CONVERT_TO_SHARES, OPERAND)
            )
        );

        assertEq(constants.length, 1, "constants length must be 1");
        assertEq(constants[0], expected, "shares: wrong ExternDispatchV2 encoding");
    }

    function testAssetsAndSharesConstantsDiffer() external view {
        (,, bytes32[] memory assetsConstants) = words.convertToAssetsSubParserPublic(CONSTANTS_HEIGHT, IO_BYTE, OPERAND);
        (,, bytes32[] memory sharesConstants) = words.convertToSharesSubParserPublic(CONSTANTS_HEIGHT, IO_BYTE, OPERAND);

        assertTrue(assetsConstants[0] != sharesConstants[0], "assets and shares must have different dispatch encodings");
    }
}
