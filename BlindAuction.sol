pragma solidity ^0.8.0;
contract BlindAuction {
    struct Bid{
        bytes32 blindedBid;
        uint deposit;
    }
    
    address payable public beneficiary;
    uint public biddingEnd;
    uint public revealEnd;
    bool public ended;
    
    mapping (address => Bid[]) public bids;
    
    address public highestBidder;
    uint public highestBid;
    
    mapping (address => uint) pendingReturns;
    
    event AuctionEnded(address winner, uint highestBid);
    
    error TooEarly (uint time);
    error TooLate (uint time);
    error AuctionEndAlreadyCalled();
    
    modifier onlyBefore(uint _time){
        if (block.timestamp >= _time) revert TooLate(_time);
        _;
    }
    
    modifier onlyAfter(uint _time){
        if (block.timestamp <= _time) revert TooEarly(_time);
        _;
    }
    
    constructor(uint _biddingTime, uint _revealTime, address payable _beneficiary){
        beneficiary = _beneficiary;
        biddingEnd = block.timestamp + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
    }
    
    function bid (bytes32 _blindedBid) public payable onlyBefore( biddingEnd){
        bids[msg.sender].push(Bid({
            blindedBid: _blindedBid,
            deposit: msg.value
        }));
    }
    
    function reveal (uint[] memory _values, bool[] memory _fake, bytes32[] memory _secret) public onlyAfter(biddingEnd) onlyBefore(revealEnd){
        uint length = bids[msg.sender].length;
        require(_values.length == length);
        require(_fake.length == length);
        require(_secret.length == length);
        
        uint refund;
        for ( uint i = 0; i<length; i++){
            Bid storage bidToCheck = bids[msg.sender][i];
            (uint value, bool fake, bytes32 secret)= (_values[i], _fake[i], _secret[i]);
            
            if (bidToCheck.blindedBid != keccak256(abi.encodePacked(value, fake, secret)))
                continue;
            refund += bidToCheck.deposit;
            if (!fake && bidToCheck.deposit >= value){
                if (placeBid(msg.sender, value))
                    refund -= value;
            }
            bidToCheck.blindedBid = bytes32(0);
        }
        payable(msg.sender).transfer(refund);
    }
    
    function withdraw() public {
        uint amount = pendingReturns[msg.sender];
        if ( amount >0 ){
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        }
    }
    
    function auctionEnd() public onlyAfter(revealEnd){
        if (ended) revert AuctionEndAlreadyCalled();
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;
        beneficiary.transfer(highestBid);
    }
    
    function placeBid(address bidder, uint value) internal returns (bool success){
        if (value <= highestBid){
            return false;
        }
        if ( highestBidder != address(0)){
            pendingReturns[highestBidder] += highestBid;
        }
        highestBid = value;
        highestBidder = bidder;
        return true;
    }
    
}