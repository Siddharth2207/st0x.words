// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {LibERC4626, IERC4626Minimal} from "../../../../src/lib/erc4626/LibERC4626.sol";
import {LibDecimalFloat, Float} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";
import {MockERC4626} from "../../../utils/MockERC4626.sol";
import {MockERC20} from "../../../utils/MockERC20.sol";

contract LibERC4626Test is Test {
    MockERC20 internal asset;
    MockERC4626 internal vault;

    function _callConvertToAssets(IERC4626Minimal vault_, Float sharesFloat) external view returns (Float) {
        return LibERC4626.convertToAssets(vault_, sharesFloat);
    }

    function _callConvertToShares(IERC4626Minimal vault_, Float assetsFloat) external view returns (Float) {
        return LibERC4626.convertToShares(vault_, assetsFloat);
    }

    /// @dev Set up a 1:1 vault with 18-decimal shares and 18-decimal assets.
    function setUp() external {
        asset = new MockERC20(18);
        // assetsPerShare = 1e18 means 1 share = 1 asset
        vault = new MockERC4626(18, address(asset), 1e18);
    }

    function testConvertToAssetsOneToOne() external view {
        IERC4626Minimal typedVault = IERC4626Minimal(address(vault));
        // 1.0 share
        Float sharesFloat = LibDecimalFloat.packLossless(1, 0);

        Float assetsFloat = LibERC4626.convertToAssets(typedVault, sharesFloat);

        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(assetsFloat, 18);
        assertEq(assetsRaw, 1e18, "1 share should be 1 asset in a 1:1 vault");
    }

    function testConvertToSharesOneToOne() external view {
        IERC4626Minimal typedVault = IERC4626Minimal(address(vault));
        // 1.0 asset
        Float assetsFloat = LibDecimalFloat.packLossless(1, 0);

        Float sharesFloat = LibERC4626.convertToShares(typedVault, assetsFloat);

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(sharesFloat, 18);
        assertEq(sharesRaw, 1e18, "1 asset should be 1 share in a 1:1 vault");
    }

    function testConvertToAssetsTwoToOne() external {
        // 1 share = 2 assets
        MockERC4626 vault2 = new MockERC4626(18, address(asset), 2e18);

        IERC4626Minimal typedVault = IERC4626Minimal(address(vault2));
        // 1.0 share
        Float sharesFloat = LibDecimalFloat.packLossless(1, 0);

        Float assetsFloat = LibERC4626.convertToAssets(typedVault, sharesFloat);

        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(assetsFloat, 18);
        assertEq(assetsRaw, 2e18, "1 share should be 2 assets in a 2:1 vault");
    }

    function testConvertToSharesHalfRate() external {
        // 1 share = 2 assets → 1 asset = 0.5 shares
        MockERC4626 vault2 = new MockERC4626(18, address(asset), 2e18);

        IERC4626Minimal typedVault = IERC4626Minimal(address(vault2));
        // 2.0 assets
        Float assetsFloat = LibDecimalFloat.packLossless(2, 0);

        Float sharesFloat = LibERC4626.convertToShares(typedVault, assetsFloat);

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(sharesFloat, 18);
        assertEq(sharesRaw, 1e18, "2 assets should be 1 share in a 2:1 vault");
    }

    function testConvertToAssetsWithSixDecimalAsset() external {
        // Simulate a vault backed by USDC (6 decimals) with 18-decimal shares
        MockERC20 usdc = new MockERC20(6);
        // 1 share = 1 USDC = 1e6 raw asset units
        MockERC4626 usdcVault = new MockERC4626(18, address(usdc), 1e6);

        IERC4626Minimal typedVault = IERC4626Minimal(address(usdcVault));
        // 1.0 share
        Float sharesFloat = LibDecimalFloat.packLossless(1, 0);

        Float assetsFloat = LibERC4626.convertToAssets(typedVault, sharesFloat);

        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(assetsFloat, 6);
        assertEq(assetsRaw, 1e6, "1 share should be 1 USDC (1e6 raw) in a 1:1 USDC vault");
    }

    function testConvertToSharesWithSixDecimalAsset() external {
        MockERC20 usdc = new MockERC20(6);
        // 1 share = 1 USDC
        MockERC4626 usdcVault = new MockERC4626(18, address(usdc), 1e6);

        IERC4626Minimal typedVault = IERC4626Minimal(address(usdcVault));
        // 1.0 USDC (represented as float)
        Float assetsFloat = LibDecimalFloat.packLossless(1, 0);

        Float sharesFloat = LibERC4626.convertToShares(typedVault, assetsFloat);

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(sharesFloat, 18);
        assertEq(sharesRaw, 1e18, "1 USDC should be 1 share in a 1:1 USDC vault");
    }

    function testConvertToSharesRevertsOnLossyAssetsInput() external {
        // 1e-19 has more precision than 18 decimal places; toFixedDecimalLossless must revert.
        Float assetsFloat = LibDecimalFloat.packLossless(1, -19);
        vm.expectRevert();
        this._callConvertToShares(IERC4626Minimal(address(vault)), assetsFloat);
    }

    function testConvertToAssetsRevertsOnLossySharesInput() external {
        // 1e-19 has more precision than 18 decimal places; toFixedDecimalLossless must revert.
        Float sharesFloat = LibDecimalFloat.packLossless(1, -19);
        vm.expectRevert();
        this._callConvertToAssets(IERC4626Minimal(address(vault)), sharesFloat);
    }

    function testConvertToSharesRevertsOnLossyInputWithSixDecimalAsset() external {
        MockERC20 usdc = new MockERC20(6);
        MockERC4626 usdcVault = new MockERC4626(18, address(usdc), 1e6);
        // 1e-7 has more precision than 6 decimal places; toFixedDecimalLossless must revert.
        Float assetsFloat = LibDecimalFloat.packLossless(1, -7);
        vm.expectRevert();
        this._callConvertToShares(IERC4626Minimal(address(usdcVault)), assetsFloat);
    }

    function testConvertToAssetsRoundsDownWithFractionalShares() external {
        // assetsPerShare=1 raw unit: 1 whole share (1e18 raw) gives 1 raw asset.
        // 0.5 shares (5e17 raw) → 5e17 * 1 / 1e18 = 0 (Solidity floor division).
        MockERC4626 v = new MockERC4626(18, address(asset), 1);
        IERC4626Minimal typedVault = IERC4626Minimal(address(v));
        Float sharesFloat = LibDecimalFloat.packLossless(5, -1);
        Float assetsFloat = LibERC4626.convertToAssets(typedVault, sharesFloat);
        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(assetsFloat, 18);
        assertEq(assetsRaw, 0, "fractional shares must round DOWN to 0 assets, never up");
    }

    function testConvertToSharesRoundsDownWithNonDivisibleRate() external {
        // 1 share = 3 assets: 1 asset → assets*1e18/assetsPerShare = 1e18*1e18/3e18 = 333333333333333333 (floor).
        MockERC4626 v3 = new MockERC4626(18, address(asset), 3e18);
        IERC4626Minimal typedVault = IERC4626Minimal(address(v3));
        Float assetsFloat = LibDecimalFloat.packLossless(1, 0);
        Float sharesFloat = LibERC4626.convertToShares(typedVault, assetsFloat);
        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(sharesFloat, 18);
        assertEq(sharesRaw, 333333333333333333, "convertToShares must round DOWN (favor protocol, not caller)");
        assertTrue(sharesRaw < 333333333333333334, "must not round up toward the interactive caller");
    }

    function _convertToAssets(IERC4626Minimal vault, Float sharesFloat) external view returns (Float) {
        return LibERC4626.convertToAssets(vault, sharesFloat);
    }

    function _convertToShares(IERC4626Minimal vault, Float assetsFloat) external view returns (Float) {
        return LibERC4626.convertToShares(vault, assetsFloat);
    }

    /// @notice For any whole-number shares input and any positive exchange rate,
    /// convertToAssets must produce the same value as the independent integer floor.
    /// Reverts (when the Float cannot represent the result) are skipped; the
    /// rounding assertion applies only to the non-reverting subset.
    function testFuzzConvertToAssetsFloorRounding(uint32 sharesWhole, uint64 rate) external {
        rate = uint64(bound(rate, 1, type(uint64).max));
        MockERC4626 v = new MockERC4626(18, address(asset), uint256(rate));
        IERC4626Minimal typedVault = IERC4626Minimal(address(v));
        Float sharesFloat = LibDecimalFloat.packLossless(int256(uint256(sharesWhole)), 0);

        uint256 sharesRaw = uint256(sharesWhole) * 1e18;
        // Skip inputs where the vault multiply overflows uint256.
        bool overflow = sharesRaw != 0 && uint256(rate) > type(uint256).max / sharesRaw;
        if (overflow) return;
        uint256 expected = sharesRaw * uint256(rate) / 1e18;

        bool success;
        uint256 actual;
        try this._convertToAssets(typedVault, sharesFloat) returns (Float f) {
            success = true;
            actual = LibDecimalFloat.toFixedDecimalLossless(f, 18);
        } catch {}
        if (success) {
            assertEq(actual, expected, "convertToAssets floor: must equal independent computation");
        }
    }

    /// @notice For any whole-number assets input and any positive exchange rate,
    /// convertToShares must produce the same value as the independent integer floor.
    function testFuzzConvertToSharesFloorRounding(uint32 assetsWhole, uint64 rate) external {
        rate = uint64(bound(rate, 1, type(uint64).max));
        MockERC4626 v = new MockERC4626(18, address(asset), uint256(rate));
        IERC4626Minimal typedVault = IERC4626Minimal(address(v));
        Float assetsFloat = LibDecimalFloat.packLossless(int256(uint256(assetsWhole)), 0);

        uint256 assetsRaw = uint256(assetsWhole) * 1e18;
        // Skip inputs where the vault multiply overflows uint256.
        bool overflow = assetsRaw != 0 && 1e18 > type(uint256).max / assetsRaw;
        if (overflow) return;
        uint256 expected = assetsRaw * 1e18 / uint256(rate);

        bool success;
        uint256 actual;
        try this._convertToShares(typedVault, assetsFloat) returns (Float f) {
            success = true;
            actual = LibDecimalFloat.toFixedDecimalLossless(f, 18);
        } catch {}
        if (success) {
            assertEq(actual, expected, "convertToShares floor: must equal independent computation");
        }
    }

    function testConvertToAssetsZeroShares() external view {
        IERC4626Minimal typedVault = IERC4626Minimal(address(vault));
        Float zeroShares = LibDecimalFloat.packLossless(0, 0);
        Float assetsFloat = LibERC4626.convertToAssets(typedVault, zeroShares);
        assertEq(LibDecimalFloat.toFixedDecimalLossless(assetsFloat, 18), 0, "0 shares must yield 0 assets");
    }

    function testConvertToSharesZeroAssets() external view {
        IERC4626Minimal typedVault = IERC4626Minimal(address(vault));
        Float zeroAssets = LibDecimalFloat.packLossless(0, 0);
        Float sharesFloat = LibERC4626.convertToShares(typedVault, zeroAssets);
        assertEq(LibDecimalFloat.toFixedDecimalLossless(sharesFloat, 18), 0, "0 assets must yield 0 shares");
    }

    function testConvertToAssetsLargeInput() external view {
        IERC4626Minimal typedVault = IERC4626Minimal(address(vault));
        // 1e9 whole shares: well within int64 range, exercises large fixed-point packing.
        Float sharesFloat = LibDecimalFloat.packLossless(1000000000, 0);
        Float assetsFloat = LibERC4626.convertToAssets(typedVault, sharesFloat);
        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(assetsFloat, 18);
        assertEq(assetsRaw, 1e27, "1e9 shares must yield 1e9 assets (1e27 raw) in a 1:1 vault");
    }

    function testConvertToSharesLargeInput() external view {
        IERC4626Minimal typedVault = IERC4626Minimal(address(vault));
        // 1e9 whole assets: exercises large fixed-point packing for convertToShares.
        Float assetsFloat = LibDecimalFloat.packLossless(1000000000, 0);
        Float sharesFloat = LibERC4626.convertToShares(typedVault, assetsFloat);
        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(sharesFloat, 18);
        assertEq(sharesRaw, 1e27, "1e9 assets must yield 1e9 shares (1e27 raw) in a 1:1 vault");
    }
}
