// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/morality-network/ratings/Contracts/Interfaces/IRatings.sol";
import "https://github.com/morality-network/ratings/Contracts/Interfaces/ISiteOwners.sol";

/**
 * @title Ratings
 * @dev Persists and manages ratings across the internet
 */

contract Collections is Ownable {
    // Supporting contract definitions
    IRatings _ratings;
    ISiteOwners _siteOwners;
    IERC20 _token;

    // Record of whats been paid out
    mapping(address => uint256) _userPayouts;
    mapping(string => uint256) _sitePayouts;

    // Multiplier for fee
    uint256 _multiplier = 1000000000; // 1 Gwei default

    // The contract events
    event UserPayout(address indexed user, uint256 indexed payoutAmount, uint256 indexed multiplier, uint256 time);
    event SitePayout(address indexed user, string indexed site, uint256 indexed payoutAmount, uint256 multiplier, uint256 time);
    event MultiplierUpdatedEvent(uint256 indexed newMultiplier, uint256 time);

    constructor(){
        // TODO sort out
        _ratings = IRatings(0x0000000000000000000000000000000000000000);
        _siteOwners = ISiteOwners(0x0000000000000000000000000000000000000000);
        _token = IERC20(0x0000000000000000000000000000000000000000);
    }

    //
    function lootUser() public{
        // Get the total ratings count for a user
        uint256 userRatingCount = _ratings.getTotalUserRatings(msg.sender);

        // Get the users paid out value
        uint256 paidOutValue = _userPayouts[msg.sender];
 
        // See if the user has already paid out
        require(paidOutValue >= userRatingCount, "Nothing to payout");

        // Find the amount to credit user
        uint256 payoutValue = getWhatsOwedToUser(msg.sender);

        // Add value to the user payouts
        _userPayouts[msg.sender] = userRatingCount;

        // Send the value to the user
        uint256 realizedPayoutValue = payoutValue * _multiplier;
        _token.transfer(address(this), realizedPayoutValue);

        // Emit event
        emit UserPayout(msg.sender, realizedPayoutValue, _multiplier, block.timestamp);
    }

    function lootSite(string memory site) public{
        // Check caller is owner
        address owner = _siteOwners.getSiteOwner(site);
        require(owner == msg.sender, "Only owner can loot site");

        // Get the total ratings count for a site
        uint256 siteRatingCount = _ratings.getTotalSiteRatings(site);

        // Get the sites paid out value
        uint256 paidOutValue = _sitePayouts[site];
    
        // See if the ite has already paid out
        require(paidOutValue >= siteRatingCount, "Nothing to payout");

        // Find the amount to credit site
        uint256 payoutValue = getWhatsOwedToSite(site);

        // Add value to the user payouts
        _sitePayouts[site] = siteRatingCount;

        // Send the value to the user
        uint256 realizedPayoutValue = payoutValue * _multiplier;
        _token.transfer(address(this), realizedPayoutValue);

        // Emit event
        emit SitePayout(msg.sender, site, realizedPayoutValue, _multiplier, block.timestamp);
    } 

    function getWhatsOwedToUser(address owner) public view returns(uint256){
         // Get the total ratings count for a user
        uint256 userRatingCount = _ratings.getTotalUserRatings(owner);

        // Get the users paid out value
        uint256 paidOutValue = _userPayouts[msg.sender];

        // Find the amount to credit user
        return userRatingCount - paidOutValue;
    }

    function getWhatsOwedToSite(string memory site) public view returns(uint256){
        // Get the total ratings count for a site 
        uint256 siteRatingCount = _ratings.getTotalSiteRatings(site);

        // Get the sites paid out value
        uint256 paidOutValue = _sitePayouts[site];

        // Find the amount to credit site
        return siteRatingCount - paidOutValue;
    }

    function getSitesLootedTotal(string memory site) public view returns(uint256){
        return _sitePayouts[site] * _multiplier;
    }

    function getUsersLootedTotal(address user) public view returns(uint256){
        return _userPayouts[user] * _multiplier;
    }

    /**
    * Get the multiplier
    */
    function getMultiplier() public view returns(uint256 multiplier){
        return _multiplier;
    }

    /**
    * Set the multiplier. Only owner can set
    */
    function setMultiplier(uint256 newMultiplier) public onlyOwner{
         // Update the multiplier
         _multiplier = newMultiplier;

         // Fire update event
         emit MultiplierUpdatedEvent(newMultiplier, block.timestamp);
    }

    // Recover tokens to the owner
    function recoverTokens(IERC20 token, uint256 amount) onlyOwner public {
        // Ensure there is a balance in this contract for the token specified
        require(token.balanceOf(address(this)) >= amount, "Not enough of token in contract, reduce the amount");

        // Transfer the tokens from the contract to the owner
        token.transfer(owner(), amount);
    }
}