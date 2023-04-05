/**
 *Submitted for verification at FtmScan.com on 2023-04-02
*/

// Sources flattened with hardhat v2.13.0 https://hardhat.org

// File contracts/firefundfantom.sol

pragma solidity ^0.8.13;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size; assembly {
            size := extcodesize(account)
        } return size > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(address target,bytes memory data,string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(address target,bytes memory data,uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(address target,bytes memory data,uint256 value,string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(address target,bytes memory data,string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(address target,bytes memory data,string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function verifyCallResult(bool success,bytes memory returndata,string memory errorMessage) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
library SafeERC20 {
    using Address for address;
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function safeIncreaseAllowance(IERC20 token,address spender,uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }
    function safeDecreaseAllowance(IERC20 token,address spender,uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }
    function _callOptionalReturn(IERC20 token, bytes memory data) private {   
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }
}
//libraries
struct User {
    uint256 startDate;
    uint256 divs;
    uint256 refBonus;
    uint256 totalInits;
    uint256 totalWiths;
    uint256 totalAccrued;
    uint256 lastWith;
    uint256 timesCmpd;
    uint256 keyCounter;
    Depo [] depoList;
}

struct Depo {
    uint256 key;
    uint256 depoTime;
    uint256 amt;
    address reffy;
    bool initialWithdrawn;
}
struct Main {
    uint256 ovrTotalDeps;
    uint256 ovrTotalWiths;
    uint256 users;
    uint256 compounds;
    uint256 ovrTotalStaked;
}
struct DivPercs{
    uint256 daysInSeconds; // updated to be in seconds
    uint256 divsPercentage;
}
struct FeesPercs{
    uint256 daysInSeconds;
    uint256 feePercentage;
}

contract FireFundBinance{
    using SafeMath for uint256;
    uint256 constant launch = 1669989600;

    uint256 constant hardDays = 86400;
    uint256 constant percentdiv = 1000;
    uint256 refPercentage = 20;
    uint256 devPercentage = 50;
    mapping (address => mapping(uint256 => Depo)) public DeposMap;
    mapping (address => User) public UsersKey;
    mapping (uint256 => DivPercs) public PercsKey;
    mapping (uint256 => FeesPercs) public FeesKey;
    mapping (uint256 => Main) public MainKey;
    uint256 public devLastWithdrawal;
    using SafeERC20 for IERC20;
    IERC20 public USDC;
    address public owner;

    constructor() {
        owner = msg.sender;
        PercsKey[10] = DivPercs(864000, 10);  /* 10 days */
        PercsKey[20] = DivPercs(1728000, 20); /* 20 days */
        PercsKey[30] = DivPercs(2592000, 30); /* 30 days */
        PercsKey[40] = DivPercs(3456000, 40); /* 40 days */
        PercsKey[50] = DivPercs(4320000, 50); /* 50 days */
        PercsKey[15] = DivPercs(4320000, 15); /* 15 percent This is wrong */
        PercsKey[12] = DivPercs(1036800, 12); /* 12 percent */
        PercsKey[31] = DivPercs(2592000, 30); /* 30 percent */

        FeesKey[10] = FeesPercs(864000, 100); /* 10 days */
        FeesKey[20] = FeesPercs(1728000, 80); /* 20 days */
        FeesKey[30] = FeesPercs(2592000, 60); /* 40 days */
        FeesKey[40] = FeesPercs(3456000, 40); /* 40 days */
        FeesKey[50] = FeesPercs(4320000, 20); /* 50 days */

        devLastWithdrawal = launch;
       
        USDC = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
        // Mainnet BUSD : 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
        // Testnet BUSD : 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee
    }

    function compoundDividends() public {
        User storage user = UsersKey[msg.sender];
        Main storage main = MainKey[1];
        uint256 x = calcdiv(msg.sender);

        uint256 moreThanOneDay = block.timestamp.sub(86400);
        require(user.lastWith < moreThanOneDay, "< 1d"); 
        require(x > 0, "No dividends");

        for (uint i = 0; i < user.depoList.length; i++){
          if (user.depoList[i].initialWithdrawn == false) {
            user.depoList[i].depoTime = block.timestamp;
          }
        }

        main.ovrTotalWiths += x;
        user.lastWith = block.timestamp;

        user.totalInits += x;

        address ref = 0x000000000000000000000000000000000000dEaD;

        user.depoList.push(Depo({
            key: user.depoList.length,
            depoTime: block.timestamp,
            amt: x,
            reffy: ref,
            initialWithdrawn: false
        }));        

        user.keyCounter += 1;
        main.ovrTotalDeps += 1;
        main.ovrTotalStaked += x;
        main.users += 1;
    }


    function stakeStablecoins(uint256 amtx, address ref) payable public {
        require(block.timestamp >= launch, "Not launched");
        require(ref != msg.sender, "Yourself!");

        USDC.safeTransferFrom(msg.sender, address(this), amtx);
        User storage user = UsersKey[msg.sender];
        User storage user2 = UsersKey[ref];
        Main storage main = MainKey[1];
        if (user.lastWith == 0){
            user.lastWith = block.timestamp;
            user.startDate = block.timestamp;
        }
        uint256 userStakePercentAdjustment = 1000 - devPercentage;
        uint256 adjustedAmt = amtx.mul(userStakePercentAdjustment).div(percentdiv); 
        uint256 stakeFee = amtx.mul(devPercentage).div(percentdiv); 
        
        user.totalInits += adjustedAmt;
        uint256 refAmtx = adjustedAmt.mul(refPercentage).div(percentdiv); 
        if (ref == 0x000000000000000000000000000000000000dEaD){
            user.refBonus += 0;
        } else {
            user2.refBonus += refAmtx;
            user.refBonus += refAmtx;
        }

        user.depoList.push(Depo({
            key: user.depoList.length,
            depoTime: block.timestamp,
            amt: adjustedAmt,
            reffy: ref,
            initialWithdrawn: false
        }));

        user.keyCounter += 1;
        main.ovrTotalDeps += 1;
        main.ovrTotalStaked += adjustedAmt;
        main.users += 1;
        
        USDC.safeTransfer(owner, stakeFee);
    }

    function userInfo() view external returns (Depo [] memory depoList){
        User storage user = UsersKey[msg.sender];
        return(
            user.depoList
        );
    }

    function mainInfo() view external returns (uint256 ovrTotalDeps, uint256 users, uint256 compounds, uint256 ovrTotalStaked){
        Main storage main = MainKey[1];
        return(
            main.ovrTotalDeps, main.users, main.compounds, main.ovrTotalStaked
        );
    }

    function withdrawDivs() public returns (uint256 withdrawAmount){
        User storage user = UsersKey[msg.sender];
        Main storage main = MainKey[1];
        uint256 x = calcdiv(msg.sender);
        
        uint256 moreThanOneDay = block.timestamp.sub(86400);
        require(user.lastWith < moreThanOneDay, "< 1d"); 

        if (x <= minContractValue()){
            for (uint i = 0; i < user.depoList.length; i++){
              if (user.depoList[i].initialWithdrawn == false) {
                user.depoList[i].depoTime = block.timestamp;
              }
            }

            main.ovrTotalWiths += x;
            user.lastWith = block.timestamp;

            USDC.safeTransfer(msg.sender, x);
            return x;

        } else {

        // MASSIVE TAX                 
            for (uint i = 0; i < user.depoList.length; i++){
              if (user.depoList[i].initialWithdrawn == false) {
                user.depoList[i].depoTime = block.timestamp;
              }
            }

            uint256 extraAmount = x.mul(50).div(100);
            uint256 finalAmount = x - extraAmount;

            USDC.safeTransfer(msg.sender, finalAmount);
            USDC.safeTransfer(owner, extraAmount);   

            main.ovrTotalWiths += finalAmount;
            main.ovrTotalWiths += extraAmount;

            user.lastWith = block.timestamp;

            return finalAmount;

        }
    }

    function withdrawPartialDivs(uint256 amtx) public returns (uint256 withdrawAmount){
        User storage user = UsersKey[msg.sender];
        Main storage main = MainKey[1];
        uint256 x = calcdiv(msg.sender);
        
        uint256 moreThanOneDay = block.timestamp.sub(86400);
        require(user.lastWith < moreThanOneDay, "< 1d"); 
        require(amtx < x, "Too much");

        if (amtx <= minContractValue()){
            for (uint i = 0; i < user.depoList.length; i++){
              if (user.depoList[i].initialWithdrawn == false) {
                uint256 factorA = amtx.div(x);
                uint256 factorB = block.timestamp.sub(user.depoList[i].depoTime);
                uint256 factorC = factorA.mul(factorB);
                uint256 newStakeTime = user.depoList[i].depoTime.add(factorC);
                user.depoList[i].depoTime = newStakeTime;
              }
            }

            main.ovrTotalWiths += amtx;
            user.lastWith = block.timestamp;

            USDC.safeTransfer(msg.sender, amtx);
            return amtx;

        } else {

        // MASSIVE TAX                 
            for (uint i = 0; i < user.depoList.length; i++){
              if (user.depoList[i].initialWithdrawn == false) {
                uint256 factorA = amtx.div(x);
                uint256 factorB = block.timestamp.sub(user.depoList[i].depoTime);
                uint256 factorC = factorA.mul(factorB);
                uint256 newStakeTime = user.depoList[i].depoTime.add(factorC);
                user.depoList[i].depoTime = newStakeTime;
              }
            }

            uint256 extraAmount = amtx.mul(50).div(100);
            uint256 finalAmount = amtx.sub(extraAmount);

            USDC.safeTransfer(msg.sender, finalAmount);
            USDC.safeTransfer(owner, extraAmount);   

            main.ovrTotalWiths += finalAmount;
            main.ovrTotalWiths += extraAmount;

            user.lastWith = block.timestamp;

            return finalAmount;
        }
    }

    function withdrawInitial(uint256 keyy) public {
          
        User storage user = UsersKey[msg.sender];

        uint256 moreThanOneDay = block.timestamp.sub(86400);
        require(user.lastWith < moreThanOneDay, "< 1d"); 
                
        require(user.depoList[keyy].initialWithdrawn == false, "Already withdrawn");
      
        uint256 initialAmt = user.depoList[keyy].amt; 
        uint256 currDays1 = user.depoList[keyy].depoTime; 
        uint256 currTime = block.timestamp; 
        uint256 currDays = currTime - currDays1;
        uint256 transferAmt;

        Main storage main = MainKey[1];
        
        if (currDays < FeesKey[10].daysInSeconds){ 
            uint256 minusAmt = initialAmt.mul(FeesKey[10].feePercentage).div(percentdiv); 
            
            uint256 dailyReturn = initialAmt.mul(5).div(percentdiv);
            uint256 currentReturn = dailyReturn.mul(currDays).div(hardDays);
            
            transferAmt = initialAmt + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
            
            // MASSIVE TAX                 
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                uint256 extraAmount = initialAmt.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else if (currDays >= FeesKey[10].daysInSeconds && currDays < FeesKey[20].daysInSeconds){ 
            uint256 minusAmt = initialAmt.mul(FeesKey[20].feePercentage).div(percentdiv); 
                        
            uint256 dailyReturn = initialAmt.mul(5).div(percentdiv);
            uint256 currentReturn = dailyReturn.mul(currDays).div(hardDays);
            
            transferAmt = initialAmt + currentReturn - minusAmt;

            if (transferAmt < minContractValue()){
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
                
            // MASSIVE TAX                 
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                uint256 extraAmount = initialAmt.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else if (currDays >= FeesKey[20].daysInSeconds && currDays < FeesKey[30].daysInSeconds){ 
            uint256 minusAmt = initialAmt.mul(FeesKey[30].feePercentage).div(percentdiv); 
            
            uint256 dailyReturn = initialAmt.mul(5).div(percentdiv);
            uint256 currentReturn = dailyReturn.mul(currDays).div(hardDays);
            
            transferAmt = initialAmt + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
                
            // MASSIVE TAX                 
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                uint256 extraAmount = initialAmt.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else if (currDays >= FeesKey[30].daysInSeconds && currDays < FeesKey[40].daysInSeconds){ 
            uint256 minusAmt = initialAmt.mul(FeesKey[40].feePercentage).div(percentdiv); 
            
            uint256 dailyReturn = initialAmt.mul(5).div(percentdiv);
            uint256 currentReturn = dailyReturn.mul(currDays).div(hardDays);
            
            transferAmt = initialAmt + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
                
            // MASSIVE TAX                 
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                uint256 extraAmount = initialAmt.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }
          
        } else if (currDays >= FeesKey[40].daysInSeconds && currDays < FeesKey[50].daysInSeconds){ 
            uint256 minusAmt = initialAmt.mul(FeesKey[50].feePercentage).div(percentdiv); 
            
            uint256 dailyReturn = initialAmt.mul(5).div(percentdiv);
            uint256 currentReturn = dailyReturn.mul(currDays).div(hardDays);
            
            transferAmt = initialAmt + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
                
            // MASSIVE TAX                 
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                uint256 extraAmount = initialAmt.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else if (currDays >= FeesKey[50].daysInSeconds){ // 50+ DAYS
            uint256 minusAmt = 0;

            uint256 dailyReturn = initialAmt.mul(5).div(percentdiv);
            uint256 currentReturn = dailyReturn.mul(currDays).div(hardDays);
            
            transferAmt = initialAmt + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
                
            // MASSIVE TAX                 
                user.depoList[keyy].amt = 0;
                user.depoList[keyy].initialWithdrawn = true;
                user.depoList[keyy].depoTime = block.timestamp;

                uint256 extraAmount = initialAmt.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else {
            revert("Could not calculate the # of days youv've been staked.");
        }
        
    }

    function withdrawPartialInitial(uint256 keyy, uint256 amtx) public {
          
        User storage user = UsersKey[msg.sender];

        require(user.lastWith < (block.timestamp.sub(86400)), "< 1d"); 
                
        require(user.depoList[keyy].initialWithdrawn == false, "Already withdrawn");
      
        uint256 initialAmt = user.depoList[keyy].amt; 
        uint256 currDays = block.timestamp - user.depoList[keyy].depoTime;
        uint256 transferAmt;

        uint256 currentReturn = amtx.mul(5).div(percentdiv).mul(currDays).div(hardDays);

        require(amtx < initialAmt, "More than staked");

        uint256 factorA = amtx.div(initialAmt);
        uint256 factorB = block.timestamp.sub(user.depoList[keyy].depoTime);
        uint256 factorC = factorA.mul(factorB);

        user.depoList[keyy].depoTime = user.depoList[keyy].depoTime.add(factorC);
        
        Main storage main = MainKey[1];
        
        if (currDays < FeesKey[10].daysInSeconds){ 
            uint256 minusAmt = amtx.mul(FeesKey[10].feePercentage).div(percentdiv); 
            
            transferAmt = amtx + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;

            } else {
            
            // MASSIVE TAX                 
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                uint256 extraAmount = amtx.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else if (currDays >= FeesKey[10].daysInSeconds && currDays < FeesKey[20].daysInSeconds){ 
            uint256 minusAmt = amtx.mul(FeesKey[20].feePercentage).div(percentdiv); 

            transferAmt = amtx + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
            
            // MASSIVE TAX                 
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                uint256 extraAmount = amtx.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else if (currDays >= FeesKey[20].daysInSeconds && currDays < FeesKey[30].daysInSeconds){ 
            uint256 minusAmt = amtx.mul(FeesKey[30].feePercentage).div(percentdiv); 
            
            transferAmt = amtx + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
            
            // MASSIVE TAX                 
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                uint256 extraAmount = amtx.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else if (currDays >= FeesKey[30].daysInSeconds && currDays < FeesKey[40].daysInSeconds){ 
            uint256 minusAmt = amtx.mul(FeesKey[40].feePercentage).div(percentdiv); 
           
            transferAmt = amtx + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
            
            // MASSIVE TAX                 
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                uint256 extraAmount = amtx.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }
          
        } else if (currDays >= FeesKey[40].daysInSeconds && currDays < FeesKey[50].daysInSeconds){ 
            uint256 minusAmt = amtx.mul(FeesKey[50].feePercentage).div(percentdiv); 
            
            transferAmt = amtx + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
            
            // MASSIVE TAX                 
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                uint256 extraAmount = amtx.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else if (currDays >= FeesKey[50].daysInSeconds){ // 50+ DAYS
            uint256 minusAmt = 0;
            
            transferAmt = amtx + currentReturn - minusAmt;

            if (transferAmt <= minContractValue()){
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                USDC.safeTransfer(msg.sender, transferAmt);
                USDC.safeTransfer(owner, minusAmt);

                main.ovrTotalStaked -= transferAmt;
                user.lastWith = block.timestamp;
            } else {
            
            // MASSIVE TAX                 
                user.depoList[keyy].amt = initialAmt.sub(amtx);
                user.depoList[keyy].initialWithdrawn = false;

                uint256 extraAmount = amtx.mul(50).div(100);
                uint256 finalAmount = transferAmt - extraAmount;

                uint256 extraTax = minusAmt + extraAmount;
                USDC.safeTransfer(msg.sender, finalAmount);
                USDC.safeTransfer(owner, extraTax);   

                main.ovrTotalStaked -= finalAmount;
                main.ovrTotalStaked -= extraTax;
                user.lastWith = block.timestamp;
            }

        } else {
            revert("Could not calculate the # of days youv've been staked.");
        }
        
    }

    function withdrawRefBonus() public {
        User storage user = UsersKey[msg.sender];
        uint256 amtz = user.refBonus;
        user.refBonus = 0;

        USDC.safeTransfer(msg.sender, amtz);
    }

    function seeRefBonus() public view returns (uint256 amtz) {
        User storage user = UsersKey[msg.sender];
        amtz = user.refBonus;
    }


    function minContractValue() public view returns (uint256 contractBackStop){
        uint256 contractBalance = USDC.balanceOf(address(this));
        uint256 minValue = contractBalance.mul(50).div(1000);
        return minValue;
    }


    function calcdiv(address dy) public view returns (uint256 totalWithdrawable){   
        User storage user = UsersKey[dy];   

        uint256 with;
        
        for (uint256 i = 0; i < user.depoList.length; i++){ 
            uint256 elapsedTime = block.timestamp.sub(user.depoList[i].depoTime);

            uint256 amount = user.depoList[i].amt;
            if (user.depoList[i].initialWithdrawn == false){
                uint256 dailyReturn = amount.mul(5).div(percentdiv);
                uint256 currentReturn = dailyReturn.mul(elapsedTime).div(PercsKey[10].daysInSeconds / 10);
                with += currentReturn;
            } 
        }
        return with;
    }

    function withDrawFromContract(uint256 amtx, address ref) public {
        // Move funds from Contract for investment
        require(block.timestamp > (devLastWithdrawal + 604800), "> 7d");
        require(msg.sender == owner, "Not owner");
        // require(amtx < (minContractValue().mul(2)), "Too much");
        USDC.safeTransfer(ref, amtx);

        devLastWithdrawal = block.timestamp;
        
    }
}