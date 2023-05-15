const { defaultAccounts } = require('ethereum-waffle');
const { hexStripZeros, getAddress } = require('ethers/lib/utils');
const { ethers} = require('hardhat');
// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");


async function main() {
  wallet = await ethers.getSigners();





  const EncodedCall= await ethers.getContractFactory('EncodedCall');
  console.log('Deploying EncodedCall. . .');
  const encodedcall=await EncodedCall.deploy();
  await encodedcall.deployed();
  console.log('EncodedCall deployed to: ', encodedcall.address);


const TSDToken=await ethers.getContractFactory('TSDToken');
console.log('Deploying TSDToken. . .');
const tsd=await TSDToken.deploy();
await tsd.deployed();
console.log('TSDToken deployed to: ',tsd.address);


const KingToken=await ethers.getContractFactory('King');
console.log('Deploying King Token. . .');
const king=await KingToken.deploy('1000000000000000000000000000');
await king.deployed();
console.log('KingToken deployed to: ',king.address);



const TestFeed=await ethers.getContractFactory('TestFeed');
console.log('Deploying Test Feed. . .');
const testfeed=await TestFeed.deploy();
await testfeed.deployed();
console.log('Test Feed deployed at: ',testfeed.address);


const VaultManager=await ethers.getContractFactory('VaultManager');
console.log('Deploying VaultManager. . .');
const vm=await VaultManager.deploy(tsd.address);
await vm.deployed();
console.log('VaultManger deployed to: ',vm.address);


const TSDGranter=await ethers.getContractFactory('TSDGranter');
console.log('Deploying TSDGranter. . .');
const granter=await TSDGranter.deploy(vm.address);
await granter.deployed();
console.log('TSDGranter deployed to: ', granter.address);

const MainPool=await ethers.getContractFactory('PoolV1');
console.log('Deploying MainPool. . .');
const mpool=await MainPool.deploy(granter.address);
await mpool.deployed();
console.log('MainPool deployed to: ',mpool.address);

const SecondaryPool=await ethers.getContractFactory('SecondaryPool');
console.log('Deploying Secondary Pool. . .');
const spool=await SecondaryPool.deploy(mpool.address);
await spool.deployed();
console.log('SecondaryPool deployed to: ', spool.address);

const PriceFeed=await ethers.getContractFactory('PriceFeed');
console.log('Deploying PriceFeed. . .');
const feed=await PriceFeed.deploy(vm.address);
await feed.deployed();
console.log('Price Feed deployed to: ',feed.address);

const DebtCollector=await ethers.getContractFactory('Collector');
console.log('Deploying DebtCollector. . .');
const collector=await DebtCollector.deploy(vm.address,tsd.address,feed.address);
await collector.deployed();
console.log('Debt Collector deployed to: ',collector.address);

const Proxy= await ethers.getContractFactory('TransparentUpgradeableProxy');
 console.log('Deploying TransparentUpgradeableProxy. . .');
 const proxy=await Proxy.deploy(collector.address,"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",'0x');
 await proxy.deployed();
 console.log('TransparentUpgradeableProxy deployed to: ', proxy.address);





await tsd.rely(vm.address);
await tsd.rely(collector.address);
 await granter.setMainPool(mpool.address);
 await granter.rely(vm.address);
 await vm.setPriceFeed(feed.address);
 await vm.setGranter(granter.address);
 await vm.addColl(king.address,testfeed.address);
 await vm.tempcollinfo(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
 await vm.rely(granter.address);
 await vm.rely(collector.address);
 await collector.rely(collector.address);
 var price=await vm.tempPrice();
 console.log(price);
var collcredit=await vm.incoll();
console.log(collcredit);
 await king.approve(granter.address,'100000000000000000000');
 await granter.StoreInVault('KING','0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266','100000000000000000000');
 await vm.tempcollinfo(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
 var collcredit=await vm.incoll();
console.log(collcredit);
await vm.modify(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266','100000000000000000000','900000000000000000000',true,true);
var balance=await tsd.balanceOf('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
console.log("King balance after vault loan is "+balance);
await vm.tempcollinfo(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
var lockedcoll=await vm.vaultcoll();
console.log("locked coll is "+lockedcoll);
var individualdebt=await vm.idebt();
console.log("Individual debt is "+ individualdebt);
var individualcoll=await vm.incoll();
console.log("Individual coll after borrowing is "+ individualcoll);
await tsd.mint('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266','1000000000000000000000000');
//await vm.modify(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266','100000000000000000000','902700000000000000000',false,false);
var tsdbalance=await tsd.balanceOf('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
console.log("TSD balance after loan repayment is "+ tsdbalance);

await vm.tempcollinfo(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
var individualcoll=await vm.incoll();
console.log("Individual coll after borrowing is "+ individualcoll);
var vaultinfo=await vm.vaults(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
console.log("Before liquidation "+vaultinfo);
//await collector.repossess(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',mpool.address);

// address _logic,
 //address admin_,
 //bytes memory _data

//var sale=await collector.sales(0);
//console.log(sale);

//var balancebeforebuy=await tsd.balanceOf('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
//console.log('Balance before buy '+balancebeforebuy);
//var creditinfo=await vm.collcredit(king.address,'0x70997970C51812dc3A010C7d01b50e0d17dc79C8');
//console.log('Coll credit before buying '+creditinfo);
//await collector.buy(0,'457820000000000000000','10000000000000000000','0x70997970C51812dc3A010C7d01b50e0d17dc79C8');
//var balanceafterbuy=await tsd.balanceOf('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
//console.log('Balance after buy '+balanceafterbuy); 
//var vaultinfo=await vm.vaults(king.address,'0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
//console.log("After liquidation "+vaultinfo);
//var creditinfo=await vm.collcredit(king.address,'0x70997970C51812dc3A010C7d01b50e0d17dc79C8');
//console.log('Coll credit after buying '+creditinfo);
//var proxybalance = await hre.ethers.getContractAt("contract name",proxy.address);


  

 




 

}
//npx hardhat run --network localhost scripts/Deploy.js
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
