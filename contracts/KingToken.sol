// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract King is ERC20 {


 mapping (address => uint) public wards;
    function rely(address guy) external auth { wards[guy] = 1; }
    function deny(address guy) external auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "TSD/not-authorized");
        _;
    }
    

    constructor(uint256 initialSupply) ERC20("King", "KING") {
        _mint(msg.sender, initialSupply);
        wards[msg.sender]=1;
    }
    function mint(address who, uint256 amount) public auth{
     _mint(who,amount);
    }
}