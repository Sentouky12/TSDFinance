// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IERC2612.sol";


interface ITSDToken is IERC20, IERC2612{

function mint(address _account, uint256 _amount) external;

function burn(address _account, uint256 _amount) external;


}

