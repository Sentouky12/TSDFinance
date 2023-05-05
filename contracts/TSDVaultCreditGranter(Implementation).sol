pragma solidity ^0.8.9;

interface VMlike{
    function interact(address,address,uint256,bool) external;
}
interface PoolLike{
    function take(address,address,uint256) external returns(bool);
}
interface tokenLike {

    function decimals() external view returns (uint8);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function symbol() external view  returns (string memory);
}

struct token{
    address tokenAddress;
    uint256 decimals;
}

struct coll{
    uint256 tdbt;   //total debt
    uint256 price; // price of the collateral
    uint256 rate; //total acc rates
    uint256 mc; //minimum collateral amount for a given collateral type
}


contract TSDGranter{
VMlike public vm;
PoolLike public mpool;
mapping (address => uint) public wards;
mapping(string => token) public tokens; 
mapping(address => coll) public colls;
    function rely(address guy) external auth { wards[guy] = 1; }
    function deny(address guy) external auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "TSD/not-authorized");
        _;
    }

   
   uint256 public on;

constructor(address _vm) public{
vm=VMlike(_vm);
wards[msg.sender] = 1;
on=1;


}

function setMainPool(address _mainpool) public auth {
mpool=PoolLike(_mainpool);

}

function addSupportedToken(address _supportedToken) public auth returns(uint256){
require(on==1,"Granter is turned off");
string memory symbol=tokenLike(_supportedToken).symbol();
uint256  _decimals=tokenLike(_supportedToken).decimals();
tokens[symbol].tokenAddress=_supportedToken;
tokens[symbol].decimals=_decimals;

return _decimals;
//colls[_supportedToken]
}

function turnoff() public auth{
on=0;

}


function StoreInVault(string memory symbol,address usr,uint256 amt) public{
require(on==1,"Granter is turned off");
bool  isWithdrawal=false;
//vars.price = priceFeed.fetchPrice(); we need a price feed that 
//gets prices from an oracle and updates them with delay of idk 5 mins
uint256 wad=(amt*10**(18-tokens[symbol].decimals));
require(wad>=0);
require(tokenLike(tokens[symbol].tokenAddress).transferFrom(msg.sender, address(mpool), amt), "Granter/failed-transfer");
vm.interact(tokens[symbol].tokenAddress,usr,wad,isWithdrawal);

}



function WithdrawFromVault(string memory symbol,uint256 amt,address beneficiary) public {
require(on==1,"Granter is turned off");
bool  isWithdrawal=true;
uint256 wad=(amt*10**(18-tokens[symbol].decimals));
require(wad>=0);
vm.interact(tokens[symbol].tokenAddress,msg.sender,wad,isWithdrawal);
require(mpool.take(tokens[symbol].tokenAddress,beneficiary,amt), "Granter/failed-transfer");

 
}



}