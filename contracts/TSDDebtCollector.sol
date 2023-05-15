pragma solidity ^0.8.9;
import "../math/TSDMath.sol";
import "../interfaces/IERC20.sol";

interface VMLike{
    function creditTransfer(address,address,address,uint256 ) external;
    function confiscate(address,address,address,uint256,uint256 ) external;
    function vaults(address,address) external view returns(uint256 lcoll,
                                                           uint256 idbt);
    function colls(address) external view returns(uint256 tdbt, 
                                                  uint256 price,
                                                  uint256 mc,    
                                                  uint256 tsc,
                                                  uint256 msc,
                                                  uint256 _100perc,
                                                  uint256 dec);  
    function updateprice(address) external;                                                                                                 
}

interface FeedLike{
  function getprice(address,uint256) external returns(uint256);
}

contract Collector{

struct Coll{
  uint256 tdbt;
   uint256 price;
    uint256 mc;   
    uint256 tsc;
    uint256 msc;
    uint256 dec; 
}


struct Sale{
uint256 pos;
uint256 needed; //debt
uint256 available;//coll
uint256 price;
address usr;
address coll;

}

struct Vars{
  uint256 debtx;
  uint256 collx;
  uint256 collvx;
  uint256 tdebtx;
  uint256 icoll;
  uint256 idebt;
  uint256 price;
  uint256 mc;
  uint256 msc;
  uint256 _100perc;
}
mapping(uint256=>Sale) public sales;
mapping(address => Coll) public liqcolls;
mapping (address => uint) public wards;
 uint256[] public forsale;
 uint256 public id;

event Repossess(address,address,address);
event SaleStarted(address,uint256,uint256,address,address);
    function rely(address usr) external  auth { require(on == 1, "Vat/not-live"); wards[usr] = 1; }
    function deny(address usr) external  auth { require(on == 1, "Vat/not-live"); wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Vat/not-authorized");
        _;

}
IERC20 public tsd;
uint public on;
FeedLike public feed;
VMLike public vm;
  constructor(address _vm,address _tsd,address _feed){
  wards[msg.sender]=1;
  vm=VMLike(_vm);
  on=1;
  tsd=IERC20(_tsd);
  feed=FeedLike(_feed);
}



function _min(uint _a, uint _b) internal pure returns (uint) {
        return (_a < _b) ? _a : _b;
    }

    function _max(uint _a, uint _b) internal pure returns (uint) {
        return (_a >= _b) ? _a : _b;
    }



function repossess(address _coll,address vlt,address taker) public {
require(on==1,"Debt collector turned off");
vm.updateprice(_coll);
Vars memory vars;
uint256 debtx;uint256 collx;uint256 collvx;uint256 tdebtx;
(vars.icoll,vars.idebt)= vm.vaults(_coll,vlt);
(,vars.price,vars.mc, ,vars.msc,vars._100perc,)= vm.colls(_coll);
  //vars.price=10000000000000000000;
uint256 ICR=TSDMath._computeCR(vars.icoll,vars.idebt,vars.price);
  require(ICR<=vars.mc,"Cannot liquidate a safe vault");



if(ICR<=vars._100perc){
 vars.debtx=vars.idebt;
 vars.collx=vars.icoll;

}
if(ICR>=vars._100perc && ICR< vars.mc){
collvx=vars.icoll*vars.price;
//tdebtx=(mc*idebt-collvx/mc-_100perc)*10/100; dont 
tdebtx=((((vars.mc*vars.idebt)-collvx)/(vars.mc-vars._100perc)));
uint256 perc=tdebtx*10/100;
vars.debtx=tdebtx+perc;
vars.collx=(vars.debtx*10**18/vars.price);

}
vm.confiscate(_coll,vlt,address(this),vars.collx,vars.debtx);
this.startSale(_coll,vars.debtx,vars.collx,vlt,taker);

emit Repossess(_coll,vlt,taker);
}

function startSale(address _coll,uint256 debtx,uint256 collx, address vlt,address incentives) public auth{
require(on==1,"Debt collector turned off");
require(debtx > 0);
require(collx > 0);
require(vlt!=address(0));

uint256 price= feed.getprice(_coll,18);
//uint256 price=10000000000000000000;


forsale.push(id);
sales[id].pos=forsale.length-1;
sales[id].usr=vlt;
sales[id].needed=debtx;
sales[id].available=collx;
sales[id].coll=_coll;
sales[id].price=price;
uint256 reward=debtx*10/100;
tsd.mint(incentives,reward);
id++;

emit SaleStarted(_coll,debtx,collx,vlt,incentives);
}

function buy(uint256 id,uint256 amount,uint256 maxprice,address rcvr) public {
require(on==1,"Debt collector turned off");
address coll=sales[id].coll;
uint256 price=feed.getprice(coll,18);
//uint256 price=10000000000000000000;
uint256 needed=sales[id].needed;
uint256 available=sales[id].available;
address user=sales[id].usr;
uint256 buying=_min(available,amount);
uint256 required=(buying*price)/10**18;
require(price<=maxprice,"Buyer doesnt accept the price");
if(required>needed){
  required=needed;
  buying=(required/price)*10**18;
} 

available-=buying;
needed-=required;

tsd.burn(msg.sender,required);
vm.creditTransfer(coll,address(this),rcvr,buying);
if(available==0){
forsale.pop();
}else if(needed==0){
  vm.creditTransfer(coll,address(this),user,available);
  forsale.pop();
}else{
  sales[id].available=available;
  sales[id].needed=needed;
}


}



function turnoff() public auth{
    on=0;
} 

}