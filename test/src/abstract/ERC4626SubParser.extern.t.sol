// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {ERC4626SubParserExternWrapper} from "./ERC4626SubParser.externWrapper.sol";

/// @notice Pins extern() to address(this) for ERC4626Words.
/// erc4626ConvertToAssetsSubParser and erc4626ConvertToSharesSubParser are
/// view functions dispatched through a pure function-pointer table in
/// BaseRainlangSubParser. Their only state access is extern(), which must
/// return address(this) (an immutable fact about the executing contract) so
/// the compiler's view/pure boundary is respected at dispatch time. Any future
/// override that returns a different address or reads other state would
/// silently broaden the mutability guarantee. Covers issue #48.
contract ERC4626SubParserExternTest is Test {
    ERC4626SubParserExternWrapper internal words;

    function setUp() external {
        words = new ERC4626SubParserExternWrapper();
    }

    function testExternIsAddressThis() external view {
        assertEq(words.externPublic(), address(words), "extern() must return address(this)");
    }
}
