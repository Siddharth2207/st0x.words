// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {ERC4626Words} from "../../../src/concrete/ERC4626Words.sol";
import {DESCRIBED_BY_META_HASH} from "../../../src/generated/ERC4626Words.pointers.sol";
import {IDescribedByMetaV1} from "rain-metadata-0.1.0/src/interface/IDescribedByMetaV1.sol";
import {IInterpreterExternV4} from "rain-interpreter-interface-0.1.0/src/interface/IInterpreterExternV4.sol";
import {ISubParserV4} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";

contract ERC4626WordsMetaTest is Test {
    ERC4626Words internal words;

    function setUp() external {
        words = new ERC4626Words();
    }

    function testDescribedByMetaV1ReturnsCommittedHash() external view {
        assertEq(
            words.describedByMetaV1(),
            DESCRIBED_BY_META_HASH,
            "describedByMetaV1() must return the committed DESCRIBED_BY_META_HASH constant"
        );
    }

    function testDescribedByMetaV1IsNonZero() external view {
        assertTrue(words.describedByMetaV1() != bytes32(0), "DESCRIBED_BY_META_HASH must be non-zero");
    }

    function testSupportsInterfaceIERC165() external view {
        assertTrue(words.supportsInterface(type(IERC165).interfaceId), "must support IERC165");
    }

    function testSupportsInterfaceDescribedByMetaV1() external view {
        assertTrue(
            words.supportsInterface(type(IDescribedByMetaV1).interfaceId),
            "must support IDescribedByMetaV1 (SubParser inheritance branch)"
        );
    }

    function testSupportsInterfaceInterpreterExternV4() external view {
        assertTrue(
            words.supportsInterface(type(IInterpreterExternV4).interfaceId),
            "must support IInterpreterExternV4 (Extern inheritance branch)"
        );
    }

    function testSupportsInterfaceISubParserV4() external view {
        assertTrue(
            words.supportsInterface(type(ISubParserV4).interfaceId),
            "must support ISubParserV4 (SubParser inheritance branch)"
        );
    }

    function testSupportsInterfaceReturnsFalseForUnknown() external view {
        assertFalse(words.supportsInterface(0xdeadbeef), "must return false for unknown interface ID");
    }

    /// @notice describedByMetaV1() must equal keccak256(meta/ERC4626Words.rain.meta).
    /// This pins the on-chain hash to the actual CBOR bytes so a stale DESCRIBED_BY_META_HASH
    /// or an out-of-sync meta file is caught immediately by CI.
    function testDescribedByMetaHashMatchesCBORFile() external view {
        bytes memory metaBytes = vm.readFileBinary("meta/ERC4626Words.rain.meta");
        bytes32 fileHash = keccak256(metaBytes);
        assertEq(words.describedByMetaV1(), fileHash, "on-chain hash must equal keccak256 of CBOR meta file");
    }
}
