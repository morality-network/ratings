// Contract to confirm user/subject user rating counts for payouts
interface IUserRatings{

    // Get total subject user ratings 
    function getTotalSubjectUsersRatings(address subjectUser) external view returns(uint256 total);

    // Get a total user ratings 
    function getTotalUsersRatedsRatings(address userAddress) external view returns(uint256 total);
}