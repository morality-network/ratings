// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// Contract to confirm user/site rating counts for payouts
interface IRatings{
     // Add a new or replace and existing rating
    function addRating(string memory site, Models.RatingDto memory rating) external;

    // Gets an aggregate rating for a site
    function GetRating(string memory site) external view returns(Models.AggregateRating memory aggregateRating);

    // Get a page of users ratings 
    function getUserRatings(address userAddress, uint256 pageNumber, uint256 perPage) external view returns(Models.Rating[] memory ratings);

    // Get a page of a sites ratings - pageNumber starts from 0
    function getSiteRatings(string memory site, uint256 pageNumber, uint256 perPage) external view returns(Models.Rating[] memory ratings);

    // Get a page ratings - pageNumber starts from 0
    function getRatings(uint256 pageNumber, uint256 perPage) external view returns(Models.Rating[] memory ratings);

    // Get total sites ratings 
    function getTotalSiteRatings(string memory site) external view returns(uint256 total);

    // Get a total user ratings 
    function getTotalUserRatings(address userAddress) external view returns(uint256 total);

    // Get total ratings made
    function getTotalRatings() external view returns(uint256 total);

    /**
    * Get the page limit
    */
    function getPageLimit() external view returns(uint256 pageLimit);

    /**
    * Set the page limit. Only owner can set
    */
    function setPageLimit(uint256 newPageLimit) external;
}