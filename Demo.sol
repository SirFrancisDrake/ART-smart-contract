
pragma solidity ^0.4.15;


    // This is a simplified version of some of the key functions 
    // for demonstrative purposes. Top-level function comments are omitted,
    // array handling that avoids running out of gas errors is also omitted
    
contract DemoFragments {
    event VoteCast(bytes32 _contentID, bool _vote);
    event VoteResolved(bytes32 _contentID, bool _VoteResultedInDeletion);
    event ReportRegistered(bytes32 _contentID);
    
    uint constant public MIN_REPORTS_TO_INIT_VOTING = 10; 
    uint constant public MODERATION_VOTING_TIME = 10 days;
    
    struct Account {
        // this is a stub
        uint rating;
        uint upvotes;
        bool isValue;
    }
    
    mapping (address => Account) accounts;
    
  	struct Content {
		address author;
		address owner;
		bool isValue;
		address[] moderationReporters;
		uint totalReports;
    }
    
    mapping (bytes32 => Content) content;

    struct LicensePurchase {
        mapping (string => bool) coversTerritory;
        bool isLifetime;
        uint expirationDate;
        bool isValue;
        bool grantsSublicensingRights;
        bool permitsCommercialUse;
    }

    // for each contentID -> and each address -> store current purchased license
    mapping (bytes32 => mapping (address => LicensePurchase)) licensePurchases;
    
    struct FreePeriod {
        uint startingDate;
        uint endingDate;
        bool isValue;
    }
    
    // for each contentID -> is a free period active, starting date, ending date
    mapping (bytes32 => FreePeriod) freePeriods;
    // **********************
    // ************************************* 
    // WP page 34, content availability "are regulated by the smart contract that 
    //                                                grants acess to the content"
    // *************************************
    // **********************
    function hasPermissionToGetContent(bytes32 _contentID) public view 
                                            returns (bool _hasPermission) {
        _hasPermission = false;
        
        bool allowedByLicense = false;
        if (licensePurchases[_contentID][msg.sender].isValue) {
            allowedByLicense = 
                (licensePurchases[_contentID][msg.sender].isLifetime) ||
                (licensePurchases[_contentID][msg.sender].expirationDate > now);
        }
        
        bool freePeriodApplies = false;
        if (freePeriods[_contentID].isValue) {
            freePeriodApplies =
                (freePeriods[_contentID].startingDate < now) &&
                (now < freePeriods[_contentID].endingDate);
        }
        
        _hasPermission = 
            (content[_contentID].owner == msg.sender)  || 
            allowedByLicense ||
            freePeriodApplies;
    }
    
    // **********************
    // ************************************* 
    // WP page 39, content moderation "content maker's royalty lies between 85-95%"
    // *************************************
    // **********************
    function punishForInappropriateContent(address _author) internal {
        // Decrease rating, but not below the threshold of 85% royalties
        accounts[_author].rating = max(accounts[_author].rating - 100, 8500);
    }
    
    function punishForUnsuccessfulModerationReport(address _reporter) internal {
        // Decrease rating, but not below the threshold of 85% royalties
        accounts[_reporter].rating = max(accounts[_reporter].rating - 10, 8500);
    }
    
    function rewardForSuccessfulModerationReport(address _reporter) internal {
        // Increase rating, but not above the threshold of 95% royalties
        accounts[_reporter].rating = min(accounts[_reporter].rating + 10, 9500);
    }
 
     // **********************
    // ************************************* 
    // WP page 43, content moderation "relies on users who sent complaints"
    // *************************************
    // **********************
    struct ContentDeletionVote {
        bool hasVoted;
        bool votedToDelete;
    }
    
    struct ContentDeletionVoteBooth {
        // The number of potential voters is small, so arrays can be used
        // safely, without the risk of running out of gas
        address[] assignedModerators;
        mapping (address => ContentDeletionVote) castVotes;
        uint totalVotesCast;
        uint startingDate;
        uint expirationDate;
        bool resolved;
        bool isValue;
    }
    
    mapping (bytes32 => ContentDeletionVoteBooth) contentDeletionVotes;
    
    function maybeAdvanceContentReporting(bytes32 _contentID) internal {
        uint authorsRating = accounts[content[_contentID].author].rating;
        uint threshold = MIN_REPORTS_TO_INIT_VOTING + (authorsRating^2) / 10000;
        if (content[_contentID].totalReports >= threshold) {
            // Check that the moderation voting hasn't been launched already
            require(!contentDeletionVotes[_contentID].isValue);
            // Launch voting
            contentDeletionVotes[_contentID].startingDate = now;
            contentDeletionVotes[_contentID].expirationDate = now + MODERATION_VOTING_TIME;
            contentDeletionVotes[_contentID].isValue = true;
            assignRandomModeratorsForContentRemoval(_contentID);
        }
    }
    
    // **********************
    // ************************************* 
    // WP page 43, content moderation "The second step involves a small number of moderators"
    // *************************************
    // **********************
    function voteForContentDeletion(bytes32 _contentID, bool _vote) public {
        require(contentDeletionVotes[_contentID].isValue);
        // Make sure the voting period hasn't ended
        require(contentDeletionVotes[_contentID].expirationDate > now);
        // Make sure the voter has been selected for this particular vote
        require(isInAddressArray(msg.sender, 
                          contentDeletionVotes[_contentID].assignedModerators));
        // Make sure the voter hasn't already voted
        require(!contentDeletionVotes[_contentID].castVotes[msg.sender].hasVoted);
        
        contentDeletionVotes[_contentID].castVotes[msg.sender].hasVoted = true;
        contentDeletionVotes[_contentID].castVotes[msg.sender].votedToDelete = _vote;
        contentDeletionVotes[_contentID].totalVotesCast += 1;
        
        VoteCast(_contentID, _vote);
    }
    
    function punishModeratorForIdling(address _moderator) internal {
        // Decrease rating, but not below the threshold of 85% royalties
        accounts[_moderator].rating = max(accounts[_moderator].rating - 30, 8500);
    }

   function resolveContentDeletionVote(bytes32 _contentID) internal {
        require(contentDeletionVotes[_contentID].isValue);
        // Make sure the vote hasn't already been resolved
        require(!contentDeletionVotes[_contentID].resolved);
        // Voting can only be resolved when every vote is cast or it has expired
        require((contentDeletionVotes[_contentID].assignedModerators.length == 
                 contentDeletionVotes[_contentID].totalVotesCast) ||
                (now > contentDeletionVotes[_contentID].expirationDate));
        
        uint votesToDelete = 0;
        uint votesToKeep = 0;
        address _moderator;        
        for (uint i=0; i<contentDeletionVotes[_contentID].assignedModerators.length;  i++) {
            _moderator = contentDeletionVotes[_contentID].assignedModerators[i];
            // If the moderator has voted, count the vote
            if (contentDeletionVotes[_contentID].castVotes[_moderator].hasVoted) {
                if (contentDeletionVotes[_contentID].castVotes[_moderator].votedToDelete)
                    votesToDelete += 1;
                else votesToKeep += 1;
            // Otherwise punish the moderator for skipping on a vote
            } else punishModeratorForIdling(_moderator);
        }
        
        bool voteResultedInDeletion = votesToDelete > votesToKeep;
        if (voteResultedInDeletion) {
            punishForInappropriateContent(content[_contentID].author);
            removeContent(_contentID);
            rewardReporters(_contentID);
        } else {
            punishReporters(_contentID);
            clearReportersList(_contentID);
        }

        contentDeletionVotes[_contentID].resolved = true;
        VoteResolved(_contentID, voteResultedInDeletion);
    }
    
        
    // **********************
    // ************************************* 
    // Don't publish this and anything below
    // *************************************
    // **********************


    function max(uint _a, uint _b) internal returns (uint result) {
        if (_a > _b) result = _a;
        else result = _b;
    }

    function min(uint _a, uint _b) internal returns (uint result) {
        if (_a < _b) result = _a;
        else result = _b;
    }
    
    function isInAddressArray(address item, address[] _arr) internal returns (bool result) {
        return false;
    }
    
    function removeContent(bytes32 _contentID) internal {
        
    }
    
    function rewardReporters(bytes32 _contentID) internal {
        
    }

    function punishReporters(bytes32 _contentID) internal {
        
    }
    
    function clearReportersList(bytes32 _contentID) internal {
        
    }
    
    function assignRandomModeratorsForContentRemoval(bytes32 _contentID) internal {
    }
}