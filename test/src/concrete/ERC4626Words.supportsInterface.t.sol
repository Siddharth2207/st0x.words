// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {ERC4626Words} from "src/concrete/ERC4626Words.sol";
import {ISubParserV4} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {IIntegrityToolingV1} from "rain-sol-codegen-0.1.0/src/interface/IIntegrityToolingV1.sol";
import {IOpcodeToolingV1} from "rain-sol-codegen-0.1.0/src/interface/IOpcodeToolingV1.sol";
import {IParserToolingV1} from "rain-sol-codegen-0.1.0/src/interface/IParserToolingV1.sol";
import {ISubParserToolingV1} from "rain-sol-codegen-0.1.0/src/interface/ISubParserToolingV1.sol";

/// @notice Tests that ERC4626Words.supportsInterface covers all interfaces from
/// both the SubParser and the Extern inheritance branches. The C3 linearization
/// over override(BaseRainlangSubParser, BaseRainlangExtern) must walk both bases,
/// and a regression dropping one branch must be caught.
///
/// Basic IERC165/IDescribedByMetaV1/IInterpreterExternV4 assertions live in
/// ERC4626WordsMetaTest. This suite pins the remaining interface ids from both
/// branches that were previously unasserted.
contract ERC4626WordsSupportsInterfaceTest is Test {
    ERC4626Words internal words;

    function setUp() external {
        words = new ERC4626Words();
    }

    /// SubParser branch: ISubParserV4 must be reported as supported.
    function testSupportsISubParserV4() external view {
        assertTrue(words.supportsInterface(type(ISubParserV4).interfaceId), "must support ISubParserV4");
    }

    /// SubParser branch: IParserToolingV1 must be reported as supported.
    function testSupportsIParserToolingV1() external view {
        assertTrue(words.supportsInterface(type(IParserToolingV1).interfaceId), "must support IParserToolingV1");
    }

    /// SubParser branch: ISubParserToolingV1 must be reported as supported.
    function testSupportsISubParserToolingV1() external view {
        assertTrue(words.supportsInterface(type(ISubParserToolingV1).interfaceId), "must support ISubParserToolingV1");
    }

    /// Extern branch: IIntegrityToolingV1 must be reported as supported.
    function testSupportsIIntegrityToolingV1() external view {
        assertTrue(words.supportsInterface(type(IIntegrityToolingV1).interfaceId), "must support IIntegrityToolingV1");
    }

    /// Extern branch: IOpcodeToolingV1 must be reported as supported.
    function testSupportsIOpcodeToolingV1() external view {
        assertTrue(words.supportsInterface(type(IOpcodeToolingV1).interfaceId), "must support IOpcodeToolingV1");
    }
}
