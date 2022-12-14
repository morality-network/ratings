// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.12.0;

library RatingUtils{

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function substring(string memory str, uint startIndex, uint endIndex) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
        }
        return string(result);
    }

    function getTimestamp() public view returns(uint256){
        return block.timestamp;
    }

    function validateUrl(string memory url) public pure returns(bool){
        // ie. 'https://www.a.a' (15 in length)
        uint256 urlLength = bytes(url).length;
        require(urlLength >= 15, "Length of url must be minimum 15 characters ie. 'https://www.a.a'");
        
        // ie. 'https://www.a.a' -> MUST include 'https://www.'
        string memory firstSection = substring(url, 0, 12);
        require(compareStrings(firstSection, "https://www."), "Url must start with 'https://www.'");

        // ie. 'https://www.a.a/' -> Don't include '/' at end
        string memory lastCharacter = substring(url, urlLength-1, urlLength);
        require(compareStrings(lastCharacter, "/") == false, "Url must not end with '/'");

        return true;
    }
}
