// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0.0;

import "https://github.com/morality-network/ratings/Contracts/Libraries/StringUtils.sol";

library UrlUtils{

    function validateUrl(string memory url) public pure returns(bool){
        // ie. 'https://www.a.a' (15 in length)
        uint256 urlLength = bytes(url).length;
        require(urlLength >= 15, "Length of url must be minimum 15 characters ie. 'https://www.a.a'");
        
        // ie. 'https://www.a.a' -> MUST include 'https://www.'
        string memory firstSection = StringUtils.substring(url, 0, 12);
        require(StringUtils.compareStrings(firstSection, "https://www."), "Url must start with 'https://www.'");

        // ie. 'https://www.a.a/' -> Don't include '/' at end
        string memory lastCharacter = StringUtils.substring(url, urlLength-1, urlLength);
        require(StringUtils.compareStrings(lastCharacter, "/") == false, "Url must not end with '/'");

        return true;
    }
}
