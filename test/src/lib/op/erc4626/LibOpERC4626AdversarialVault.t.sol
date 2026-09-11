// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibOpERC4626ConvertToAssets} from "../../../../../src/lib/op/erc4626/LibOpERC4626ConvertToAssets.sol";
import {LibOpERC4626ConvertToShares} from "../../../../../src/lib/op/erc4626/LibOpERC4626ConvertToShares.sol";
import {OperandV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";
import {LossyConversionToFloat, FixedDecimalOverflow} from "rain-math-float-0.1.1/src/error/ErrDecimalFloat.sol";
import {MockERC20} from "../../../../utils/MockERC20.sol";
import {MaliciousERC4626} from "../../../../utils/MaliciousERC4626.sol";
import {MockERC4626} from "../../../../utils/MockERC4626.sol";
import {NotAnAddress} from "rainlang-0.1.2/src/error/ErrRainType.sol";

/// @notice Tests that an adversarial vault returning type(uint256).max causes a
/// revert with LossyConversionToFloat rather than silent data corruption.
/// Covers issues #88 (adversarial convertToAssets), #107 (adversarial
/// convertToShares), and #153 (MockERC4626 cannot model adversarial scenarios).
contract LibOpERC4626AdversarialVaultTest is Test {
    MockERC20 internal asset;
    MaliciousERC4626 internal malVault;

    function setUp() external {
        asset = new MockERC20(18);
        malVault = new MaliciousERC4626(18, address(asset));
    }

    /// External wrapper so vm.expectRevert crosses a call boundary.
    function runConvertToAssets(StackItem[] calldata inputs) external view returns (StackItem[] memory) {
        StackItem[] memory memInputs = new StackItem[](inputs.length);
        for (uint256 i = 0; i < inputs.length; i++) {
            memInputs[i] = inputs[i];
        }
        return LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), memInputs);
    }

    /// External wrapper so vm.expectRevert crosses a call boundary.
    function runConvertToShares(StackItem[] calldata inputs) external view returns (StackItem[] memory) {
        StackItem[] memory memInputs = new StackItem[](inputs.length);
        for (uint256 i = 0; i < inputs.length; i++) {
            memInputs[i] = inputs[i];
        }
        return LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), memInputs);
    }

    /// An adversarial vault returning type(uint256).max from convertToAssets
    /// must revert with LossyConversionToFloat, not silently corrupt the result.
    function testAdversarialConvertToAssetsReverts() external {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(malVault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        // type(uint256).max / 10 fits in int256; exponent shifts by +1 because the
        // value exceeded int256 max and was divided by 10 inside fromFixedDecimalLossy.
        vm.expectRevert(
            abi.encodeWithSelector(LossyConversionToFloat.selector, int256(type(uint256).max / 10), int256(-17))
        );
        this.runConvertToAssets(inputs);
    }

    /// An adversarial vault returning type(uint256).max from convertToShares
    /// must revert with LossyConversionToFloat, not silently corrupt the result.
    function testAdversarialConvertToSharesReverts() external {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(malVault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        vm.expectRevert(
            abi.encodeWithSelector(LossyConversionToFloat.selector, int256(type(uint256).max / 10), int256(-17))
        );
        this.runConvertToShares(inputs);
    }

    /// A conversion whose floor division loses a remainder must return the
    /// floored value: 1 raw share unit at assetsPerShare = 1e18 + 1 yields
    /// 1 * (1e18 + 1) / 1e18 = 1 raw asset unit, the +1 remainder dropped.
    function testConvertToAssetsFloorsRemainder() external {
        MockERC4626 oddVault = new MockERC4626(18, address(asset), 1e18 + 1);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(oddVault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, -18)));

        StackItem[] memory outputs = this.runConvertToAssets(inputs);

        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 1, "assets out must be the floored vault result");
    }

    /// 1 raw asset unit at assetsPerShare = 1e18 + 1 yields
    /// 1 * 1e18 / (1e18 + 1) = 0 raw share units: floored to zero, never
    /// rounded up.
    function testConvertToSharesFloorsRemainderToZero() external {
        MockERC4626 oddVault = new MockERC4626(18, address(asset), 1e18 + 1);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(oddVault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, -18)));

        StackItem[] memory outputs = this.runConvertToShares(inputs);

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 0, "shares out must floor to zero");
    }

    /// A vault input whose stack bits exceed uint160 range must revert with
    /// the typed NotAnAddress error carrying the full offending word.
    function testConvertToAssetsRevertsOnOversizedAddress() external {
        uint256 oversized = (uint256(1) << 160) | uint256(uint160(address(malVault)));
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(oversized));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, oversized));
        this.runConvertToAssets(inputs);
    }

    /// Same oversized-address guard on the shares side.
    function testConvertToSharesRevertsOnOversizedAddress() external {
        uint256 oversized = (uint256(1) << 160) | uint256(uint160(address(malVault)));
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(oversized));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, oversized));
        this.runConvertToShares(inputs);
    }

    /// A vault reporting an absurd decimals value (255) must revert cleanly in
    /// the share-amount rescale rather than silently corrupting the conversion.
    function testConvertToAssetsRevertsOnHostileVaultDecimals() external {
        MockERC4626 hostileVault = new MockERC4626(255, address(asset), 1e18);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(hostileVault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        vm.expectRevert(abi.encodeWithSelector(FixedDecimalOverflow.selector, int256(1), int256(0), uint256(255)));
        this.runConvertToAssets(inputs);
    }

    /// An underlying asset reporting an absurd decimals value (255) must revert
    /// cleanly in the asset-amount rescale.
    function testConvertToSharesRevertsOnHostileAssetDecimals() external {
        MockERC20 hostileAsset = new MockERC20(255);
        MockERC4626 vaultWithHostileAsset = new MockERC4626(18, address(hostileAsset), 1e18);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vaultWithHostileAsset)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        vm.expectRevert(abi.encodeWithSelector(FixedDecimalOverflow.selector, int256(1), int256(0), uint256(255)));
        this.runConvertToShares(inputs);
    }
}
