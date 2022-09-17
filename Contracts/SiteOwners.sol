// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.12.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/morality-network/ratings/Contracts/Libraries/TimeUtils.sol";
import "https://github.com/morality-network/ratings/Contracts/Libraries/UrlUtils.sol";
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
    
    // The site owner list (history of all)
    Models.SiteOwner[] private _allSiteOwners;

    // The site owner request list (history of all)
    Models.SiteOwnerRequest[] private _allSiteOwnerRequests;

    // The list of all site owners 1:1 map
    mapping(string => uint256) private _siteOwnerIndexes; 

    // Site owner requests (not confirmed)
    mapping(bytes32 => uint256) private _currentSiteOwnerRequestIndexes; 

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

        Chainlink.Request memory request = buildChainlinkRequest(_jobId, address(this), this.fulfill.selector);

        // Set the URL to perform the GET request on
        request.add("get", string.concat(site, _extension));

        // Specify the path for retrieving the data
        request.add("path", "address");

        // Sends the request
        requestId = sendChainlinkRequestTo(_oracle, request, _fee);

        // Add to the total requests made
        _allSiteOwnerRequests.push(Models.SiteOwnerRequest(site, msg.sender, true, false));

        // Add the request
        _currentSiteOwnerRequestIndexes[requestId] = (_allSiteOwnerRequests.length -1); 

        emit SiteOwnerRequestAddedEvent(site, msg.sender, requestId, TimeUtils.getTimestamp());
        
        return requestId;
    }

    /**
    * Get the site owner
    */
    function getSiteOwner(string memory site) external override view returns(Models.SiteOwner memory siteOwner){
        // Get index of where the site owner is in the central list
        uint256 index = _siteOwnerIndexes[site];

        // Check to see if site owners exist
        if(_allSiteOwners.length == 0)
            return siteOwner;

        // Use index to get site owner
        siteOwner = _allSiteOwners[index];

        // Return it if sites match
        if(StringUtils.compareStrings(siteOwner.Site, site))
            return siteOwner;

        // Index was not matched
        siteOwner = Models.SiteOwner('',address(0),false); 
    }

    /**
    * Get the total site owner requests
    */
    function getTotalSiteOwnerRequests() public view returns(uint256){
        return _allSiteOwnerRequests.length;
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

     // Get a page of a sites owners - pageNumber starts from 0
    function getSiteOwnerRequests(uint256 pageNumber, uint256 perPage) public view returns(Models.SiteOwnerRequest[] memory siteOwners){
        // Validate page limit
        require(perPage <= _pageLimit, "Page limit exceeded");

        // Get the total amount remaining
        uint256 totalSiteOwnerRequests = getTotalSiteOwnerRequests();

        // Get the index to start from
        uint256 startingIndex = pageNumber * perPage;

        // The number of site owners that will be returned (to set array)
        uint256 remaining = totalSiteOwnerRequests - startingIndex;
        uint256 pageSize = ((startingIndex+1)>totalSiteOwnerRequests) ? 0 : (remaining < perPage) ? remaining : perPage;

        // Create the page
        Models.SiteOwnerRequest[] memory pageOfSiteOwners = new Models.SiteOwnerRequest[](pageSize);

        // Add each item to the page
        uint256 pageItemIndex = 0;
        for(uint256 i = startingIndex;i < (startingIndex + pageSize);i++){
           // Get the siteOwner
           Models.SiteOwnerRequest memory siteOwner = _allSiteOwnerRequests[i];

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
         emit ExtensionUpdatedEvent(newExtension, TimeUtils.getTimestamp());
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
         emit PageLimitUpdatedEvent(newPageLimit, TimeUtils.getTimestamp());
    }

    /**
    * Oracle Callback Function
    */
    function fulfill(bytes32 _requestId, address _owner) public recordChainlinkFulfillment (_requestId)
    {
        // Match the request
        uint256 index =  _currentSiteOwnerRequestIndexes[_requestId];
        Models.SiteOwnerRequest storage siteOwnerRequest = _allSiteOwnerRequests[index];

        // If owner taken from extension matches the request owner then owner can be set
        if(siteOwnerRequest.Exists && siteOwnerRequest.Owner == _owner){  
            // Get the site owner index of site    
            uint256 siteOwnerIndex = _addOrUpdateSiteOwner(siteOwnerRequest.Site, siteOwnerRequest.Owner);

            // Site owner is confirmed - added to site mapping
            _siteOwnerIndexes[siteOwnerRequest.Site] = siteOwnerIndex;

            // Confirm request
            siteOwnerRequest.Confirmed = true;

            // Fire event
            emit SiteOwnerAddedEvent(siteOwnerRequest.Site, _owner, _requestId, TimeUtils.getTimestamp());
        }
        else{
            // Deny request
            siteOwnerRequest.Confirmed = false;

            // Fire event
            emit SiteOwnerFailedEvent(_requestId, TimeUtils.getTimestamp());
        }
    }

    // Add or update an existing site owner
    function _addOrUpdateSiteOwner(string memory site, address owner) private returns(uint256){
        // Get index of where the site owner is in the central list
        uint256 index = _siteOwnerIndexes[site];

        // Check to see if site owners exist
        if(_allSiteOwners.length >= 0)
        {
            // Get site owner
            Models.SiteOwner storage siteOwner = _allSiteOwners[index];

            // Check site matches
            if(!StringUtils.compareStrings(siteOwner.Site, site)){
                // Update not create
                siteOwner.Owner = owner;

                return index;
            }
        }

        // Add to the total site owner
        _allSiteOwners.push(Models.SiteOwner(site, owner, true));

        return (_allSiteOwners.length -1);
    }
}