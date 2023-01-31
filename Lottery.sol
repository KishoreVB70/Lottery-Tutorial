// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "witnet-solidity-bridge/contracts/interfaces/IWitnetRandomness.sol";

contract Lottery {
    //Address of the witnet randomness contract in Celo Alfajores testnet
    address witnetAddress = 0xbD804467270bCD832b4948242453CA66972860F5;
    IWitnetRandomness public witnet = IWitnetRandomness(witnetAddress);

    // The price to enter the lottery
    uint256 public entryAmount;

    uint256 public lastWinnerAmount;
    uint256 public lotteryId;
    uint256 public latestRandomizingBlock;

    address payable public lastWinner;
    address[] public players;
    address public owner;

    bool public open;

    constructor () {
        owner = msg.sender;
    } 
  
    modifier onlyOwner{
        require(msg.sender == owner, "not owner");
        _;
    }

    //Checks if there is a current active lottery
    modifier onlyIfOpen{
        require(open, "Not Open");
        _;
    }

    event Started(uint lotteryId, uint entryAmount);
    event Ended(uint lotteryId, uint winningAmount, address winner);

    error reEntry();

    function start(uint32 _entryAmount) external onlyOwner{
        //Check if there is a current active lottery
        require(!open, "running");

        // Convert the default wei input to celo
        entryAmount = _entryAmount * 1 ether;

        open = true;

        // Deleting the previous arrays of players
        delete players;

        emit Started(lotteryId, _entryAmount);
        lotteryId++;
    }

    function join() external payable onlyIfOpen{
        require(msg.value == entryAmount, "Insufficient Funds");

        //Check if user is already a player
        for(uint i=0; i < players.length; i++){
            if (msg.sender == players[i]){
                revert reEntry();
            }
        }
        players.push(msg.sender);
    }
    
    function requestRandomness() external onlyOwner onlyIfOpen{
        latestRandomizingBlock = block.number;

        //Setting the fee to 1 celo
        uint feeValue = 1 ether;
        witnet.randomize{ value: feeValue }();
    }

    function pickWinner() external onlyOwner onlyIfOpen{
        // Check if the requestRandomness was called to generate the randomness
        assert(latestRandomizingBlock > 0);

        uint32 range = uint32(players.length);
        uint winnerIndex = witnet.random(range, 0, latestRandomizingBlock);

        lastWinner = payable(players[winnerIndex]);
        lastWinnerAmount = address(this).balance;

        (bool sent,) = lastWinner.call{value: lastWinnerAmount}("");
        require(sent, "Failed to send reward");

        open = false;
        latestRandomizingBlock = 0;
        emit Ended(lotteryId, lastWinnerAmount, lastWinner);
    }

    receive () external payable {}
}