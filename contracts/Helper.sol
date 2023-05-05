pragma solidity ^0.8.9;


contract EncodedCall{
bytes public  data;

function encodewithsignature(uint256 _a,uint256 _b) public returns(bytes memory) {
      data= abi.encodeWithSignature("add(uint256,uint256)",_a,_b);
      return data;
}
function test(address _contract,bytes calldata data) external {

    (bool ok,)=_contract.call(data);
    require(ok, "call failed");
}
function keccak2566() public returns(bytes32){
    return keccak256("");
}
}