// SPDX-License-Identifier: MIT
pragma solidity =0.8.12.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ProfileInformation is Ownable{

    struct AccountDetails{
        string ProfilePictureUrl;
        string FirstName;
        string LastName;
        string Alias;
        string Country;
        uint256 LastUpdated;
    }

    struct AccountDetailsDto{
        string ProfilePictureUrl;
        string FirstName;
        string LastName;
        string Alias;
        string Country;
    }

    struct Index{
        bool Exists;
        uint256 Position;
    }

    // Indexes of profile information 2 their index in the collection
    mapping(address => Index) private _accountDetailIndexes;

    // All the account details
    AccountDetails[] _accountDetails;

    // The max page limit
    uint256 private _pageLimit = 50;

    // Events
    event AccountDetailsAdded(address indexed user,string ProfilePictureUrl, string FirstName, string LastName, string indexed Alias, string Country, uint256 indexed time);
    event AccountDetailsEdited(address indexed user, string ProfilePictureUrl, string FirstName, string LastName, string indexed Alias, string Country, uint256 indexed time);
    event PageLimitUpdatedEvent(uint256 indexed newPageLimit, uint256 time);

    // Update the callers account details
    function updateAccountDetails(AccountDetailsDto memory details) public{
        // Try to get the users items index
        Index memory existingIndex =  _accountDetailIndexes[msg.sender];
        
        // If the index doesn't exist then we add
        if(!existingIndex.Exists)
        {
            // Add and add to new indexs
            _accountDetails.push(_mapAccountDetailsDto(details));
            _accountDetailIndexes[msg.sender] = Index(true, _accountDetails.length - 1);

            // Fire event
            emit AccountDetailsAdded(msg.sender, details.ProfilePictureUrl, details.FirstName, details.LastName, details.Alias, details.Country, getTimestamp());
        }
        // If the index already exists then we update
        else 
        {
            // Update value at index
            _accountDetails[existingIndex.Position] = _mapAccountDetailsDto(details);

            // Fire event
            emit AccountDetailsEdited(msg.sender, details.ProfilePictureUrl, details.FirstName, details.LastName, details.Alias, details.Country, getTimestamp());
        }
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

    function getAccountDetail(address user) public view returns(AccountDetails memory){
         // Try to get the users items index
        Index memory existingIndex =  _accountDetailIndexes[user];
        
        // Check exists
        require(existingIndex.Exists, 'Account details dont exist for specified user');

        // Return the account details
        return _accountDetails[existingIndex.Position];
    }

     function getUsersAccountDetail(address[] memory users) public view returns(AccountDetails[] memory){
         // Validate page limit
        require(users.length <= _pageLimit, "Page limit exceeded");

        // Create the page
        AccountDetails[] memory page = new AccountDetails[](users.length);

        for(uint256 i = 0;i<users.length;i++)
        {
            // Get the user
            address user = users[i];

            // Try to get the users items index
            Index memory existingIndex =  _accountDetailIndexes[user];
        
            // Check exists
            require(existingIndex.Exists, 'Account details dont exist for specified user');

            // Get the item at index
            AccountDetails memory accountDetail =_accountDetails[existingIndex.Position];

            // Add to page
            page[i] = accountDetail;
        }

        // Return the page of account details
        return page;
    }

    /**
    * Get the page limit
    */
    function getPageLimit() public view returns(uint256 pageLimit){
        return _pageLimit;
    }

    // Get total users account details created
    function getTotalUsersAccountDetails() public view returns(uint256 total){
        return _accountDetails.length;
    }

    function getAccountDetails(uint256 pageNumber, uint256 perPage) public view returns(AccountDetails[] memory accountDetails){
        // Validate page limit
        require(perPage <= _pageLimit, "Page limit exceeded");

        // Get the total amount remaining
        uint256 totalAccountDetails = getTotalUsersAccountDetails();

        // Get the index to start from
        uint256 startingIndex = pageNumber * perPage;

        // The number of account details that will be returned (to set array)
        uint256 remaining = totalAccountDetails - startingIndex;
        uint256 pageSize = ((startingIndex+1)>totalAccountDetails) ? 0 : (remaining < perPage) ? remaining : perPage;

        // Create the page
        AccountDetails[] memory pageOfRatings = new AccountDetails[](pageSize);

        // Add each item to the page
        uint256 pageItemIndex = 0;
        for(uint256 i = startingIndex;i < (startingIndex + pageSize);i++){
           // Get the account detail
           AccountDetails memory rating = _accountDetails[i];

           // Add to page
           pageOfRatings[pageItemIndex] = rating;

           // Increment page item index
           pageItemIndex++;
        }

        return pageOfRatings;
    }

    function _mapAccountDetailsDto(AccountDetailsDto memory accountDetailDto) private view returns(AccountDetails memory){
          return AccountDetails(
             accountDetailDto.ProfilePictureUrl,
             accountDetailDto.FirstName,
             accountDetailDto.LastName,
             accountDetailDto.Alias,
             accountDetailDto.Country,
             getTimestamp()
          );
    }

    function getTimestamp() public view returns(uint256){
        return block.timestamp;
    }
}