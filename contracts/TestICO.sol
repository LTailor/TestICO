pragma solidity ^0.4.15;

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) constant returns (uint256);
  function transfer(address to, uint256 value) returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) returns (bool);
  function approve(address spender, uint256 value) returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {

  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

}
/**
 Basic Token
*/
contract BasicToken is ERC20Basic {

  using SafeMath for uint256;

  mapping(address => uint256) balances;

  /**
  * Transfer token for a specified address
  */
  function transfer(address _to, uint256 _value) returns (bool) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * Gets the balance of the specified address.
  */
  function balanceOf(address _owner) constant returns (uint256 balance) {
    return balances[_owner];
  }

}

/**
 * Standard ERC20 token
 *
 */
contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) allowed;

  /**
   * Transfer tokens from one address to another
   */
  function transferFrom(address _from, address _to, uint256 _value) returns (bool) {
    var _allowance = allowed[_from][msg.sender];

    require ((_allowance>=_value) && (balances[_from]>=_value));
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);

    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * Aprove the passed address to spend the specified amount of tokens on behalf of msg.sender.
   */
  function approve(address _spender, uint256 _value) returns (bool) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    require((_value == 0) || (allowed[msg.sender][_spender] == 0));

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * Function to check the amount of tokens that an owner allowed to a spender.
   */
  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

}

/**
 *  Ownable
 */
contract Ownable {

  address public owner;

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }

  /**
   * Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * Allows the current owner to transfer control of the contract to a newOwner.
   */
  function transferOwnership(address newOwner) onlyOwner {
    require(newOwner != address(0));
    owner = newOwner;
  }

}

contract TestLogicToken is StandardToken, Ownable {
  uint public maxTokens;


  function TestLogicToken(uint totalTokens)
  {
    maxTokens = totalTokens;
  }

  function addTokens(address to,uint value) onlyOwner {
    maxTokens = maxTokens.sub(value);
    balances[to] = balances[to].add(value);
  }
}

contract TestTokenCoin is TestLogicToken {

    string public constant name = "Test Token";

    string public constant symbol = "TST";

    uint32 public constant decimals = 18;

    function TestTokenCoin(uint maxTokens_) TestLogicToken(maxTokens_)
    {

    }

    function burnUnusedTokens() onlyOwner
    {
      maxTokens = 0;
    }

}


contract Crowdsale is Ownable {

    using SafeMath for uint;

    uint public restrictedPercent;

    address public restricted;

    TestTokenCoin public token;

    uint public start;

    uint public period;

    uint public hardcap = (maxTokens - tokensForOwners)/rate * 1 ether;

    address public  owners;

    uint constant rate = 50000;

    uint public softcap = maxTokens/(rate * 2) * 1 ether;

    uint constant maxTokens = 21 * 10 ** 6;

    uint constant tokensForOwners = 10 ** 6;

    mapping(address => uint) public balances;

    function Crowdsale() {
      start = now;
      period = 28;
      token = new TestTokenCoin(maxTokens);
    }

    modifier saleIsOn() {
      require(now > start && now < start + period * 1 days);
      _;
    }

    modifier saleIsOff() {
      require(now > start + period * 1 days);
      _;
    }

    modifier isUnderHardCap() {
      require(this.balance <= hardcap);
      _;
    }

    function refund() saleIsOff {
      require(this.balance < softcap);
      uint value = balances[msg.sender];
      balances[msg.sender] = 0;
      msg.sender.transfer(value);
    }

   function createTokens() isUnderHardCap saleIsOn payable {
      uint tokens = rate.mul(msg.value).div(1 ether);
      uint bonusTokens = 0;
      if(now < start + (period * 1 days).div(4)) {
        bonusTokens = tokens.div(4);
      } else if(now >= start + (period * 1 days).div(4) && now < start + (period * 1 days).div(4).mul(2)) {
        bonusTokens = tokens.div(10);
      } else if(now >= start + (period * 1 days).div(4).mul(2) && now < start + (period * 1 days).div(4).mul(3)) {
        bonusTokens = tokens.div(20);
      }
      tokens += bonusTokens;

      token.addTokens(msg.sender, tokens);
      balances[msg.sender] = balances[msg.sender].add(msg.value);
    }

    function finishCrowdsale() saleIsOff
    {
      token.addTokens(owners, tokensForOwners);
      token.burnUnusedTokens();
    }

    function() external payable {
      createTokens();
    }

}
