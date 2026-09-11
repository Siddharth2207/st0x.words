// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {ERC4626Words} from "../../../src/concrete/ERC4626Words.sol";
import {LibOpERC4626ConvertToAssets} from "../../../src/lib/op/erc4626/LibOpERC4626ConvertToAssets.sol";
import {LibOpERC4626ConvertToShares} from "../../../src/lib/op/erc4626/LibOpERC4626ConvertToShares.sol";
import {OperandV2, StackItem} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {IInterpreterExternV4} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterExternV4.sol";
import {ISubParserV4} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {Float, LibDecimalFloat} from "rain-math-float-0.1.1/src/lib/LibDecimalFloat.sol";
import {MockERC4626, MockERC20} from "../../utils/MockERC4626.sol";
import {IDescribedByMetaV1} from "rain-metadata-0.1.0/src/interface/IDescribedByMetaV1.sol";
import {IIntegrityToolingV1} from "rain-sol-codegen-0.1.0/src/interface/IIntegrityToolingV1.sol";
import {IOpcodeToolingV1} from "rain-sol-codegen-0.1.0/src/interface/IOpcodeToolingV1.sol";
import {IParserToolingV1} from "rain-sol-codegen-0.1.0/src/interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "rain-sol-codegen-0.1.0/src/interface/ISubParserToolingV1.sol";

/// @notice Tests ERC4626Words extern dispatch directly (bypassing the parser).
contract ERC4626WordsConversionsTest is Test {
    MockERC20 internal asset;
    MockERC4626 internal vault;
    ERC4626Words internal erc4626Words;

    function setUp() external {
        asset = new MockERC20(18);
        vault = new MockERC4626(18, address(asset), 1e18);
        erc4626Words = new ERC4626Words();
    }

    function testConvertToAssetsDispatch() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // 1.0 share
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1, "convertToAssets should produce 1 output");
        assertTrue(StackItem.unwrap(outputs[0]) != bytes32(0), "output should be non-zero");

        uint256 assetsRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(assetsRaw, 1e18, "1 share should be 1 asset");
    }

    function testConvertToSharesDispatch() external view {
        StackItem[] memory inputs = new StackItem[](2);
        inputs[0] = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // 1.0 asset
        inputs[1] = StackItem.wrap(Float.unwrap(LibDecimalFloat.packLossless(1, 0)));

        StackItem[] memory outputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), inputs);

        assertEq(outputs.length, 1, "convertToShares should produce 1 output");
        assertTrue(StackItem.unwrap(outputs[0]) != bytes32(0), "output should be non-zero");

        uint256 sharesRaw = LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(outputs[0])), 18);
        assertEq(sharesRaw, 1e18, "1 asset should be 1 share");
    }

    function testERC4626WordsDeploysSuccessfully() external view {
        assertTrue(address(erc4626Words) != address(0), "ERC4626Words should deploy");
    }

    function testSupportsInterfaceUnionOfBothBases() external view {
        assertTrue(erc4626Words.supportsInterface(0x01ffc9a7), "IERC165");
        // extern base
        assertTrue(erc4626Words.supportsInterface(type(IInterpreterExternV4).interfaceId), "IInterpreterExternV4");
        assertTrue(erc4626Words.supportsInterface(type(IIntegrityToolingV1).interfaceId), "IIntegrityToolingV1");
        assertTrue(erc4626Words.supportsInterface(type(IOpcodeToolingV1).interfaceId), "IOpcodeToolingV1");
        // subparser base
        assertTrue(erc4626Words.supportsInterface(type(ISubParserV4).interfaceId), "ISubParserV4");
        assertTrue(erc4626Words.supportsInterface(type(IDescribedByMetaV1).interfaceId), "IDescribedByMetaV1");
        assertTrue(erc4626Words.supportsInterface(type(IParserToolingV1).interfaceId), "IParserToolingV1");
        assertTrue(erc4626Words.supportsInterface(type(ISubParserToolingV1).interfaceId), "ISubParserToolingV1");
    }

    function testSupportsInterfaceRejectsUnknown() external view {
        assertFalse(erc4626Words.supportsInterface(0xffffffff), "0xffffffff must be false per ERC165");
    }

    function testSupportsInterfaceFuzz(uint32 rawId) external view {
        bytes4 interfaceId = bytes4(rawId);
        vm.assume(interfaceId != 0x01ffc9a7);
        vm.assume(interfaceId != type(IInterpreterExternV4).interfaceId);
        vm.assume(interfaceId != type(IIntegrityToolingV1).interfaceId);
        vm.assume(interfaceId != type(IOpcodeToolingV1).interfaceId);
        vm.assume(interfaceId != type(ISubParserV4).interfaceId);
        vm.assume(interfaceId != type(IDescribedByMetaV1).interfaceId);
        vm.assume(interfaceId != type(IParserToolingV1).interfaceId);
        vm.assume(interfaceId != type(ISubParserToolingV1).interfaceId);
        assertFalse(erc4626Words.supportsInterface(interfaceId), "unrelated id must be false");
    }

    function testConvertToAssetsAndSharesRoundTrip() external view {
        StackItem vaultItem = StackItem.wrap(bytes32(uint256(uint160(address(vault)))));
        // Start with 3.5 shares
        Float sharesIn = LibDecimalFloat.packLossless(35, -1);

        StackItem[] memory assetsInputs = new StackItem[](2);
        assetsInputs[0] = vaultItem;
        assetsInputs[1] = StackItem.wrap(Float.unwrap(sharesIn));

        StackItem[] memory assetsOutputs = LibOpERC4626ConvertToAssets.run(OperandV2.wrap(0), assetsInputs);

        // Convert back to shares
        StackItem[] memory sharesInputs = new StackItem[](2);
        sharesInputs[0] = vaultItem;
        sharesInputs[1] = assetsOutputs[0];

        StackItem[] memory sharesOutputs = LibOpERC4626ConvertToShares.run(OperandV2.wrap(0), sharesInputs);

        // In a 1:1 vault, shares_out should equal shares_in (within rounding)
        uint256 sharesOutRaw =
            LibDecimalFloat.toFixedDecimalLossless(Float.wrap(StackItem.unwrap(sharesOutputs[0])), 18);
        uint256 sharesInRaw = LibDecimalFloat.toFixedDecimalLossless(sharesIn, 18);
        assertEq(sharesOutRaw, sharesInRaw, "round-trip should return original share amount in 1:1 vault");
    }
}
