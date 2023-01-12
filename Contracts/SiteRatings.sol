// SPDX-License-Identifier: MIT
pragma solidity =0.8.12.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/morality-network/ratings/Contracts/Interfaces/ISiteRatings.sol";

/**
* @title Ratings
* @dev Persists and manages ratings across the internet
*/

contract SiteRatings is Ownable, ISiteRatings{

    struct Rating {
       address User;
       string Site;
       uint256 Field1;
       uint256 Field2;
       uint256 Field3;
       uint256 Field4;
       uint256 Field5;
       string Message;
       uint256 DateRated;
    }

    struct AggregateRating {
       string Site;
       uint256 Field1Total;
       uint256 Field2Total;
       uint256 Field3Total;
       uint256 Field4Total;
       uint256 Field5Total;
       uint256 Count;
    }

    struct Index {
        uint256 Position;
        bool Exists;
    }

    struct RatingDto{
       uint256 Field1;
       uint256 Field2;
       uint256 Field3;
       uint256 Field4;
       uint256 Field5;
       string Message;
    }

    struct RatingBound{
        uint256 Min;
        uint256 Max;
    }

    struct RatingDefinition{
       RatingBound Field1Bound;
       RatingBound Field2Bound;
       RatingBound Field3Bound;
       RatingBound Field4Bound;
       RatingBound Field5Bound;
    }

    // All sites total ratings
    AggregateRating[] private _allAggregateRatings;

    // Sites total ratings
    mapping(string => Index) private _siteAggregates;

    // All user/site ratings
    Rating[] private _allRatings;

    // Sites individual rating indexes
    mapping(string => uint256[]) private _siteRatingIndexes;
    mapping(string => uint256) private _siteRatingCounts;

    // Users individual rating indexes
    mapping(address => uint256[]) private _userRatingIndexes;
    mapping(address => uint256) private _userRatingCounts;

    // Index mapping for sites/users individual ratings
    mapping(address => mapping(string => Index)) private _userSiteRatingsIndex;

    // The max page limit
    uint256 private _pageLimit = 50;

    // Rating settings
    RatingDefinition _definition = RatingDefinition(
        RatingBound(0,5),
        RatingBound(0,5),
        RatingBound(0,5),
        RatingBound(0,5),
        RatingBound(0,5)
    );

    // Events
    event AddedRating(string indexed site, address indexed user, uint256 rating1, uint256 rating2, uint256 rating3, uint256 rating4, uint256 rating5, uint256 time);
    event EditedRating(string indexed site, address indexed user, uint256 newRating1, uint256 newRating2, uint256 newRating3, uint256 newRating4, uint256 newRating5, uint256 time);
    event PageLimitUpdatedEvent(uint256 indexed newPageLimit, uint256 time);
    event RatingDefinitionUpdatedEvent(address indexed user, uint256 time);

    // Add a new or replace and existing rating
    function addRating(string memory site, RatingDto memory rating) external {
        // Validate url 
        require(validateUrl(site));

        // Validate bounds
        validateBounds(rating);

        // We check if there is already an index for this site/user
        Index memory userSiteRatingIndex = _userSiteRatingsIndex[msg.sender][site];

        // Map to correct model
        Rating memory mappedRating = _mapRatingDto(site, rating);

        // If it already exists then edit the existing
        if(userSiteRatingIndex.Exists == true) 
            _editRating(site, mappedRating);

        // Otherwise add a new rating for site/user
        else _createRating(site, mappedRating);          
    }

    // Gets an aggregate rating for a site
    function getAggregateRating(string memory site) public view returns(AggregateRating memory aggregateRating){
        Index memory index = _siteAggregates[site];
        
        if(!index.Exists)
            return aggregateRating;

        aggregateRating = _allAggregateRatings[index.Position];
    }

    // Gets a single rating for a user-site
	function getRating(address user, string memory site) public view returns(Rating memory rating){
		// Get the index of the user/site rating
        Index memory userIndex = _userSiteRatingsIndex[user][site];
		
		require(userIndex.Exists, "No user-site rating exists");

        // Get the users existing rating for the site
        rating = _allRatings[userIndex.Position];

        return rating;
	}

    // Gets paged aggregate ratings for a site
    function getAggregateRatings(uint256 pageNumber, uint256 perPage) public view returns(AggregateRating[] memory aggregateRatings){
        // Validate page limit
        require(perPage <= _pageLimit, "Page limit exceeded");

        // Get the total amount remaining
        uint256 totalRatings = _allAggregateRatings.length;

        // Get the index to start from
        uint256 startingIndex = pageNumber * perPage;

        // The number of ratings that will be returned (to set array)
        uint256 remaining = totalRatings - startingIndex;
        uint256 pageSize = ((startingIndex+1)>totalRatings) ? 0 : (remaining < perPage) ? remaining : perPage;

        // Create the page
        AggregateRating[] memory pageOfRatings = new AggregateRating[](pageSize);

        // Add each item to the page
        uint256 pageItemIndex = 0;
        for(uint256 i = startingIndex;i < (startingIndex + pageSize);i++){
           
           // Get the rating 
           AggregateRating memory rating = _allAggregateRatings[i];

           // Add to page
           pageOfRatings[pageItemIndex] = rating;

           // Increment page item index
           pageItemIndex++;
        }

        return pageOfRatings;
    }

    // Get a page of users ratings 
    function getUserRatings(address userAddress, uint256 pageNumber, uint256 perPage) public view returns(Rating[] memory ratings){
        // Validate page limit
        require(perPage <= _pageLimit, "Page limit exceeded");

        // Get the total amount remaining
        uint256 totalRatings = _userRatingCounts[userAddress];

        // Get the index to start from
        uint256 startingIndex = pageNumber * perPage;

        // The number of ratings that will be returned (to set array)
        uint256 remaining = totalRatings - startingIndex;
        uint256 pageSize = ((startingIndex+1)>totalRatings) ? 0 : (remaining < perPage) ? remaining : perPage;

        // Create the page
        Rating[] memory pageOfRatings = new Rating[](pageSize);

        // Add each item to the page
        uint256 pageItemIndex = 0;
        for(uint256 i = startingIndex;i < (startingIndex + pageSize);i++){
           // Get the rating index
           uint256 index = _userRatingIndexes[userAddress][i];

           // Get the rating 
           Rating memory rating = _allRatings[index];

           // Add to page
           pageOfRatings[pageItemIndex] = rating;

           // Increment page item index
           pageItemIndex++;
        }

        return pageOfRatings;
    }

    // Get a page of a sites ratings - pageNumber starts from 0
    function getSiteRatings(string memory site, uint256 pageNumber, uint256 perPage) public view returns(Rating[] memory ratings){
        // Validate page limit
        require(perPage <= _pageLimit, "Page limit exceeded");

        // Get the total amount remaining
        uint256 totalRatings = _siteRatingCounts[site];

        // Get the index to start from
        uint256 startingIndex = pageNumber * perPage;

        // The number of ratings that will be returned (to set array)
        uint256 remaining = totalRatings - startingIndex;
        uint256 pageSize = ((startingIndex+1)>totalRatings) ? 0 : (remaining < perPage) ? remaining : perPage;

        // Create the page
        Rating[] memory pageOfRatings = new Rating[](pageSize);

        // Add each item to the page
        uint256 pageItemIndex = 0;
        for(uint256 i = startingIndex;i < (startingIndex + pageSize);i++){
           // Get the rating index
           uint256 index = _siteRatingIndexes[site][i];

           // Get the rating
           Rating memory rating = _allRatings[index];

           // Add to page
           pageOfRatings[pageItemIndex] = rating;

           // Increment page item index
           pageItemIndex++;
        }

        return pageOfRatings;
    }

    // Get a page ratings - pageNumber starts from 0
    function getRatings(uint256 pageNumber, uint256 perPage) public view returns(Rating[] memory ratings){
        // Validate page limit
        require(perPage <= _pageLimit, "Page limit exceeded");

        // Get the total amount remaining
        uint256 totalRatings = getTotalRatings();

        // Get the index to start from
        uint256 startingIndex = pageNumber * perPage;

        // The number of ratings that will be returned (to set array)
        uint256 remaining = totalRatings - startingIndex;
        uint256 pageSize = ((startingIndex+1)>totalRatings) ? 0 : (remaining < perPage) ? remaining : perPage;

        // Create the page
        Rating[] memory pageOfRatings = new Rating[](pageSize);

        // Add each item to the page
        uint256 pageItemIndex = 0;
        for(uint256 i = startingIndex;i < (startingIndex + pageSize);i++){
           // Get the rating
           Rating memory rating = _allRatings[i];

           // Add to page
           pageOfRatings[pageItemIndex] = rating;

           // Increment page item index
           pageItemIndex++;
        }

        return pageOfRatings;
    }

    // Get total sites ratings 
    function getTotalSiteRatings(string memory site) external override view returns(uint256 total){
        return _siteRatingCounts[site];
    }

    // Get a total user ratings 
    function getTotalUserRatings(address userAddress) external override view returns(uint256 total){
        return _userRatingCounts[userAddress];
    }

    // Get total ratings made
    function getTotalRatings() public view returns(uint256 total){
        return _allRatings.length;
    }

    // Get total aggregate ratings made
    function getTotalAggregateRatings() public view returns(uint256 total){
        return _allAggregateRatings.length;
    }

    /**
    * Get the page limit
    */
    function getPageLimit() public view returns(uint256 pageLimit){
        return _pageLimit;
    }

    /**
    * Validate rating field bounds
    */
    function validateBounds(RatingDto memory rating) public view returns(bool){
        require(rating.Field1 >= _definition.Field1Bound.Min, 'Field 1 is not within bounds (less than expected)');
        require(rating.Field1 <= _definition.Field1Bound.Max, 'Field 1 is not within bounds (more than expected');

        require(rating.Field2 >= _definition.Field2Bound.Min, 'Field 2 is not within bounds (less than expected)');
        require(rating.Field2 <= _definition.Field2Bound.Max, 'Field 2 is not within bounds (more than expected');

        require(rating.Field3 >= _definition.Field3Bound.Min, 'Field 3 is not within bounds (less than expected)');
        require(rating.Field3 <= _definition.Field3Bound.Max, 'Field 3 is not within bounds (more than expected');

        require(rating.Field4 >= _definition.Field4Bound.Min, 'Field 4 is not within bounds (less than expected)');
        require(rating.Field4 <= _definition.Field4Bound.Max, 'Field 4 is not within bounds (more than expected');

        require(rating.Field5 >= _definition.Field5Bound.Min, 'Field 5 is not within bounds (less than expected)');
        require(rating.Field5 <= _definition.Field5Bound.Max, 'Field 5 is not within bounds (more than expected)');

        return true;
    }

    /**
    * Set the page limit. Only owner can set
    */
    function setPageLimit(uint256 newPageLimit) public onlyOwner{
         // Update the extension
         _pageLimit = newPageLimit;

         // Fire update event
         emit PageLimitUpdatedEvent(newPageLimit, getTimestamp());
    }

    /**
    * Set the rating min/max values. Only owner can set
    */
    function setRatingDefinition(RatingDefinition memory definition) public onlyOwner{
        // Update the definition
        _definition = definition;

         // Fire update event
        emit RatingDefinitionUpdatedEvent(msg.sender, getTimestamp());
    }

    /**
    * Get the rating min/max values. Only owner can set
    */
    function getRatingDefinition() public view returns(RatingDefinition memory){
        return _definition;
    }

    // Helpers

    // Create a new rating for a site/user
    function _createRating(string memory site, Rating memory rating) private {
        // Update the total rating for the site
        _updateSiteAggregate(site, rating);

        // Save the rating
        _allRatings.push(rating);

       // Add to site rating indexes
       uint256[] storage siteRatingIndexes = _siteRatingIndexes[site];
       siteRatingIndexes.push(_allRatings.length-1);

       // Update the length of the ratings
       _siteRatingCounts[site] = siteRatingIndexes.length;

       // Add to user rating indexes
       uint256[] storage userRatings = _userRatingIndexes[msg.sender];
       userRatings.push(_allRatings.length-1);

       // Update the length of the ratings
       _userRatingCounts[msg.sender] = userRatings.length;

       // Add index
       Index memory userSiteIndex = Index(_allRatings.length-1, true);
       _userSiteRatingsIndex[msg.sender][site] = userSiteIndex;

       // Fire event
       emit AddedRating(site, msg.sender, rating.Field1, rating.Field2, rating.Field3, rating.Field4, rating.Field5, getTimestamp());
    }

    // Create a new rating for a site/user
    function _editRating(string memory site, Rating memory rating) private {
        // Get the index of the user/site rating
        Index memory userIndex = _userSiteRatingsIndex[msg.sender][site];

        // Get the users existing rating for the site
        uint256 oldRatingIndex = _userRatingIndexes[msg.sender][userIndex.Position];
        Rating storage oldRating = _allRatings[oldRatingIndex];

        // Remove old value
        _removeSiteAggregate(site, oldRating);

        // Update the total rating for the site
        _updateSiteAggregate(site, rating);

       // Update user rating
       oldRating.Field1 = rating.Field1;
       oldRating.Field2 = rating.Field2;
       oldRating.Field3 = rating.Field3;
       oldRating.Field4 = rating.Field4;
       oldRating.Field5 = rating.Field5;
       oldRating.Message = rating.Message;
       oldRating.DateRated = getTimestamp();

       // Fire event
       emit EditedRating(site, msg.sender, rating.Field1, rating.Field2, rating.Field3, rating.Field4, 
            rating.Field5, getTimestamp());
    }

    // Update the total ratings for a site
    function _updateSiteAggregate(string memory site, Rating memory rating) private{
        // Get index
        Index memory existingIndex = _siteAggregates[site];

        // Update if exists already
        if(existingIndex.Exists){
            // Get the aggregate to update
            AggregateRating storage aggregateRating = _allAggregateRatings[existingIndex.Position];

            // Update the aggregate with extra info
            aggregateRating.Site = site;
            aggregateRating.Field1Total += rating.Field1;
            aggregateRating.Field2Total += rating.Field2;
            aggregateRating.Field3Total += rating.Field3;
            aggregateRating.Field4Total += rating.Field4;
            aggregateRating.Field5Total += rating.Field5;

            // Up the answer count
            aggregateRating.Count += 1;
        }
        else{
            // Create the aggregate
            AggregateRating memory aggregateRating = AggregateRating(
                site, rating.Field1, rating.Field2, rating.Field3, rating.Field4, rating.Field5, 1);

            // Add to all
            _allAggregateRatings.push(aggregateRating);

            // Add to indexes
            Index memory index = Index(_allAggregateRatings.length-1, true);
            _siteAggregates[site] = index;
        }
    }

    // Update the total ratings for a site
    function _removeSiteAggregate(string memory site, Rating memory oldRating) private{
        // Get index
        Index memory index = _siteAggregates[site];
        require(index.Exists, "Index doesn't exist");

        // Get the aggregate to update
        AggregateRating storage aggregateRating = _allAggregateRatings[index.Position];

        aggregateRating.Field1Total -= oldRating.Field1;
        aggregateRating.Field2Total -= oldRating.Field2;
        aggregateRating.Field3Total -= oldRating.Field3;
        aggregateRating.Field4Total -= oldRating.Field4;
        aggregateRating.Field5Total -= oldRating.Field5;

        aggregateRating.Count -= 1;
    }

    // Map CreateRating to Rating
    function _mapRatingDto(string memory site, RatingDto memory createRating) private view returns(Rating memory rating){
         return Rating(
            msg.sender,
            site,
            createRating.Field1,
            createRating.Field2,
            createRating.Field3,
            createRating.Field4,
            createRating.Field5,
            createRating.Message,
            getTimestamp()
         );
    }

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
        // ie. 'https://test.com' (11 in length)
        uint256 urlLength = bytes(url).length;
        require(urlLength >= 11, "Length of url must be minimum 11 characters ie. 'https://test.com'");
        
        // ie. 'https://test.com' -> MUST include 'https://'
        string memory acceptedFirstSection = substring(url, 0, 8);
        require(compareStrings(acceptedFirstSection, "https://"), "Url must start with 'https://'");

        // ie. 'https://test.com' -> MUST include 'https://'
        string memory firstSection = substring(url, 0, 2);
        require(!compareStrings(firstSection, "https://www."), "Url must NOT start with 'https://www.'");

        // ie. 'https://test.com/' -> Don't include '/' at end
        string memory lastCharacter = substring(url, urlLength-1, urlLength);
        require(compareStrings(lastCharacter, "/") == false, "Url must not end with '/'");

        return true;
    }
}
