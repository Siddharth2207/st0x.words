// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {stdError} from "forge-std-1.16.2/src/StdError.sol";
import {LibOpERC4626ConvertToShares} from "../../../../../src/lib/op/erc4626/LibOpERC4626ConvertToShares.sol";
import {NotAnAddress} from "rainlang-0.1.2/src/error/ErrRainType.sol";
import {OperandV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";
import {LossyConversionFromFloat, CoefficientOverflow} from "rain-math-float-0.1.1/src/error/ErrDecimalFloat.sol";
import {MockERC4626, MockERC20} from "../../../../utils/MockERC4626.sol";
import {UnexpectedInputs} from "../../../../../src/lib/op/erc4626/LibOpERC4626ConvertToShares.sol";

contract LibOpERC4626ConvertToSharesTest is Test {
    MockERC20 internal asset;
    MockERC4626 internal vault;

    function setUp() external {
        asset = new MockERC20(18);
        vault = new MockERC4626(18, address(asset), 1e18);
    }

    function _callRunShares(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);
    }

    function testIntegrity(OperandV2 operand, uint256 inputs, uint256 outputs) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpERC4626ConvertToShares.integrity(operand, inputs, outputs);
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function testRunOneToOne() external view {
        StackItem[] memory inputs = new StackItem[](2);
        // vault address as raw stack bits
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // 1.0 asset
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1, "should produce 1 output");

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 1e18, "1 asset should convert to 1 share in a 1:1 vault");
    }

    function testRunTwoAssets() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // 2.0 assets
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(2, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1);

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 2e18, "2 assets should convert to 2 shares in a 1:1 vault");
    }

    function testRunTwoToOneVault() external {
        // 1 share = 2 assets → 1 asset = 0.5 shares
        MockERC4626 vault2 = new MockERC4626(18, address(asset), 2e18);

        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault2)))));
        // 2.0 assets
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(2, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1);

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 1e18, "2 assets should convert to 1 share in a 2:1 vault");
    }

    function testRunOutputIsNonZeroForNonZeroInput() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);

        assertTrue(StackItem.unwrap(outputs[0]) != bytes32(0), "output should be non-zero for non-zero input");
    }

    function testRunRevertsOnOneInput() external {
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] =
            StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(uint256(uint160(address(vault)))), 0)));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedInputs.selector, uint256(2), uint256(1)));
        this._callRunShares(inputs);
    }

    function testRunRevertsOnZeroInputs() external {
        StackItem[] memory inputs = new StackItem[](0);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedInputs.selector, uint256(2), uint256(0)));
        this._callRunShares(inputs);
    }

    function testRunRevertsOnNonAddressVault() external {
        StackItem[] memory inputs = new StackItem[](2);
        // Any bit above the low 160 makes the vault stack item not an address.
        uint256 vaultWord = uint256(type(uint160).max) + 1;
        inputs[0] = StackItem.wrap(bytes32(vaultWord));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, vaultWord));
        this._callRunShares(inputs);
    }

    function testRunRevertsOnLossyAssetsInput() external {
        // vault with 0 asset decimals; 0.5 assets cannot be represented losslessly at 0 decimals
        MockERC20 asset0 = new MockERC20(0);
        MockERC4626 vault0 = new MockERC4626(0, address(asset0), 1);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault0)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(5, -1)));
        vm.expectRevert(abi.encodeWithSelector(LossyConversionFromFloat.selector, int256(5), int256(-1)));
        this._callRunShares(inputs);
    }

    function testRunFuzzConvertToSharesConsistency(uint32 assetsWhole, uint64 rate) external {
        rate = uint64(bound(rate, 1, type(uint64).max));
        MockERC4626 fv = new MockERC4626(18, address(asset), uint256(rate));

        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(fv)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(uint256(assetsWhole)), 0)));

        uint256 assetsRaw = uint256(assetsWhole) * 1e18;
        // Skip cases where the vault multiply overflows.
        bool overflow = assetsRaw != 0 && 1e18 > type(uint256).max / assetsRaw;
        if (overflow) return;
        uint256 expected = fv.convertToShares(assetsRaw);

        bool success;
        uint256 actual;
        try this._callRunShares(inputs) returns (StackItem[] memory out) {
            success = true;
            actual = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(out[0])), 18);
        } catch {}

        if (success) {
            assertEq(actual, expected, "run() convertToShares must match vault directly");
        }
    }

    function testRunZeroAssets() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(0, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1);
        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 0, "0 assets must convert to 0 shares");
    }

    function testRunMismatchedDecimals() external {
        // 6-decimal asset, 18-decimal vault share; assetsPerShare = 1e6 (1 asset per share at 6 dec).
        MockERC20 asset6 = new MockERC20(6);
        MockERC4626 vaultMixed = new MockERC4626(18, address(asset6), 1e6);

        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vaultMixed)))));
        // 2.0 assets (represented as Float 2e0 — the library converts using assetDecimals=6)
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(2, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);
        // 2 assets → convertToShares(2e6) = 2e6 * 1e18 / 1e6 = 2e18 raw shares, packed at 18 decimals.
        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 2e18, "2 (6-dec) assets must equal 2 (18-dec) shares");
        assertTrue(sharesRaw != 2e6, "result must use share decimals, not asset decimals");
    }

    function runExternal(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);
    }

    function testRunRevertsOnLossySharesOutput() external {
        // sharesRaw > type(int224).max triggers CoefficientOverflow in
        // fromFixedDecimalLosslessPacked (the output conversion path).
        // Use 0-decimal asset and vault with a 1:1 rate; supply 2 * 10^67 assets
        // so sharesRaw = 2 * 10^67 > int224.max (≈ 1.36e67).
        MockERC20 asset0 = new MockERC20(0);
        MockERC4626 vault0 = new MockERC4626(0, address(asset0), 1);

        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] =
            StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(uint256(uint160(address(vault0)))), 0)));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(2, 67)));

        vm.expectRevert(abi.encodeWithSelector(CoefficientOverflow.selector, int256(2) * int256(10) ** 67, int256(0)));
        this.runExternal(inputs);
    }

    function testRunZeroSupplyVaultReverts() external {
        MockERC4626 emptyVault = new MockERC4626(18, address(asset), 0);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(emptyVault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        vm.expectRevert(stdError.divisionError);
        this.runExternal(inputs);
    }

    function testRunRevertsOnLossyAssetInput() external {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // 1e-19 assets: finer than the asset's 18 decimals, cannot be converted losslessly to uint256
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, -19)));
        vm.expectRevert(abi.encodeWithSelector(LossyConversionFromFloat.selector, int256(1), int256(-19)));
        this.runExternal(inputs);
    }

    function testRunRoundsSharesDown() external {
        // 1 share = 3 assets → 1 asset = 0.333... shares; must round DOWN (favors protocol).
        MockERC4626 vault3 = new MockERC4626(18, address(asset), 3e18);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault3)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        // floor(1e18 * 1e18 / 3e18) = 333333333333333333
        assertEq(sharesRaw, 333333333333333333, "shares must round DOWN, favoring the protocol");
        assertTrue(sharesRaw < 333333333333333334, "must not round up toward the interactive caller");
    }

    function testRunRoundsDownOnPrecisionLoss() external {
        // assetsPerShare = 3e18; 1 asset rounds down to 333333333333333333 shares
        MockERC4626 vault3 = new MockERC4626(18, address(asset), 3e18);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault3)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);
        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 333333333333333333, "convertToShares must round DOWN (floor)");
        assertLt(sharesRaw, uint256(1e18) / 3 + 1, "must not round up");
    }
}
