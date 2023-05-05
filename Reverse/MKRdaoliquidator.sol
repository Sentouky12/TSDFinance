/**
 *Submitted for verification at Etherscan.io on 2021-04-16
*/

// SPDX-License-Identifier: AGPL-3.0-or-later

/// dog.sol -- Dai liquidation module 2.0

// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.6.12;

interface ClipperLike {
    function ilk() external view returns (bytes32);
    function kick(
        uint256 tab,   //the target DAI to raise from the auction (debt + stability fees + liquidation penalty) [rad]
        uint256 lot,   //the amount of collateral available for purchase [wad]
        address usr, //the address to return any excess collateral to
        address kpr //the address where DAI incentives will be sent
    ) external returns (uint256);
}

interface VatLike {
    function ilks(bytes32) external view returns (
        uint256 Art,  //total normalized stablecoin debt.
        uint256 rate, //  stablecoin debt multiplier (accumulated stability fees).
        uint256 spot, // collateral price with safety margin, i.e. the maximum stablecoin allowed per unit of collateral.
        uint256 line, // the debt ceiling for a specific collateral type.
        uint256 dust  // the minimum possible debt of a Vault.
    );
    function urns(bytes32,address) external view returns (
        uint256 ink,  // collateral balance.
        uint256 art   // normalized outstanding stablecoin debt.
    );
    function grab(bytes32,address,address,address,int256,int256) external;
    function hope(address) external;
    function nope(address) external;
}

interface VowLike {
    function fess(uint256) external;
}

contract Dog {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth {
        require(wards[msg.sender] == 1, "Dog/not-authorized");
        _;
    }

    // --- Data ---
    struct Ilk {
        address clip;  // Liquidator
        uint256 chop;  // Liquidation Penalty                                          [wad]
        uint256 hole;  // Max DAI needed to cover debt+fees of active auctions per ilk [rad]
        uint256 dirt;  // Amt DAI needed to cover debt+fees of active auctions per ilk [rad]
    }

    VatLike immutable public vat;  // CDP Engine

    mapping (bytes32 => Ilk) public ilks;

    VowLike public vow;   // Debt Engine
    uint256 public live;  // Active Flag
    uint256 public Hole;  // Max DAI needed to cover debt+fees of active auctions [rad] (in total not just per one type of coll or ilk)
    uint256 public Dirt;  // Amt DAI needed to cover debt+fees of active auctions [rad] (in total not just per one type of coll or ilk)

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);
    event File(bytes32 indexed ilk, bytes32 indexed what, uint256 data);
    event File(bytes32 indexed ilk, bytes32 indexed what, address clip);

    event Bark(
      bytes32 indexed ilk,
      address indexed urn,
      uint256 ink,
      uint256 art,
      uint256 due,
      address clip, 
      uint256 indexed id
    );
    event Digs(bytes32 indexed ilk, uint256 rad);
    event Cage();

    // --- Init ---
    constructor(address vat_) public {
        vat = VatLike(vat_);
        live = 1;
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Administration ---
    function file(bytes32 what, address data) external auth {
        if (what == "vow") vow = VowLike(data);
        else revert("Dog/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 what, uint256 data) external auth {
        if (what == "Hole") Hole = data;
        else revert("Dog/file-unrecognized-param");
        emit File(what, data);
    }
    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        if (what == "chop") {
            require(data >= WAD, "Dog/file-chop-lt-WAD");
            ilks[ilk].chop = data;
        } else if (what == "hole") ilks[ilk].hole = data;
        else revert("Dog/file-unrecognized-param");
        emit File(ilk, what, data);
    }
    function file(bytes32 ilk, bytes32 what, address clip) external auth {
        if (what == "clip") {
            require(ilk == ClipperLike(clip).ilk(), "Dog/file-ilk-neq-clip.ilk");
            ilks[ilk].clip = clip;
        } else revert("Dog/file-unrecognized-param");
        emit File(ilk, what, clip);
    }

    function chop(bytes32 ilk) external view returns (uint256) {
        return ilks[ilk].chop;
    }

    // --- CDP Liquidation: all bark and no bite ---
    //
    // Liquidate a Vault and start a Dutch auction to sell its collateral for DAI.
    //
    // The third argument is the address that will receive the liquidation reward, if any.
    //
    // The entire Vault will be liquidated except when the target amount of DAI to be raised in
    // the resulting auction (debt of Vault + liquidation penalty) causes either Dirt to exceed
    // Hole or ilk.dirt to exceed ilk.hole by an economically significant amount. In that
    // case, a partial liquidation is performed to respect the global and per-ilk limits on
    // outstanding DAI target. The one exception is if the resulting auction would likely
    // have too little collateral to be interesting to Keepers (debt taken from Vault < ilk.dust),
    // in which case the function reverts. Please refer to the code and comments within if
    // more detail is desired.
    function bark(bytes32 ilk, address urn, address kpr) external returns (uint256 id) {
        require(live == 1, "Dog/not-live");

        (uint256 ink, uint256 art) = vat.urns(ilk, urn); //this calls vat(or the vault engine) to grab a specific vault ink(or collateral balance) 
        //and art(or stablecoin debt that needs to be multiplied by rate ))
        Ilk memory milk = ilks[ilk];
        uint256 dart; //amount of stablecoin debt to exchange
        uint256 rate;
        uint256 dust;
        {
            uint256 spot;
            (,rate, spot,, dust) = vat.ilks(ilk);
            require(spot > 0 && mul(ink, spot) < mul(art, rate), "Dog/not-unsafe"); // we require the ink(col balance) multiplied by spot(price with safety margin) to be 
                                                                                   //lower than art(stablecoin debt) multiplied by rate(stablecoin debt multiplier) in order to liquidate otherwise the vault is safe
                     //the spot price is not updated directly in the dog contract
                     //it is taken from the vat contract via an call to the ilks 
                     //mapping that is updated in the vat contract with new prices 
                     //by the oracles..                                                             

            // Get the minimum value between:
            // 1) Remaining space in the general Hole
            // 2) Remaining space in the collateral hole
            require(Hole > Dirt && milk.hole > milk.dirt, "Dog/liquidation-limit-hit");//
            uint256 room = min(Hole - Dirt, milk.hole - milk.dirt);

            // uint256.max()/(RAD*WAD) = 115,792,089,237,316
            dart = min(art, mul(room, WAD) / rate / milk.chop);//ilk.chop=Liquidation Penalty per collateral (ilk). E.g. if there is a vault ready to be liquidated 
            //that has a debt of 1,000 DAI and chop = 1.13 * WAD (13% above), then the max amount to be raised by the auction will be 1,130 DAI.
//dart or amount of stablecoin debt to exchange is calculated by min(stablecoin debt of a vault,mul(remaining space in col hole,WAD/stablecoin debt multiplier/))
            // Partial liquidation edge case logic
            if (art > dart) {
                if (mul(art - dart, rate) < dust) {

                    // If the leftover Vault would be dusty, just liquidate it entirely.
                    // This will result in at least one of dirt_i > hole_i or Dirt > Hole becoming true.
                    // The amount of excess will be bounded above by ceiling(dust_i * chop_i / WAD).
                    // This deviation is assumed to be small compared to both hole_i and Hole, so that
                    // the extra amount of target DAI over the limits intended is not of economic concern.
                    dart = art;
                } else {

                    // In a partial liquidation, the resulting auction should also be non-dusty.
                    require(mul(dart, rate) >= dust, "Dog/dusty-auction-from-partial-liquidation");
                }
            }
        }
//dink=amount of collateral to exchange.
//dart=amount of stablecoin debt to exchange.
        uint256 dink = mul(ink, dart) / art; //dink is calculated by multiplying coll balance of a vault or usr with amout of stablecoin debt to exchange and divided by the normalized stablecoin debt of that vault

        require(dink > 0, "Dog/null-auction");
        require(dart <= 2**255 && dink <= 2**255, "Dog/overflow");

        vat.grab(
            ilk, urn, milk.clip, address(vow), -int256(dink), -int256(dart)
        );

        uint256 due = mul(dart, rate);
        vow.fess(due);

        {   // Avoid stack too deep
            // This calcuation will overflow if dart*rate exceeds ~10^14
            uint256 tab = mul(due, milk.chop) / WAD;
            Dirt = add(Dirt, tab);
            ilks[ilk].dirt = add(milk.dirt, tab);

            id = ClipperLike(milk.clip).kick({ //initiates auction by calling clipper.kick.
                tab: tab,
                lot: dink,
                usr: urn,
                kpr: kpr
            });
        }

        emit Bark(ilk, urn, dink, dart, due, milk.clip, id);
    }

    function digs(bytes32 ilk, uint256 rad) external auth {
        Dirt = sub(Dirt, rad);
        ilks[ilk].dirt = sub(ilks[ilk].dirt, rad);
        emit Digs(ilk, rad);
    }

    function cage() external auth {
        live = 0;
        emit Cage();
    }
}
 