pragma solidity ^0.8.9;
import "../math/TSDMath.sol";
import "../interfaces/IERC20.sol";
interface FeedLike{
function addPriceFeed(address,address) external;
function getprice(address,uint256) external returns(uint);
}

interface GranterLike{
  function addSupportedToken(address) external returns(uint256); 
}

contract VaultManager{
  GranterLike vcg; //vault credit granter
  FeedLike feed;
  IERC20 tsd;
uint256 public on=1;
uint256 public tempPrice;//Just for test;
uint256 public incoll;//Just for test;
uint256 public vaultcoll;//Just for test;
uint256 public idebt;//Just for test;
uint256 public credit;//Just for test;
 mapping (address => uint) public wards;
    function rely(address usr) external  auth { require(on == 1, "Vat/not-live"); wards[usr] = 1; }
    function deny(address usr) external  auth { require(on == 1, "Vat/not-live"); wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "Vat/not-authorized");
        _;

}
constructor(address _tsd) public {
wards[msg.sender] = 1;
tsd=IERC20(_tsd);
}

mapping(address=>uint256) public Tsd;
mapping(address=>Coll) public colls;
mapping(address=>mapping(address=>Vault)) public vaults;
mapping (address => mapping (address => uint)) public collcredit;
// mapping(collateral address=>user address => user balances).
struct Coll{
    uint256 tdbt;   //total debt
    uint256 price; // price of the collateral
    uint256 mc;    //minimum collateral ratio for a given coll type
    uint256 tsc;  //total system collateral for a given coll type 
    uint256 msc;//minimum system collateral ratio for a given coll type
    uint256 _100perc; //100%
    uint256 dec; //decimals
}

struct Vault{
uint256 lcoll; //locked collateral
uint256 idbt; //individual debt
}

function getVaultInfo(address coll,address usr) public  {
Vault memory vault;
vaultcoll=vaults[coll][usr].lcoll;
idebt=vaults[coll][usr].idbt;

}

function setPriceFeed(address priceFeed) public auth{
  require(on==1,"VM turned off");
feed=FeedLike(priceFeed);


}

function setGranter(address _granter) public auth{
  require(on==1,"VM turned off");
vcg=GranterLike(_granter);

}

function turnoff() public auth{
    on=0;
}

function addColl(address _newcoll,address collFeed) public auth{
 require(on==1,"VM turned off");
 uint256 dec= vcg.addSupportedToken(_newcoll);
              feed.addPriceFeed(_newcoll,collFeed);
  Coll memory coll=colls[_newcoll];
  coll.dec=dec;
  coll._100perc=10**18;//100%
  coll.price=feed.getprice(_newcoll,dec);
  coll.mc=(12*(10**18))/10;//120%
  coll.msc=(15*(10**18))/10;//150%
  colls[_newcoll]=coll;
}

function tempcollinfo(address coll,address usr) public  {//Function just for test delete it later
tempPrice=colls[coll].price;
incoll=collcredit[coll][usr];
vaultcoll=vaults[coll][usr].lcoll;
idebt=vaults[coll][usr].idbt;
}
function interact(address _coll, address usr, uint256 wad,bool isWithdrawal) public  auth {
      if(isWithdrawal==false){
        
      collcredit[_coll][usr]+=wad;
       }else{
        collcredit[_coll][usr]-=wad;
       }
//coll.tdbt//total system debt we add this in modify when users deposits coll and we give him stable for it  modifies vault
//coll.tsc//total system collateral we add this in modifiy when isWithdrawal==false users modifies vault
    }

function modify(address _coll, address vlt, uint256 collchange,uint256 tsdchange,bool isCollIncrease,bool isDebtIncrease ) public {
  require(on==1,"VM turned off");
  Vault memory vault=vaults[_coll][vlt];
  Coll  memory coll=colls[_coll];
  coll.price=feed.getprice(_coll,18);  
  bool isEmergencyMode=isEmergencyMode(_coll,coll.price);
  require(collchange!=0 || tsdchange!=0,"Zero adjustment is not possible");
uint256 borrowingfee;
   if(isDebtIncrease&& !isEmergencyMode){
   require(tsdchange>0);
    borrowingfee=getBorrowingfee(tsdchange);
   tsdchange+=borrowingfee;
   }

    if(isDebtIncrease){
  require(tsdchange>0);
  vault.idbt+=tsdchange;
  coll.tdbt+=tsdchange;
 }else{

   vault.idbt-=tsdchange;
   coll.tdbt-=tsdchange;
}

   if(isCollIncrease){
   vault.lcoll+=collchange;
   coll.tsc+=collchange;
   collcredit[_coll][msg.sender]-=collchange;
 }else{
   vault.lcoll-=collchange;
   coll.tsc-=collchange;
   collcredit[_coll][msg.sender]+=collchange;
}

   uint256 icr=TSDMath._computeCR(vault.lcoll, vault.idbt,coll.price);
   requireVaultSafe(isEmergencyMode,isDebtIncrease,coll,icr);


  vaults[_coll][vlt]=vault;
 colls[_coll]=coll;


 if(isDebtIncrease){
  tsd.mint(vlt,tsdchange-borrowingfee);
 }else{

  tsd.burn(msg.sender,tsdchange);
 }
 
}

function getBorrowingfee(uint256 tsdchange) public returns(uint){
  return tsdchange*30/10000;//0.3%
  //we re using basis points so we get percantages lower than 1% if we want to
}



function requireVaultSafe(bool isEmergencyMode,
                         bool isDebtIncrease,
                         Coll memory coll,
                         uint256 icr ) public view {

if(isEmergencyMode){
  if(isDebtIncrease)
    require(icr>=coll.msc,'ICR should be greater than MSC');
  
}else{
require(icr>=coll.mc,'ICR should be greater than MC');
uint256 TCR=TSDMath._computeCR(coll.tsc,coll.tdbt,coll.price);
                            //coll total sis coll, total sis debt, coll price
require(TCR>=coll.msc,'TCR should be greater than MSC');
  }
}


function getTCR(address coll,uint _price) internal view returns (uint TCR) {
      uint256 totalDebt= colls[coll].tdbt;
      uint256 totalCollateral=colls[coll].tsc;
       
       TCR=TSDMath._computeCR(totalCollateral, totalDebt, _price);

        return TCR;
    }



 function isEmergencyMode(address coll,uint _price) internal view returns (bool) {
        uint TCR = getTCR(coll,_price);

        return TCR < colls[coll].msc;
    }


function confiscate(address _coll, address vlt,address liq,uint256 colx,uint256 debtx) public auth {

Vault storage vault= vaults[_coll][vlt];
Coll storage coll= colls[_coll];

vault.lcoll-=colx;
vault.idbt-=debtx;
coll.tsc-=colx;
coll.tdbt-=debtx;
collcredit[_coll][liq]+=colx;

vaults[_coll][vlt]=vault;
colls[_coll]=coll;

}

//function addcredit()

function creditTransfer(address _coll, address from,address to, uint256 howmuch) public auth {
  collcredit[_coll][from]-=howmuch;
  collcredit[_coll][to]+=howmuch;
}

function updateprice(address _coll) public auth{
  uint256 dec=colls[_coll].dec;
  colls[_coll].price=feed.getprice(_coll,dec);
}

   // function modify(address _coll, address usr, int256 wad,bool isWithdrawal) external  auth {
      // if(isWithdrawal==false){
       // gem[ilk][usr]+=wad;
      // }else{
      //  gem[ilk][usr]-=wad;
     //  }

  //  }

}