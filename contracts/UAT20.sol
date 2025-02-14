// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract UAT20 is ERC20, ERC20Burnable, AccessControl, ERC20Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    mapping (address => uint256) public all_chain_balance;
    mapping (address => uint256) public single_balance;
    mapping (address => uint256) public balance_used;
    mapping (address => uint256) public tmp_used;
    mapping (bytes32 => uint256) public pending_transfers;

    constructor(address defaultAdmin, address minter)
        ERC20("UAT20", "UAT")
        ERC20Permit("UAT20")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _decrease_limit(address to, uint256 amount) private {
        require(amount <= balanceOf(to), "out of balance");
        _burn(to, amount);
        single_balance[to] += amount;
    }

    function decrease_limit(address to, uint256 amount) public onlyRole(RELAYER_ROLE) {
        _decrease_limit(to, amount);
    }

    function decrease_limit(uint256 amount) public {
        _decrease_limit(msg.sender, amount);
    }

    function _request_increase_limit(address to, uint256 amount) private {
        tmp_used[to] += amount;
        emit IncreaseLimitRequest(to, amount);
    }

    function request_increase_limit(address to, uint256 amount) public onlyRole(RELAYER_ROLE) {
        _request_increase_limit(to, amount);
    }

    function request_increase_limit(uint256 amount) public {
         _request_increase_limit(msg.sender, amount);
    }

    function _cancle_increase(address to, uint256 amount) private {
        require(amount <= tmp_used[to], "out of request");
        tmp_used[to] -= amount;
        emit IncreaseCancled(to, amount);
    }

     function cancle_increase(address to, uint256 amount) public onlyRole(RELAYER_ROLE) {
        _cancle_increase(to, amount);
    }

    function cancle_increase(uint256 amount) public {
        _cancle_increase(msg.sender, amount);
    }

    // _proof: zk proof
    function _increase_limit(address to, uint256 amount, bytes memory) private {
        require(amount <= tmp_used[to], "out of request");
        // todo: verify _proof
        _mint(to, amount);
        balance_used[to] += amount;
        tmp_used[to] -= amount;
    }

    function increase_limit(address to, uint256 amount, bytes memory _proof) public onlyRole(RELAYER_ROLE) {
        _increase_limit(to, amount, _proof);
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20)
    {
        if (amount <= balanceOf(from)) {
            super._update(from, to, amount);
        } else {
            bytes32 h = keccak256(abi.encode(from, to, amount));
            pending_transfers[h] += 1;
            emit PendingTransfer(from, to, amount, balanceOf(from));
        }
    }

    function finishTransfer(address from, address to, uint256 amount) public {
        bytes32 h = keccak256(abi.encode(from, to, amount));
        require(pending_transfers[h] > 0, "not found");
        require(balanceOf(from) >= amount, "Out of Balance");
        pending_transfers[h] -= 1;
        super._update(from, to, amount);
        emit TransferFinish(from, to, amount);
    }

    function _updateAllchainBalance(address to, uint256 amount, bytes memory) private {
        // todo: verify proof
        all_chain_balance[to] = amount;
    }

    function updateAllchainBalance(address to, uint256 amount, bytes memory _proof)  public onlyRole(RELAYER_ROLE) {
        _updateAllchainBalance(to, amount, _proof);
    }

    event IncreaseLimitRequest(address indexed to, uint256 value);
    event IncreaseCancled(address indexed to, uint256 value);
    event PendingTransfer(address from, address to, uint256 value, uint256 balance);
    event TransferFinish(address from, address to, uint256 amount);
}
