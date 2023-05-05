pragma solidity ^0.8.9;

import "../interfaces/IPriceFeed.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "../interfaces/ITellorCaller.sol";


contract PriceFeed{

address public vm;
uint256 public lastGoodPrice;
uint256 lastTimeStamp;
uint256 _5minutes=5*60;
constructor(address _vaultmanager) {

vm=_vaultmanager;



}

mapping(address =>address) tokenpricefeeds;

struct ChainlinkData {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
        uint8 decimals;
    }

event LastGoodPriceUpdated(uint _lastGoodPrice);

modifier onlyVM(){
    require(msg.sender==vm);
    _;
}

function addPriceFeed(address token,address _priceFeed) public onlyVM returns(uint){
tokenpricefeeds[token]=_priceFeed;
}

function getprice(address token,uint256 decimals) public returns(uint){

AggregatorV3Interface priceAggregator=AggregatorV3Interface(tokenpricefeeds[token]);

  ChainlinkData memory chainlinkdata = _getCurrentChainlinkResponse(priceAggregator);
        ChainlinkData memory prevchainlinkdata = _getPrevChainlinkResponse(priceAggregator,chainlinkdata.roundId, chainlinkdata.decimals);
    
             if (block.timestamp<lastTimeStamp+_5minutes) {
           
                    return lastGoodPrice; 
        }
                
             lastTimeStamp=block.timestamp;
             return _storeChainlinkPrice(chainlinkdata,decimals);
        
//You might need to delete the rest from here we re going to do a more simple oracle we dont have time.
//________________________________________________________________________________________________________________
       
    }

function _getCurrentChainlinkResponse(AggregatorV3Interface  priceAggregator) internal view returns (ChainlinkData memory chainlinkResponse) {
        // First, try to get current decimal precision:
        try priceAggregator.decimals() returns (uint8 decimals) {
            // If call to Chainlink succeeds, record the current decimal precision
            chainlinkResponse.decimals = decimals;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }

        // Secondly, try to get latest price data:
        try priceAggregator.latestRoundData() returns
        (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        )
        {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkResponse.roundId = roundId;
            chainlinkResponse.answer = answer;
            chainlinkResponse.timestamp = timestamp;
            chainlinkResponse.success = true;
            return chainlinkResponse;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }
    }

    function _getPrevChainlinkResponse(AggregatorV3Interface  priceAggregator,uint80 _currentRoundId, uint8 _currentDecimals) internal view returns (ChainlinkData memory prevChainlinkResponse) {
        /*
        * NOTE: Chainlink only offers a current decimals() value - there is no way to obtain the decimal precision used in a 
        * previous round.  We assume the decimals used in the previous round are the same as the current round.
        */

        // Try to get the price data from the previous round:
        try priceAggregator.getRoundData(_currentRoundId - 1) returns 
        (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        )
        {
            // If call to Chainlink succeeds, return the response and success = true
            prevChainlinkResponse.roundId = roundId;
            prevChainlinkResponse.answer = answer;
            prevChainlinkResponse.timestamp = timestamp;
            prevChainlinkResponse.decimals = _currentDecimals;
            prevChainlinkResponse.success = true;
            return prevChainlinkResponse;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return prevChainlinkResponse;
        }
    }


function _storeChainlinkPrice(ChainlinkData memory _chainlinkResponse,uint256 target_decimals) internal returns (uint) {
        uint scaledChainlinkPrice = _scaleChainlinkPriceByDigits(uint256(_chainlinkResponse.answer), _chainlinkResponse.decimals,target_decimals);
        _storePrice(scaledChainlinkPrice);

        return scaledChainlinkPrice;
    }
 function _scaleChainlinkPriceByDigits(uint _price, uint _answerDigits,uint256 target_decimals) public pure returns (uint) {
        /*
        * Convert the price returned by the Chainlink oracle to the desired decimal for use by TSD.
        */
        uint price;
        if (_answerDigits >= target_decimals) {
            // Scale the returned price value down to TSD's target precision
            price = _price/(10 ** (_answerDigits - target_decimals));
        }
        else if (_answerDigits < target_decimals) {
            // Scale the returned price value up to TSD's target precision
            price = _price*(10 ** (target_decimals - _answerDigits));
        }
        return price;
    }


function _storePrice(uint _currentPrice) internal {
        lastGoodPrice = _currentPrice;
        emit LastGoodPriceUpdated(_currentPrice);
    }


}