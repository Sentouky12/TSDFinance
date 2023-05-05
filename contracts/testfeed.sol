pragma solidity ^0.8.9;

//This is just a test feed, we only need it to return a number we can use as price for testing purposes.


contract TestFeed{


function decimals() public pure  returns(uint8 decimals){

    return 18;
}


function latestRoundData() public view returns(uint80 roundId,int256 answer,uint256 startedAt,uint256 timestamp, uint80 answeredInRound){

roundId=1;
answer=15000000000000000000;
startedAt=block.timestamp;
timestamp=block.timestamp;
answeredInRound=1;

return(roundId,answer,startedAt,timestamp,answeredInRound);

}



function getRoundData(uint80 Id,bool safe) public view  returns(uint80 roundId,int256 answer,uint256 startedAt,uint256 timestamp, uint80 answeredInRound) {
if(safe){
    answer=15000000000000000000;
}
else{
    answer=1000000000000000000000;
}
roundId=1;
startedAt=block.timestamp;
timestamp=block.timestamp;
answeredInRound=1;

return(roundId,answer,startedAt,timestamp,answeredInRound);

}


}