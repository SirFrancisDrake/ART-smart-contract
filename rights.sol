pragma solidity ^0.4.11;

// FIXME: abstract representation of the token contract to interact with
contract TokenContract {
    function transferFrom(address _from, address _to, uint _value) returns (bool success);
}

contract Rights {

	struct Content {
		address author;
		address owner;
		address[] soldTo; // Accounts
		address[] reportedBy; // Accounts
		address[] upvotedBy; // Accounts
		uint price;
		uint flags; // licence type
		bool reportAvailable;
		bool isValue;
	}

	mapping(address => Account) public accounts;

    address public KOSTA; // address of main admin (Kosta Popov)
	address public ARVRFund;
    address public TokenContractAddress;

    function transferMoney(address _from, address _to, uint _value) returns (bool success) {
        // instantiate the abstract representation with the pre-deployed contract, by address
        TokenContract tokenContract = TokenContract(TokenContractAddress);
        
        return transferFrom(_from, _to, _value);
    }

	function Rights() { KOSTA = msg.sender; }

	function setArvrFund(address fund) {
	    require(KOSTA == msg.sender);
	    ARVRFund = fund;
	}

	// hash_of_the_content => Content struct
	mapping(bytes32 => Content) content;

    const uint initialRating = 9000;

    /* ACCOUNT */
	struct Account {
		uint rating;
		uint upvotes;
		bool isValue;
	}

	/* register new account */
	function registerAccount() {
		require(accounts[msg.sender].isValue == false);
		accounts[msg.sender] = Account({
			rating_sold: initialRating, // %%
			upvotes: 0,
			isValue: true
		});
	}

    // FIXME: why do we need this, is it how it's done?
    /* check if an address is in a list of addresses */
	function isIn(address a, address[] m) constant returns (bool) {
	    for (uint i = 0; i < m.length; i++)
			if (a == m[i]) return true;
	    return false;
	}

    // FIXME: why do we need this, is it how it's done?
    /* check if an byte-sequence is in a list of byte-sequences */
	function isInBytes32(bytes32 a, bytes32[]m) constant returns (bool) {
		for (uint i = 0; i < m.length; i++)
			if (a == m[i]) return true;
		return false;
	}

	/* add content with flags and price */
	function addNewContent(bytes32 id, uint price, uint flags) {
		require(content[id].isValue == false); // no content with that id
		require(price >= 0);

		content[id].author = msg.sender;
		content[id].owner = msg.sender;
		content[id].price = price;
		content[id].flags = flags;
		content[id].reportAvailable = true;
		content[id].isValue = true;
	}

	/* buy content with contentId */
	function buyContent(bytes32 id) { // id is contentId: content hash value
		Content storage c = content[id];
		// if id.flags don't allow to buy it: throw;
		require(c.owner != msg.sender);

        // FIXME: check implementation: if list, potentially long computation
        // also: what to do with licenses limited in time?
		require(!isIn(msg.sender, c.soldTo));
		require(accounts[msg.sender].checkBalance >= c.price);

        // TODO: implement cashback
        if (transferMoney(accounts[msg.sender], accounts[c.owner], c.price))
            {
            // FIXME: check implementation as above
            c.soldTo.push(msg.sender);
            return true;
            }

        return false;

    function deleteContent(bytes32 id) {
		content[id].author = 0;
		content[id].owner  = 0;
		content[id].price  = 0;
		content[id].flags  = 0;
		content[id].reportAvailable = false;
		content[id].isValue = false;
	}

	function transferOwnership(bytes32 contentId, address newOwner) {
	    require(msg.sender == content[contentId].owner);
	    content[contentId].owner = newOwner;
	}

    function changeFlags(bytes32 contentId, uint newFlags) {
        require(msg.sender == content[contentId].owner);
        content[contentId].flags = newFlags;
    }

    function changePrice(bytes32 contentId, uint newPrice) {
        require(msg.sender == content[contentId].owner);
        content[contentId].price = newPrice;
    }

    function checkRights(address user, bytes32 contentId) returns (bool) {
        if (content[contentId].owner == user) return true;
        if (isIn(user, content[contentId].soldTo)) return true;
        return false;
    }

	/* ----- ---------- ----- */
	/* ----- moderation ----- */
	/* ----- ---------- ----- */

	address[] public moderators;      // users who have moderation privileges
	bytes32[] public idsToModerate; // contentIds that should be moderated

	function max(uint a, uint b) constant returns (uint) {
		if (a > b) return a;
		return b;
	}

	function min(uint a, uint b) constant returns (uint) {
		if (a < b) return a;
		return b;
	}

	/* upvote contentId */
	function upvote(bytes32 id) {
		Content storage c = content[id];
		address user = msg.sender;
		require(!isIn(user, c.upvoted));
		c.upvoted.push(user);
		accounts[c.author].upvotes += 1;
	}

	/* report contentId*/
	function report(bytes32 id) { // TODO: add report type argument
		Content storage c = content[id];
		address user = msg.sender;
        // FIXME-reportAvailable: why do we need this?
		require(c.reportAvailable == true);
		require(!isIn(user, c.reported));
		c.reported.push(user);
        // FIXME check formula
		if (c.reported.length > 10 + (accounts[c.author].upvotes) ** 2 / 10000) { // dont know if it would work
            // FIXME-reportAvailable: why do we need this?
			c.reportAvailable = false;
			idsToModerate.push(id);
		}
	}

	/* moderators-only function to decide: delete content or not delete */
	function moderate(bytes32 id, bool vote) {
		uint i = 0;
		Content storage c = content[id];
		address user = msg.sender;
		require( isInbytes32(id,idsToModerate) ); // python syntax
		require( isIn(user, moderators) );
		if (vote) {
			// pay reporters
			for (i = 0; i < c.reported.length; i++) {
				accounts[c.reported[i]].rating_sold = min(accounts[c.reported[i]].rating_sold + 1, 9500);
				accounts[c.reported[i]].cashback = min(accounts[c.reported[i]].cashback + 10, 500);
			}
			// delete content
            deleteContent(c);
		} else {
			// punish reporters
			for (i = 0; i < c.reported.length; i++) {
				accounts[c.reported[i]].rating_sold = max(accounts[c.reported[i]].rating_sold - 10, 8500);
				accounts[c.reported[i]].cashback = max(accounts[c.reported[i]].cashback - 20, 0);
			}
		}
	}

	/* admin's method to add moderator */
	function addModerator(address addr) {
		require(msg.sender == KOSTA);
		if (!isIn(addr, moderators))
			moderators.push(addr); // python syntax
	}

	/* admin's method to delete moderator */
	function delModerator(address addr) {
		require(msg.sender == KOSTA);
		for (uint i = 0; i < moderators.length; i++) {
				if (moderators[i] == addr) delete(moderators[i]);
		}
	}
}
