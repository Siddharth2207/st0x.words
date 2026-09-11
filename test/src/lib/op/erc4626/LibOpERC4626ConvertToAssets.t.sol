// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {stdError} from "forge-std-1.16.2/src/StdError.sol";
import {LibOpERC4626ConvertToAssets} from "../../../../../src/lib/op/erc4626/LibOpERC4626ConvertToAssets.sol";
import {NotAnAddress} from "rainlang-0.1.2/src/error/ErrRainType.sol";
import {OperandV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";
import {LossyConversionFromFloat} from "rain-math-float-0.1.1/src/error/ErrDecimalFloat.sol";
import {MockERC4626, MockERC20} from "../../../../utils/MockERC4626.sol";
import {UnexpectedInputs} from "../../../../../src/lib/op/erc4626/LibOpERC4626ConvertToAssets.sol";

contract LibOpERC4626ConvertToAssetsTest is Test {
    MockERC20 internal asset;
    MockERC4626 internal vault;

    function setUp() external {
        asset = new MockERC20(18);
        vault = new MockERC4626(18, address(asset), 1e18);
    }

    function _callRunAssets(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);
    }

    function testIntegrity(OperandV2 operand, uint256 inputs, uint256 outputs) external pure {
        (uint256 calcInputs, uint256 calcOutputs) = LibOpERC4626ConvertToAssets.integrity(operand, inputs, outputs);
        assertEq(calcInputs, 2);
        assertEq(calcOutputs, 1);
    }

    function testRunOneToOne() external view {
        StackItem[] memory inputs = new StackItem[](2);
        // vault address as raw stack bits
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // 1.0 share
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1, "should produce 1 output");

        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 1e18, "1 share should convert to 1 asset in a 1:1 vault");
    }

    function testRunTwoShares() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // 2.0 shares
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(2, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1);

        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 2e18, "2 shares should convert to 2 assets in a 1:1 vault");
    }

    function testRunTwoToOneVault() external {
        // 1 share = 2 assets
        MockERC4626 vault2 = new MockERC4626(18, address(asset), 2e18);

        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault2)))));
        // 1.0 share
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1);

        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 2e18, "1 share should convert to 2 assets in a 2:1 vault");
    }

    function testRunOutputIsNonZeroForNonZeroInput() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);

        assertTrue(StackItem.unwrap(outputs[0]) != bytes32(0), "output should be non-zero for non-zero input");
    }

    function testRunRevertsOnOneInput() external {
        StackItem[] memory inputs = new StackItem[](1);
        inputs[0] =
            StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(uint256(uint160(address(vault)))), 0)));
        vm.expectRevert(abi.encodeWithSelector(UnexpectedInputs.selector, uint256(2), uint256(1)));
        this._callRunAssets(inputs);
    }

    function testRunRevertsOnZeroInputs() external {
        StackItem[] memory inputs = new StackItem[](0);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedInputs.selector, uint256(2), uint256(0)));
        this._callRunAssets(inputs);
    }

    /// @notice The guard accepts the entire address range: the maximum address
    /// passes the round-trip check and is called, with its reads mocked.
    function testRunAcceptsMaxAddressVault() external {
        address maxAddr = address(type(uint160).max);
        vm.mockCall(maxAddr, abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));
        vm.mockCall(maxAddr, abi.encodeWithSignature("asset()"), abi.encode(address(asset)));
        vm.mockCall(maxAddr, abi.encodeWithSignature("convertToAssets(uint256)"), abi.encode(uint256(1e18)));
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(type(uint160).max)));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        StackItem[] memory outputs = this._callRunAssets(inputs);
        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 1e18, "max address vault must be called, not rejected");
    }

    function testRunRevertsOnNonAddressVault() external {
        StackItem[] memory inputs = new StackItem[](2);
        // Any bit above the low 160 makes the vault stack item not an address.
        uint256 vaultWord = uint256(type(uint160).max) + 1;
        inputs[0] = StackItem.wrap(bytes32(vaultWord));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        vm.expectRevert(abi.encodeWithSelector(NotAnAddress.selector, vaultWord));
        this._callRunAssets(inputs);
    }

    function testRunRevertsOnLossySharesInput() external {
        // vault with 0 share decimals; 0.5 shares cannot be represented losslessly at 0 decimals
        MockERC4626 v0 = new MockERC4626(0, address(asset), 1);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(v0)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(5, -1)));
        vm.expectRevert(abi.encodeWithSelector(LossyConversionFromFloat.selector, int256(5), int256(-1)));
        this._callRunAssets(inputs);
    }

    function testRunConvertToAssetsMonotonicFuzz(uint32 sharesA, uint32 sharesB) external {
        vm.assume(sharesA <= sharesB);

        StackItem[] memory inA = new StackItem[](2);
        inA[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        inA[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(uint256(sharesA)), 0)));

        StackItem[] memory inB = new StackItem[](2);
        inB[0] = inA[0];
        inB[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(int256(uint256(sharesB)), 0)));

        bool successA;
        uint256 assetsA;
        try this._callRunAssets(inA) returns (StackItem[] memory out) {
            successA = true;
            assetsA = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(out[0])), 18);
        } catch {}

        bool successB;
        uint256 assetsB;
        try this._callRunAssets(inB) returns (StackItem[] memory out) {
            successB = true;
            assetsB = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(out[0])), 18);
        } catch {}

        if (successA && successB) {
            assertLe(assetsA, assetsB, "convertToAssets must be monotonic: more shares => more assets");
        }
    }

    function testRunZeroShares() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(0, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1);
        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 0, "0 shares must convert to 0 assets");
    }

    function testRunRoundsDownFavoringVault() external {
        // assetsPerShare=3: 1 whole share → convertToAssets(1e18) = 1e18*3/1e18 = 3 (exact).
        MockERC4626 oddVault = new MockERC4626(18, address(asset), 3);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(oddVault)))));

        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));
        StackItem[] memory outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);
        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 3, "1 whole share must equal 3 raw assets");

        // 4 raw shares (4e-18 shares): convertToAssets(4) = 4*3/1e18 = 0 (floor). Proves round-DOWN.
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(4, -18)));
        outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);
        uint256 assetsRaw2 = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw2, 0, "fractional-share remainder must round down (favor vault), not up");
    }

    function runExternal(StackItem[] memory inputs) external view returns (StackItem[] memory) {
        return LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);
    }

    function testRunZeroRateVaultReturnsZero() external {
        MockERC4626 zeroRateVault = new MockERC4626(18, address(asset), 0);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(zeroRateVault)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = this.runExternal(inputs);

        assertEq(outputs.length, 1);
        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 0, "any shares in a zero-rate vault must convert to 0 assets");
    }

    function testRunRevertsOnLossyShareInput() external {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // 1e-19 shares: finer than the vault's 18 decimals, cannot be converted losslessly to uint256
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, -19)));
        vm.expectRevert(abi.encodeWithSelector(LossyConversionFromFloat.selector, int256(1), int256(-19)));
        this.runExternal(inputs);
    }

    function testRunRoundsDownOnPrecisionLoss() external {
        // assetsPerShare = 1e18/3 = 333333333333333333; 1 share rounds down to 333333333333333333 assets
        MockERC4626 vault3 = new MockERC4626(18, address(asset), uint256(1e18) / 3);
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault3)))));
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);
        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 333333333333333333, "convertToAssets must round DOWN (floor)");
        assertLt(assetsRaw, uint256(1e18) / 3 + 1, "must not round up");
    }
}
