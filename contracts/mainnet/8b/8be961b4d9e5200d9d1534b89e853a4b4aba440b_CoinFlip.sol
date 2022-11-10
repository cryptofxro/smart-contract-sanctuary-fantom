/**
 *Submitted for verification at FtmScan.com on 2022-11-10
*/

pragma solidity ^0.4.0;

contract CoinFlip {
    address owner;
    uint payPercentage = 90;

	// Maximum amount to bet in WEIs
	uint public MaxAmountToBet = 2000000000000000000; // = 2 Ether

	struct Game {
		address addr;
		uint blocknumber;
		uint blocktimestamp;
        uint bet;
		uint prize;
        bool winner;
    }

	Game[] lastPlayedGames;

	Game newGame;

    event Status(
		string _msg, 
		address user,
		uint amount,
		bool winner
	);

    function CoinFlipper() payable {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert();
        } else {
            _;
        }
    }

    function Play() payable {

		if (msg.value > MaxAmountToBet) {
			revert();
		} else {
			if ((block.timestamp % 2) == 0) {

				if (this.balance < (msg.value * ((100 + payPercentage) / 100))) {
					
					msg.sender.transfer(this.balance);
					Status('Congratulations, you win! Sorry, we didn\'t have enought FTM, we will deposit again soon!', msg.sender, msg.value, true);

					newGame = Game({
						addr: msg.sender,
						blocknumber: block.number,
						blocktimestamp: block.timestamp,
						bet: msg.value,
						prize: this.balance,
						winner: true
					});
					lastPlayedGames.push(newGame);

				} else {
					uint _prize = msg.value * (100 + payPercentage) / 100;
					Status('Congratulations, you win!', msg.sender, _prize, true);
					msg.sender.transfer(_prize);

					newGame = Game({
						addr: msg.sender,
						blocknumber: block.number,
						blocktimestamp: block.timestamp,
						bet: msg.value,
						prize: _prize,
						winner: true
					});
					lastPlayedGames.push(newGame);

				}
			} else {
				Status('Sorry, you loose!', msg.sender, msg.value, false);

				newGame = Game({
					addr: msg.sender,
					blocknumber: block.number,
					blocktimestamp: block.timestamp,
					bet: msg.value,
					prize: 0,
					winner: false
				});
				lastPlayedGames.push(newGame);

			}
		}
    }

	function getGameCount() public constant returns(uint) {
		return lastPlayedGames.length;
	}

	function getGameEntry(uint index) public constant returns(address addr, uint blocknumber, uint blocktimestamp, uint bet, uint prize, bool winner) {
		return (lastPlayedGames[index].addr, lastPlayedGames[index].blocknumber, lastPlayedGames[index].blocktimestamp, lastPlayedGames[index].bet, lastPlayedGames[index].prize, lastPlayedGames[index].winner);
	}


	function depositFunds(uint amount) onlyOwner payable {
        if (owner.send(amount)) {
            Status('User has deposit some money!', msg.sender, msg.value, true);
        }
    }

	function withdrawFunds(uint amount) onlyOwner {
        if (owner.send(amount)) {
            Status('User withdraw some money!', msg.sender, amount, true);
        }
    }

	function setMaxAmountToBet(uint amount) onlyOwner returns (uint) {
		MaxAmountToBet = amount;
        return MaxAmountToBet;
    }

	function getMaxAmountToBet(uint amount) constant returns (uint) {
        return MaxAmountToBet;
    }

}