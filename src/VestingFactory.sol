// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.13;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {IVesting} from "src/interfaces/IVesting.sol";

/*//////////////////////////////////////////////////////////////
                        CUSTOM ERROR
//////////////////////////////////////////////////////////////*/

error NoAccess();
error ZeroAddress();
error ZeroAmount();
error StartLessThanNow();
error AmountMoreThanBalance();
error AlreadyExists();

/*//////////////////////////////////////////////////////////////
                          CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title Vesting Factory Contract
/// @author jkthms (https://github.com/jkthms)

contract VestingFactory {
    // Address of the treasury contract
    address public treasury;

    // Vesting implementation
    address public vesting;

    // Interface of token contract
    IERC20 public token;

    // A mapping between the recipient address and the corresponding vesting contract address
    mapping(address => address) public recipientVesting;
    // List of all the vesting addresses created
    address[] public vestingAddresses;

    constructor(address _treasury, address _vesting, address _token) {
        treasury = _treasury;
        vesting = _vesting;
        token = IERC20(_token);
    }

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert NoAccess();
        _;
    }

    /// @notice Create a new vesting to a receipient starting from now with the duration and amount of tokens.
    /// @dev Can only be called by the treasury.
    /// @param _recipient Address of the recipient.
    /// @param _duration Duration of the vesting period.
    /// @param _amount Total amount of tokens which are going to be vested.
    function createVestingFromNow(address _recipient, uint40 _duration, uint256 _amount, bool _isCancellable)
        external
        onlyTreasury
        returns (address vestingAddress)
    {
        if (_recipient == address(0)) revert ZeroAddress();
        if (_amount < 1) revert ZeroAmount();
        if (_amount > token.balanceOf(address(this))) revert AmountMoreThanBalance();
        if (recipientVesting[_recipient] != address(0)) revert AlreadyExists();

        vestingAddress = Clones.clone(vesting);
        recipientVesting[_recipient] = vestingAddress;
        vestingAddresses.push(vestingAddress);

        IVesting(vestingAddress).initialise(_recipient, uint40(block.timestamp), _duration, _amount, _isCancellable);
        token.transfer(vestingAddress, _amount);
    }

    /// @notice Create a new vesting to a recipient starting from a particular time with the duration and amount of tokens.
    /// @dev Can only be called by the treasury.
    /// @param _recipient Address of the recipient.
    /// @param _start Starting time of the vesting.
    /// @param _duration Duration of the vesting period.
    /// @param _amount Total amount of tokens which are going to be vested.
    function createVestingStartingFrom(
        address _recipient,
        uint40 _start,
        uint40 _duration,
        uint256 _amount,
        bool _isCancellable
    ) external onlyTreasury returns (address vestingAddress) {
        if (_recipient == address(0)) revert ZeroAddress();
        if (_start < block.timestamp) revert StartLessThanNow();
        if (_amount < 1) revert ZeroAmount();
        if (_amount > token.balanceOf(address(this))) revert AmountMoreThanBalance();
        if (recipientVesting[_recipient] != address(0)) revert AlreadyExists();

        vestingAddress = Clones.clone(vesting);
        recipientVesting[_recipient] = vestingAddress;
        vestingAddresses.push(vestingAddress);

        IVesting(vestingAddress).initialise(_recipient, _start, _duration, _amount, _isCancellable);
        token.transfer(vestingAddress, _amount);
    }

    /// @notice Changes the address of the treasury.
    /// @dev Can only be called by the treasury.
    /// @param _newTreasury Address of the new treasury.
    function changeTreasury(address _newTreasury) external onlyTreasury {
        if (_newTreasury == address(0)) revert ZeroAddress();
        treasury = _newTreasury;
    }

    function withdraw(address _token) external onlyTreasury {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance > 0) IERC20(_token).transfer(treasury, balance);
    }

    function changeRecipient(address _oldRecipient, address _newRecipient) external {
        if ((_oldRecipient == address(0)) || (_newRecipient == address(0))) revert ZeroAddress();
        if (recipientVesting[_oldRecipient] != msg.sender) revert NoAccess();
        if (recipientVesting[_newRecipient] != address(0)) revert AlreadyExists();
        recipientVesting[_oldRecipient] = address(0);
        recipientVesting[_newRecipient] = msg.sender;
    }

    function claim() external {
        for (uint256 i = 0; i < vestingAddresses.length;) {
            address v = vestingAddresses[i];
            if (!IVesting(v).cancelled()) {
                if (IVesting(v).totalClaimedAmount() < IVesting(v).amount()) {
                    IVesting(v).claim();
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
