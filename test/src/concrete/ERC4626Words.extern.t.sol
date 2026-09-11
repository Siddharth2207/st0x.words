// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {ERC4626Words} from "../../../src/concrete/ERC4626Words.sol";
import {
    OPCODE_ERC4626_CONVERT_TO_ASSETS,
    OPCODE_ERC4626_CONVERT_TO_SHARES,
    OPCODE_FUNCTION_POINTERS_LENGTH
} from "../../../src/abstract/ERC4626Extern.sol";
import {ExternDispatchV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterExternV4.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";
import {ExternOpcodeOutOfRange} from "rainlang-0.1.2/src/error/ErrExtern.sol";
import {MockERC4626, MockERC20} from "../../utils/MockERC4626.sol";

/// @notice Tests that ERC4626Words.extern() dispatches through the committed
/// OPCODE_FUNCTION_POINTERS table and that externIntegrity() correctly reports
/// the 2-input/1-output signature for each opcode.
contract ERC4626WordsExternTest is Test {
    ERC4626Words internal words;
    MockERC20 internal asset;
    MockERC4626 internal vault;

    /// @dev 1 share (18-decimal) = 2 USDC (6-decimal).
    uint256 internal constant ASSETS_PER_SHARE = 2e6;

    function setUp() external {
        words = new ERC4626Words();
        asset = new MockERC20(6);
        vault = new MockERC4626(18, address(asset), ASSETS_PER_SHARE);
    }

    function makeDispatch(uint256 opcode) internal pure returns (ExternDispatchV2) {
        return ExternDispatchV2.wrap(bytes32(opcode << 16));
    }

    function vaultItem() internal view returns (StackItem) {
        return StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
    }

    /// @dev Opcode 0 must route to convertToAssets: 1 share (Float 1.0) → 2 USDC (6 decimals).
    function testExternConvertToAssetsRouting() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = vaultItem();
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = words.extern(makeDispatch(OPCODE_ERC4626_CONVERT_TO_ASSETS), inputs);

        assertEq(outputs.length, 1, "extern must return 1 output");
        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 6);
        assertEq(assetsRaw, 2e6, "opcode 0: 1 share must yield 2 USDC");
    }

    /// @dev Opcode 1 must route to convertToShares: 2 USDC (Float 2.0) → 1 share (18 decimals).
    function testExternConvertToSharesRouting() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = vaultItem();
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(2, 0)));

        StackItem[] memory outputs = words.extern(makeDispatch(OPCODE_ERC4626_CONVERT_TO_SHARES), inputs);

        assertEq(outputs.length, 1, "extern must return 1 output");
        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 1e18, "opcode 1: 2 USDC must yield 1 share");
    }

    /// @dev Opcode 0 and opcode 1 must route to DISTINCT functions.
    /// With a 2:1 vault and Float(1.0) as input amount:
    ///   opcode 0 treats it as 1 share → 2 USDC
    ///   opcode 1 treats it as 1 unit of USDC → 0.5 shares (floor rounds to 5e17 raw)
    /// A swap in OPCODE_FUNCTION_POINTERS would produce the wrong value.
    function testExternOpcodeRoutingIsDistinct() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = vaultItem();
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory out0 = words.extern(makeDispatch(OPCODE_ERC4626_CONVERT_TO_ASSETS), inputs);
        StackItem[] memory out1 = words.extern(makeDispatch(OPCODE_ERC4626_CONVERT_TO_SHARES), inputs);

        assertTrue(
            StackItem.unwrap(out0[0]) != StackItem.unwrap(out1[0]), "opcode 0 and opcode 1 must route to distinct fns"
        );
    }

    /// @dev externIntegrity for opcode 0 must report 2 inputs and 1 output.
    function testExternIntegrityConvertToAssetsReports2In1Out() external view {
        (uint256 actualInputs, uint256 actualOutputs) =
            words.externIntegrity(makeDispatch(OPCODE_ERC4626_CONVERT_TO_ASSETS), 0, 0);
        assertEq(actualInputs, 2, "convertToAssets integrity: must need 2 inputs");
        assertEq(actualOutputs, 1, "convertToAssets integrity: must produce 1 output");
    }

    /// @dev externIntegrity for opcode 1 must report 2 inputs and 1 output.
    function testExternIntegrityConvertToSharesReports2In1Out() external view {
        (uint256 actualInputs, uint256 actualOutputs) =
            words.externIntegrity(makeDispatch(OPCODE_ERC4626_CONVERT_TO_SHARES), 0, 0);
        assertEq(actualInputs, 2, "convertToShares integrity: must need 2 inputs");
        assertEq(actualOutputs, 1, "convertToShares integrity: must produce 1 output");
    }

    /// @dev Both opcodes share the same compiled integrity function (identical pointer bytes).
    /// This is the known-correct state because both integrity() impls are identical (return 2,1).
    /// Revisit this assertion if the libs ever diverge in their integrity signatures.
    function testIntegrityBothOpcodesSameCompiledFunction() external view {
        bytes memory rebuilt = words.buildIntegrityFunctionPointers();
        assertEq(rebuilt.length, OPCODE_FUNCTION_POINTERS_LENGTH * 2, "two 2-byte integrity slots");
        assertEq(rebuilt[0], rebuilt[2], "integrity slot 0 high byte must equal slot 1 high byte");
        assertEq(rebuilt[1], rebuilt[3], "integrity slot 0 low byte must equal slot 1 low byte");
    }

    /// @dev externIntegrity reverts for an out-of-range opcode.
    function testExternIntegrityOpcodeOutOfRangeReverts() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                ExternOpcodeOutOfRange.selector, uint256(999), uint256(OPCODE_FUNCTION_POINTERS_LENGTH)
            )
        );
        words.externIntegrity(makeDispatch(999), 0, 0);
    }
}
