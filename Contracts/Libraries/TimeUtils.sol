// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0.0;

library TimeUtils{

    function getTimestamp() public view returns(uint256){
        return block.timestamp;
    }
}