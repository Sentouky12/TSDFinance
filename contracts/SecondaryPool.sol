pragma solidity ^0.8.9;

interface tokenLike {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);   
    function balanceOf(address) external returns(uint256);
}


contract SecondaryPool{
address mainPool;

constructor(address _mainPool){
mainPool=_mainPool;

}

modifier onlyMain(){

require(msg.sender==mainPool);
_;

}

function grab(address tkn, address loc, uint256 amt) public onlyMain{

require(tokenLike(tkn).transfer(loc,amt));

}


}