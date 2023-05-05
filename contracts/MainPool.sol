pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface tokenLike {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);   
    function balanceOf(address) external returns(uint256);
}




interface PoolLike{

function grab(address, address, uint256) external returns(bool);

}

contract PoolV1 is AccessControl{
//Made to split capital between different pools so we dont leave it in 
//borrower, and borrower gets frozen by a mal intentioned admin, 
//or we need to upgrade borrower to add functionality etc and this way we avoid 
//unnacessary transfers of capital
address public vcg;//Vault Credit Granter.
address public executor;
uint public Passed;
address[] public vtrarr;
mapping(address=>uint) public voters;
address[] public pools;

modifier OnlyGranter{
require(msg.sender==vcg,"Not granter");
_;
}

modifier passedvote{
    require(msg.sender==executor);
    require(Passed==1);
    _;
    Passed=0;
    delete executor;
    for(uint j=0;j<=vtrarr.length;j++){
       delete voters[vtrarr[j]];
    }
    delete vtrarr;
}




constructor(address _granter) {
_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
vcg=_granter;



}
function getNumberOfPools() public view returns(uint256){
    return pools.length;
}

function send(address tkn,address receiver,uint256 amt) public passedvote{
require(tokenLike(tkn).transfer(receiver,amt));
}

function pull(address tkn, uint256 amt,uint256 poolnr) public passedvote{
require(PoolLike(pools[poolnr]).grab(tkn,address(this),amt));
}

function take(address tkn, address usr,uint256 amt) public OnlyGranter returns(bool){
require(tokenLike(tkn).transfer(usr,amt),"Pool1/failed-transfer");
return true;


}
function changeGranterContract(address newcontract) public passedvote{
vcg=newcontract;
}

function addSupportedPools(address _pool) public passedvote {
pools.push(_pool);
}
function vote() public onlyRole(DEFAULT_ADMIN_ROLE){
require(voters[msg.sender]==0,"You already voted");
require(Passed==0,"Voting ability already unlocked");
voters[msg.sender]=1;
vtrarr.push(msg.sender);
if(vtrarr.length==6){
    Passed=1;
executor=msg.sender;
}
}


}