// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev Extension of {ERC20} that allows to implement a custodian
 * mechanism that can be managed by an authorized account with the
 * {freeze} function.
 *
 * This mechanism allows a custodian (e.g. a DAO or a
 * well-configured multisig) to freeze and unfreeze the balance
 * of a user.
 *
 * The frozen balance is not available for transfers or approvals
 * to other entities to operate on its behalf if. The frozen balance
 * can be reduced by calling {freeze} again with a lower amount.
 *
 * IMPORTANT: Deprecated. Use {ERC20Freezable} instead.
 */
abstract contract ERC20Custodian is ERC20 {
    /**
     * @dev The amount of tokens frozen by user address.
     */
    mapping(address user => uint256 amount) private _frozen;

    /**
     * @dev Emitted when tokens are frozen for a user.
     * @param user The address of the user whose tokens were frozen.
     * @param amount The amount of tokens that were frozen.
     */
    event TokensFrozen(address indexed user, uint256 amount);

    /**
     * @dev Emitted when tokens are unfrozen for a user.
     * @param user The address of the user whose tokens were unfrozen.
     * @param amount The amount of tokens that were unfrozen.
     */
    event TokensUnfrozen(address indexed user, uint256 amount);

    /**
     * @dev Emitted when frozen tokens are unfrozen and burned for a user.
     * @param user The address of the user whose tokens were unfrozen and burned.
     * @param amount The amount of tokens that were unfrozen and burned.
     */
    event TokensUnfrozenAndBurned(address indexed user, uint256 amount);

    /**
     * @dev The operation failed because the user has insufficient unfrozen balance.
     */
    error ERC20InsufficientUnfrozenBalance(address user);

    /**
     * @dev The operation failed because the user has insufficient frozen balance.
     */
    error ERC20InsufficientFrozenBalance(address user);

    /**
     * @dev Error thrown when a non-custodian account attempts to perform a custodian-only operation.
     */
    error ERC20NotCustodian();

    /**
     * @dev Modifier to restrict access to custodian accounts only.
     */
    modifier onlyCustodian() {
        if (!_isCustodian(_msgSender())) revert ERC20NotCustodian();
        _;
    }

    /**
     * @dev Incrementally freezes additional tokens for a user.
     * @param user The address of the user whose tokens to freeze.
     * @param amount The amount of additional tokens to freeze.
     *
     * Requirements:
     *
     * - The user must have sufficient unfrozen balance for the additional amount.
     */
    function freeze(address user, uint256 amount) external virtual onlyCustodian {
        if (amount == 0) return;

        uint256 available = availableBalance(user);
        if (available < amount) revert ERC20InsufficientUnfrozenBalance(user);

        _frozen[user] += amount;
        emit TokensFrozen(user, amount);
    }

    /**
     * @dev Unfreezes tokens for a user.
     * @param user The address of the user whose tokens to unfreeze.
     * @param amount The amount of tokens to unfreeze.
     *
     * Requirements:
     *
     * - The caller must be a custodian.
     * - The user must have sufficient frozen balance.
     */
    function unfreeze(address user, uint256 amount) external virtual onlyCustodian {
        _unfreeze(user, amount);
    }

    /**
     * @dev Unfreezes and burns tokens for a user.
     * The tokens are first unfrozen from the user's frozen balance, then burned.
     * @param user The address of the user whose tokens to unfreeze and burn.
     * @param amount The amount of tokens to unfreeze and burn.
     *
     * Requirements:
     *
     * - The caller must be a custodian.
     * - The user must have sufficient frozen balance.
     */
    function unfreezeAndBurn(address user, uint256 amount) external virtual onlyCustodian {
        _unfreeze(user, amount);
        _burn(user, amount);
        emit TokensUnfrozenAndBurned(user, amount);
    }

    /**
     * @dev Returns the amount of tokens frozen for a user.
     */
    function frozen(address user) public view virtual returns (uint256) {
        return _frozen[user];
    }

    /**
     * @dev Returns the available (unfrozen) balance of an account.
     * @param account The address to query the available balance of.
     * @return available The amount of tokens available for transfer.
     */
    function availableBalance(address account) public view returns (uint256 available) {
        available = balanceOf(account) - frozen(account);
    }

    /**
     * @dev Checks if the user is a custodian.
     * @param user The address of the user to check.
     * @return True if the user is authorized, false otherwise.
     */
    function _isCustodian(address user) internal view virtual returns (bool);

    /**
     * @dev Internal function to unfreeze tokens for a user.
     * @param user The address of the user whose tokens to unfreeze.
     * @param amount The amount of tokens to unfreeze.
     *
     * Requirements:
     *
     * - The user must have sufficient frozen balance.
     */
    function _unfreeze(address user, uint256 amount) internal virtual {
        if (amount == 0) return;

        uint256 currentFrozen = _frozen[user];
        if (currentFrozen < amount) revert ERC20InsufficientFrozenBalance(user);

        _frozen[user] -= amount;
        emit TokensUnfrozen(user, amount);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && availableBalance(from) < value) revert ERC20InsufficientUnfrozenBalance(from);
        super._update(from, to, value);
    }
}
