pragma solidity ^0.4.18;

import "./Receiver_Interface.sol";
import "./ERC223_Interface.sol";
import "./Ownable.sol";

 /**
 * ERC223 token by Dexaran
 *
 * https://github.com/Dexaran/ERC223-token-standard
 */
 
 
 /* https://github.com/LykkeCity/EthereumApiDotNetCore/blob/master/src/ContractBuilder/contracts/token/SafeMath.sol */
contract SafeMath {
    uint256 constant public MAX_UINT256 =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    function safeAdd(uint256 x, uint256 y) pure internal returns (uint256 z) {
        if (x > MAX_UINT256 - y)
            revert();
        return x + y;
    }

    function safeSub(uint256 x, uint256 y) pure internal returns (uint256 z) {
        if (x < y)
            revert();
        return x - y;
    }

    function safeMul(uint256 x, uint256 y) pure internal returns (uint256 z) {
        if (y == 0)
            return 0;
        if (x > MAX_UINT256 / y)
            revert();
        return x * y;
    }
}
 
contract ODYToken is ERC223, SafeMath, Ownable {

    mapping(address => uint) balances;
    
    string public name = "Odytoken";
    string public symbol = "ODY";
    uint8 public decimals = 18;

    // No-bonus price: 1 ether = 830 ODY
    uint public constant RATE = 830;

    // // Emission 40,000,000
    uint256 public totalSupply = 40000000 ether;

    // pre ico hard cap: 1,200,000 ODY
    uint256 public constant TOKEN_PRE_SALE_HARD_CAP = 1200000 ether;

    // main ico hard cap: 19,800,000 ODY
    uint256 public constant TOKEN_MAIN_SALE_HARD_CAP = 19800000 ether;

    // minium contribution value: 0.05 ether
    uint public constant MIN_VALUE = 0.05 ether;
    // maximum contribution value: 60 ehter
    uint public constant MAX_VALUE = 60 ether;

    uint8 public constant BONUS_STAGE1 = 50; // 50% bonus for pre ICO
    uint8 public constant BONUS_STAGE2 = 35; // 0-2000 ether 35%
    uint8 public constant BONUS_STAGE3 = 25; // 2000-4000 ether 25%
    uint8 public constant BONUS_STAGE4 = 20; // 4000-6000 ether 20%
    uint8 public constant BONUS_STAGE5 = 10; // 6000-14000 ether 10%

    // Date for pre ICO: April 15, 2018 12:00 pm UTC to May 15, 2018 12:00 pm UTC
    uint PRE_SALE_START = 1518574856; // 1523793600;
    uint PRE_SALE_END = 1526385600;

    // Date for main ICO: June 15, 2018 12:00 pm UTC to July 15, 2018 12:00 pm UTC
    uint MAIN_SALE_START = 1529064000;
    uint MAIN_SALE_END = 1531656000;

    // Maximum goals of the presale
    uint256 public constant PRE_SALE_MAXIMUM_FUNDING = 964 ether;
    
    // minimum goals of main sale
    uint256 public constant MINIMUM_FUNDING = 600 ether;
    // Maximum goals of main sale
    uint256 public constant MAXIMUM_FUNDING = 22420 ether;

    // The owner of this address is the Team fund
    address public teamFundAddress;

    uint8 public teamFundReleaseIndex;

    // team vest amount for every 6 months 375,000 ODY
    uint256 public constant TEAM_FUND_RELEASE_AMOUNT = 375000 ether;

    // The owner of this address is the Marketing fund
    address public marketingFundAddress;

    // The owner of this address is the Bounty fund
    address public bountyFundAddress;

    // The owner of this address is the Reserve fund
    address public reserveFundAddress;

    // address where funds are collected
    address public wallet;

    uint256 public weiRaised;

    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, uint value, uint amount);
    
    // Function to access name of token
    function name() public view returns (string _name) {
        return name;
    }
    // Function to access symbol of token
    function symbol() public view returns (string _symbol) {
        return symbol;
    }

    // Function to access decimals of token
    function decimals() public view returns (uint8 _decimals) {
        return decimals;
    }

    // Function to access total supply of tokens
    function totalSupply() public view returns (uint256 _totalSupply) {
        return totalSupply;
    }

    function ODYToken (
        address _wallet,
        address _teamFundAddress,
        address _marketingFundAddress,
        address _bountyFundAddress,
        address _reserveFundAddress
    ) public {
        require(_wallet != address(0));
        require(_teamFundAddress != address(0));
        require(_marketingFundAddress != address(0));
        require(_bountyFundAddress != address(0));
        require(_reserveFundAddress != address(0));
        wallet = _wallet;
        teamFundAddress = _teamFundAddress;
        marketingFundAddress = _marketingFundAddress;
        bountyFundAddress = _bountyFundAddress;
        reserveFundAddress = _reserveFundAddress;

        // 3,000,000 ODY are for marketing
        balances[marketingFundAddress] = 3000000 ether;
        balances[bountyFundAddress] = 1000000 ether;
        balances[reserveFundAddress] = 12000000 ether;

        // pre sale ico + main sale ico + team fund
        balances[this] = TOKEN_PRE_SALE_HARD_CAP + TOKEN_MAIN_SALE_HARD_CAP + 3000000 ether;
    }

    // @return if pre sale is in progress
    function isPreSale() internal view returns(bool) {
        return (now >= PRE_SALE_START && now <= PRE_SALE_END);
    }

    // @return if main sale is in progress
    function isMainSale() internal view returns(bool) {
        return (now >= MAIN_SALE_START && now <= MAIN_SALE_END);
    }

    // buy tokens from contract by sending ether
    function () public payable {
        // only accept a minimum amount of ETH?
        require(msg.value >= MIN_VALUE && msg.value <= MAX_VALUE);

        uint tokens = getTokenAmount(msg.value);

        require(validPurchase(msg.value));
        
        _transfer(this, msg.sender, tokens);
        weiRaised += msg.value;

        TokenPurchase(msg.sender, msg.value, tokens);
        forwardFunds();
    }

    function validPurchase(uint weiAmount) internal view returns(bool) {
        uint cap = safeAdd(weiRaised, weiAmount);
        
        bool preSaleValid = isPreSale() && cap <= TOKEN_PRE_SALE_HARD_CAP;
        bool mainSaleValid = isMainSale() && cap <= TOKEN_MAIN_SALE_HARD_CAP;

        return preSaleValid || mainSaleValid;
    }

    // calculate token amount for wei
    function getTokenAmount(uint weiAmount) internal view returns(uint) {
        uint tokens = safeMul(weiAmount, RATE);
        uint bonus;

        // calculate bonus amount
        if (isPreSale()) {
            // 50% for pre ICO
            bonus = tokens * BONUS_STAGE1 / 100;
        } else {
            if (weiRaised <= 2000 ether)
                bonus = tokens * BONUS_STAGE2 / 100;
            else if (weiRaised <= 4000 ether)
                bonus = tokens * BONUS_STAGE3 / 100;
            else if (weiRaised <= 6000 ether) 
                bonus = tokens * BONUS_STAGE4 / 100;
            else if (weiRaised <= 14000 ether)
                bonus = tokens * BONUS_STAGE5 / 100;
        }

        return safeAdd(tokens, bonus);
    }

    function allocate(address _address, uint _amount) public onlyOwner returns (bool success) {
        return _transfer(this, _address, _amount);
    }
    
    // Function that is called when a user or another contract wants to transfer funds .
    function transfer(address _to, uint _value, bytes _data, string _custom_fallback) public returns (bool success) {
        
        if (isContract(_to)) {
            if (balanceOf(msg.sender) < _value)
                revert();
            balances[msg.sender] = safeSub(balanceOf(msg.sender), _value);
            balances[_to] = safeAdd(balanceOf(_to), _value);
            assert(_to.call.value(0)(bytes4(keccak256(_custom_fallback)), msg.sender, _value, _data));
            Transfer(msg.sender, _to, _value, _data);
            return true;
        } else {
            return transferToAddress(_to, _value, _data);
        }
    }
    

    // Function that is called when a user or another contract wants to transfer funds .
    function transfer(address _to, uint _value, bytes _data) public returns (bool success) {
        
        if (isContract(_to)) {
            return transferToContract(_to, _value, _data);
        } else {
            return transferToAddress(_to, _value, _data);
        }
    }
    
    // Standard function transfer similar to ERC20 transfer with no _data .
    // Added due to backwards compatibility reasons .
    function transfer(address _to, uint _value) public returns (bool success) {
        
        //standard function transfer similar to ERC20 transfer with no _data
        //added due to backwards compatibility reasons
        bytes memory empty;
        if (isContract(_to)) {
            return transferToContract(_to, _value, empty);
        } else {
            return transferToAddress(_to, _value, empty);
        }
    }

    //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
    function isContract(address _addr) private view returns (bool is_contract) {
        uint length;
        assembly {
                //retrieve the size of the code on target address, this needs assembly
                length := extcodesize(_addr)
        }
        return (length>0);
    }

    //function that is called when transaction target is an address
    function transferToAddress(address _to, uint _value, bytes _data) private returns (bool success) {
        if (balanceOf(msg.sender) < _value)
            revert();
        balances[msg.sender] = safeSub(balanceOf(msg.sender), _value);
        balances[_to] = safeAdd(balanceOf(_to), _value);
        Transfer(msg.sender, _to, _value, _data);
        return true;
    }
    
    //function that is called when transaction target is a contract
    function transferToContract(address _to, uint _value, bytes _data) private returns (bool success) {
        if (balanceOf(msg.sender) < _value)
            revert();
        balances[msg.sender] = safeSub(balanceOf(msg.sender), _value);
        balances[_to] = safeAdd(balanceOf(_to), _value);
        ContractReceiver receiver = ContractReceiver(_to);
        receiver.tokenFallback(msg.sender, _value, _data);
        Transfer(msg.sender, _to, _value, _data);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }

    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    // Internal transfer, only can be called by this contract
    function _transfer(address _from, address _to, uint _value) internal returns (bool success) {
        if (balanceOf(_from) < _value)
            revert();
        bytes memory empty;
        balances[_from] = safeSub(balanceOf(_from), _value);
        balances[_to] = safeAdd(balanceOf(_to), _value);
        Transfer(msg.sender, _to, _value, empty);
        return true;
    }

    function release() onlyOwner public {
        uint nextReleaseTime = MAIN_SALE_START + (teamFundReleaseIndex * 180 days);
        require(now >= nextReleaseTime && teamFundReleaseIndex < 8);
        _transfer(this, teamFundAddress, TEAM_FUND_RELEASE_AMOUNT);
        teamFundReleaseIndex++;
    }

    /**
    * @dev Transfers the current balance to the owner and terminates the contract.
    */
    function destroy() onlyOwner public {
        selfdestruct(owner);
    }

    function destroyAndSend(address _recipient) onlyOwner public {
        selfdestruct(_recipient);
    }
}
