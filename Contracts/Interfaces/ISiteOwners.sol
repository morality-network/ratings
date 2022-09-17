// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// Contract to confirm a site ownership from
interface ISiteOwners{
    function getSiteOwner(string memory site) external view returns(address);
}