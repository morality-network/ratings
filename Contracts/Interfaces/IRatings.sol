// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// Contract to confirm user/site rating counts for payouts
interface IRatings{
    function getTotalUserRatings(address userAddress) external view returns(uint256 total);
    function getTotalSiteRatings(string memory site) external view returns(uint256 total);
}