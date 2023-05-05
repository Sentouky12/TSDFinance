// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/ITSDToken.sol";
import "../extensions/IERC20Metadata.sol";
import "../utils/Context.sol";
//import "../Dependencies/CheckContract.sol";
//import "../Dependencies/console.sol";
/*
*
* Based upon OpenZeppelin's ERC20 contract:
* https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol
*  
* and their EIP2612 (ERC20Permit / ERC712) functionality:
* https://github.com/OpenZeppelin/openzeppelin-contracts/blob/53516bc555a454862470e7860a9b5254db4d00f5/contracts/token/ERC20/ERC20Permit.sol
* 
*
* --- Functionality added specific to the LUSDToken ---
* 
* 1) Transfer protection: blacklist of addresses that are invalid recipients (i.e. core Liquity contracts) in external 
* transfer() and transferFrom() calls. The purpose is to protect users from losing tokens by mistakenly sending LUSD directly to a Liquity 
* core contract, when they should rather call the right function. 
*
* 2) sendToPool() and returnFromPool(): functions callable only Liquity core contracts, which move LUSD tokens between Liquity <-> user.
*/

contract TSDToken is Context,ITSDToken,IERC20Metadata {
    
    mapping (address => uint) public wards;
    function rely(address guy) external auth { wards[guy] = 1; }
    function deny(address guy) external auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "TSD/not-authorized");
        _;
    }
    
    uint256 private _totalSupply;
    string constant internal Name = "TSD Stablecoin";
    string constant internal Symbol = "TSD";
    string constant internal Version = "1";
    uint8 constant internal  Decimals = 18;
    
    // --- Data for EIP2612 ---
    
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable cachedDomainSeparator;

    uint256 private immutable cachedChainId;

    bytes32 private immutable hashedName;
    
    bytes32 private immutable hashedVersion;
    
    mapping (address => uint256) private _nonces;
    
    // User data for LUSD token
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;  
    
    // --- Addresses ---
   
    
    // --- Events ---
    

    constructor() public 
    {  
        wards[msg.sender] = 1;
        
         hashedName = keccak256(bytes(Name));
         hashedVersion = keccak256(bytes(Version));
        
        cachedChainId = _chainID();
        cachedDomainSeparator = _buildDomainSeparator(_TYPE_HASH, hashedName, hashedVersion);
    }

    // --- Functions for intra-Liquity calls ---

    function mint(address _account, uint256 _amount) public override(IERC20,ITSDToken) auth {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) public override(IERC20,ITSDToken) auth{
       _burn(_account, _amount);
    }

   
    // --- External functions ---

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

   function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }


     function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

     function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 par=allowance(owner, spender);
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    // --- EIP 2612 Functionality ---

    function domainSeparator() public view override returns (bytes32) {    
        if (_chainID() == cachedChainId) {
            return cachedDomainSeparator;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, hashedName, hashedVersion);
        }
    }

    function permit
    (
        address owner, 
        address spender, 
        uint amount, 
        uint deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) 
        external 
        override 
    {            
        require(deadline >= block.timestamp, 'TSD: expired deadline');
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', 
                         domainSeparator(), keccak256(abi.encode(
                         _PERMIT_TYPEHASH, owner, spender, amount, 
                         _nonces[owner]++, deadline))));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, 'TSD: invalid signature');
        _approve(owner, spender, amount);
    }

    function nonces(address owner) external view override returns (uint256) { // FOR EIP 2612
        return _nonces[owner];
    }

    // --- Internal operations ---

    function _chainID() private view returns (uint256 chainID) {
        assembly {
            chainID := chainid()
        }
    }
    
    function _buildDomainSeparator(bytes32 typeHash, bytes32 name, bytes32 version) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, name, version, _chainID(), address(this)));
    }

    // --- Internal operations ---
    // Warning: sanity checks (for sender and recipient) should have been done before calling these internal functions

   function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }


    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }


     function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

     function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // --- 'require' functions ---


 function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }


  /**
     * @dev Hooks that are called before and after any transfer of tokens. This includes
     * minting and burning.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    // --- Optional functions ---

    function name() external view override returns (string memory) {
        return Name;
    }

    function symbol() external view override returns (string memory) {
        return Symbol;
    }

    function decimals() external view override returns (uint8) {
        return Decimals;
    }

    function version() external view override returns (string memory) {
        return Version;
    }

    function permitTypeHash() external view override returns (bytes32) {
        return _PERMIT_TYPEHASH;
    }
}