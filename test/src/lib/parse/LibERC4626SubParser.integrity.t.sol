// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {OperandV2} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterV4.sol";
import {LibOpERC4626ConvertToAssets} from "src/lib/op/erc4626/LibOpERC4626ConvertToAssets.sol";
import {LibOpERC4626ConvertToShares} from "src/lib/op/erc4626/LibOpERC4626ConvertToShares.sol";
import {LibERC4626SubParser} from "src/lib/parse/LibERC4626SubParser.sol";

/// @notice Pins the integrity return values to the input/output counts claimed
/// by the authoringMetaV2 descriptions ("Accepts 2 inputs … Returns 1 output").
/// If the description strings or the opcode arity ever diverge, these tests catch it.
/// Covers #125.
contract LibERC4626SubParserIntegrityTest is Test {
    function testConvertToAssetsIntegrityReturnsTwo1() external pure {
        (uint256 inputs, uint256 outputs) = LibOpERC4626ConvertToAssets.integrity(OperandV2.wrap(0), 0, 0);
        assertEq(inputs, 2, "erc4626-convert-to-assets must accept exactly 2 inputs");
        assertEq(outputs, 1, "erc4626-convert-to-assets must produce exactly 1 output");
    }

    function testConvertToSharesIntegrityReturnsTwo1() external pure {
        (uint256 inputs, uint256 outputs) = LibOpERC4626ConvertToShares.integrity(OperandV2.wrap(0), 0, 0);
        assertEq(inputs, 2, "erc4626-convert-to-shares must accept exactly 2 inputs");
        assertEq(outputs, 1, "erc4626-convert-to-shares must produce exactly 1 output");
    }

    function testMetaDescriptionMatchesIntegrityInputCount() external pure {
        (uint256 assetsInputs,) = LibOpERC4626ConvertToAssets.integrity(OperandV2.wrap(0), 0, 0);
        (uint256 sharesInputs,) = LibOpERC4626ConvertToShares.integrity(OperandV2.wrap(0), 0, 0);
        assertEq(assetsInputs, sharesInputs, "both words must have the same input arity");
    }
}
