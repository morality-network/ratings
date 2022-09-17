// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// Contract to confirm a site ownership from
interface ISiteOwners{
    
    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data. ie. https://www.google.com -> 
     * GET https://www.google.com/owner-address { "address" : "0x0000000000000000000000000000000000000000" }
     */
    function verifyUrlOwner(string memory site) external returns (bytes32 requestId);

    /**
    * Get the site owner
    */
    function getSiteOwner(string memory site) external view returns(address);

    /**
    * Get the total registered site owners
    */
    function getTotalSiteOwners() external view returns(uint256);

    // Get a page of a sites owners - pageNumber starts from 0
    function getSiteOwners(uint256 pageNumber, uint256 perPage) external view returns(Models.SiteOwner[] memory siteOwners);

    /**
    * Get the site extension where { address:"" } needs to reside
    */
    function getExtension() external view returns(string memory);

    /**
    * Set the site extension where { address:"" } needs to reside. Only owner can set
    */
    function setExtension(string memory newExtension) external;

    /**
    * Get the page limit
    */
    function getPageLimit() external view returns(uint256 pageLimit);

    /**
    * Set the page limit. Only owner can set
    */
    function setPageLimit(uint256 newPageLimit) external;

    /**
    * Oracle Callback Function
    */
    function fulfill(bytes32 _requestId, address _owner) external recordChainlinkFulfillment (_requestId);
}