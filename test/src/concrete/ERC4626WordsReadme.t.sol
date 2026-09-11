// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.2/src/Test.sol";
import {AuthoringMetaV2} from "rain-interpreter-interface-0.1.0/src/interface/ISubParserV4.sol";
import {LibERC4626SubParser} from "../../../src/lib/parse/LibERC4626SubParser.sol";

/// @notice README.md must document every word declared by authoringMetaV2().
/// The decoded authoring meta is the oracle: renaming a word or adding a new
/// word in authoringMetaV2() without updating the README fails this test, and
/// there is no hardcoded word-name literal that could go stale alongside the
/// README.
contract ERC4626WordsReadmeTest is Test {
    /// Extracts the word name from its left-aligned zero-padded bytes32
    /// representation by trimming the trailing zero bytes.
    function wordName(bytes32 word) internal pure returns (bytes memory) {
        uint256 length = 0;
        while (length < 32 && word[length] != 0) {
            length++;
        }
        bytes memory name = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            name[i] = word[i];
        }
        return name;
    }

    function containsBytes(bytes memory haystack, bytes memory needle) internal pure returns (bool) {
        if (needle.length == 0) return true;
        if (haystack.length < needle.length) return false;
        for (uint256 i = 0; i <= haystack.length - needle.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    function testReadmeContainsEveryAuthoringMetaWordName() external view {
        bytes memory readme = bytes(vm.readFile("README.md"));
        AuthoringMetaV2[] memory meta = abi.decode(LibERC4626SubParser.authoringMetaV2(), (AuthoringMetaV2[]));
        assertTrue(meta.length > 0, "authoring meta must declare at least one word");
        for (uint256 i = 0; i < meta.length; i++) {
            bytes memory name = wordName(meta[i].word);
            assertTrue(name.length > 0, "authoring meta word name must not be empty");
            assertTrue(containsBytes(readme, name), string.concat("README must document word: ", string(name)));
        }
    }
}
