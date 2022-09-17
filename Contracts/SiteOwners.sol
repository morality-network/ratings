// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';
import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/morality-network/ratings/Contracts/Libraries/Utils.sol";
import "https://github.com/morality-network/ratings/Contracts/Models/Models.sol";
import "https://github.com/morality-network/ratings/Contracts/Interfaces/ISiteOwners.sol";

/**
 * @title SiteOwners
 * @dev Manages site owners for the ratings contract
 */

contract SiteOwners is ChainlinkClient, Ownable, ISiteOwners {
    using Chainlink for Chainlink.Request;

    address private _oracle;
    bytes32 private _jobId;
    uint256 private _fee;

    // The list of all site owners 1:1 map
    mapping(string => address) private _siteOwners; 
    
    // The site owner list (history of all)
    Models.SiteOwner[] _allSiteOwners;

    // Site owner requests (not confirmed)
    mapping(address => Models.SiteOwner) private _siteOwnerRequests; 

    // The extension added to site to validate ownership (expose { "address" : "0x0000000000000000000000000000000000000000" }
    string private _extension = "/owner-address";

    // The link contract
    IERC20 private _link;
 
    // The max page size
    uint256 private _pageLimit = 50;

    event SiteOwnerAddedEvent(string indexed site, address indexed owner, bytes32 indexed requestId, uint256 time);
    event SiteOwnerRequestAddedEvent(string indexed site, address indexed owner, bytes32 indexed requestId, uint256 time);
    event SiteOwnerFailedEvent(bytes32 indexed requestId, uint256 time);
    event ExtensionUpdatedEvent(string indexed newExtension, uint256 time);
    event PageLimitUpdatedEvent(uint256 indexed newPageLimit, uint256 time);
    
    constructor() {
        setChainlinkToken(0x70d1F773A9f81C852087B77F6Ae6d3032B02D2AB);
        _oracle = 0x40193c8518BB267228Fc409a613bDbD8eC5a97b3;
        _jobId = "7d80a6386ef543a3abb52817f6707e3b";
        _link = IERC20(0x70d1F773A9f81C852087B77F6Ae6d3032B02D2AB);
        _fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data. ie. https://www.google.com -> 
     * GET https://www.google.com/owner-address { "address" : "0x0000000000000000000000000000000000000000" }
     */
    function verifyUrlOwner(string memory site) public returns (bytes32 requestId)
    {
        // Validate url 
        require(UrlUtils.validateUrl(site));

        // Get link to make transaction (user must have approved it first)
        _link.transferFrom(msg.sender, address(this), _fee);

        // Add the request
        _siteOwnerRequests[msg.sender] = Models.SiteOwner(site, msg.sender, true); 

        Chainlink.Request memory request = buildChainlinkRequest(_jobId, address(this), this.fulfill.selector);

        // Set the URL to perform the GET request on
        request.add("get", site);

        // Specify the path for retrieving the data
        request.add("path", "address");

        // Sends the request
        requestId = sendChainlinkRequestTo(_oracle, request, _fee);

        emit SiteOwnerRequestAddedEvent(site, msg.sender, requestId, block.timestamp);
        
        return requestId;
    }

    /**
    * Get the site owner
    */
    function getSiteOwner(string memory site) external override view returns(address){
        return _siteOwners[site];
    }

    /**
    * Get the total registered site owners
    */
    function getTotalSiteOwners() public view returns(uint256){
        return _allSiteOwners.length;
    }

    // Get a page of a sites owners - pageNumber starts from 0
    function getSiteOwners(uint256 pageNumber, uint256 perPage) public view returns(Models.SiteOwner[] memory siteOwners){
        // Validate page limit
        require(perPage <= _pageLimit, "Page limit exceeded");

        // Get the total amount remaining
        uint256 totalSiteOwners = getTotalSiteOwners();

        // Get the index to start from
        uint256 startingIndex = pageNumber * perPage;

        // The number of site owners that will be returned (to set array)
        uint256 remaining = totalSiteOwners - startingIndex;
        uint256 pageSize = ((startingIndex+1)>totalSiteOwners) ? 0 : (remaining < perPage) ? remaining : perPage;

        // Create the page
        Models.SiteOwner[] memory pageOfSiteOwners = new Models.SiteOwner[](pageSize);

        // Add each item to the page
        uint256 pageItemIndex = 0;
        for(uint256 i = startingIndex;i < (startingIndex + pageSize);i++){
           // Get the siteOwner
           Models.SiteOwner memory siteOwner = _allSiteOwners[i];

           // Add to page
           pageOfSiteOwners[pageItemIndex] = siteOwner;

           // Increment page item index
           pageItemIndex++;
        }

        return pageOfSiteOwners;
    }

    /**
    * Get the site extension where { address:"" } needs to reside
    */
    function getExtension() public view returns(string memory){
        return _extension;
    }

    /**
    * Set the site extension where { address:"" } needs to reside. Only owner can set
    */
    function setExtension(string memory newExtension) public onlyOwner{
         // Update the extension
         _extension = newExtension;

         // Fire update event
         emit ExtensionUpdatedEvent(newExtension, block.timestamp);
    }

    /**
    * Get the page limit
    */
    function getPageLimit() public view returns(uint256 pageLimit){
        return _pageLimit;
    }

    /**
    * Set the page limit. Only owner can set
    */
    function setPageLimit(uint256 newPageLimit) public onlyOwner{
         // Update the extension
         _pageLimit = newPageLimit;

         // Fire update event
         emit PageLimitUpdatedEvent(newPageLimit, block.timestamp);
    }

    /**
    * Oracle Callback Function
    */
    function fulfill(bytes32 _requestId, address _owner) public recordChainlinkFulfillment (_requestId)
    {
        Models.SiteOwner memory siteOwnerRequest = _siteOwnerRequests[_owner];
        if(siteOwnerRequest.Exists && siteOwnerRequest.Owner == _owner){
            _siteOwners[siteOwnerRequest.Site] = _owner;
    
            emit SiteOwnerAddedEvent(siteOwnerRequest.Site, _owner, _requestId, block.timestamp);
        }
        else{
            emit SiteOwnerFailedEvent(_requestId, block.timestamp);
        }
    }
}