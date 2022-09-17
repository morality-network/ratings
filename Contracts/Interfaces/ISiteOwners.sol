// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "https://github.com/morality-network/ratings/Contracts/Models/Models.sol";

// Contract to confirm a site ownership from
interface ISiteOwners{
    
    /**
    * Get the owner for a site if exists
    */
    function getSiteOwner(string memory site) external view returns(Models.SiteOwner memory siteOwner);
}