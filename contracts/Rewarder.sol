// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./interfaces/IRewarder.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IReliquary.sol";

contract Rewarder is IRewarder {

    using SafeERC20 for IERC20;

    uint private constant BASIS_POINTS = 10_000;
    uint public immutable rewardMultiplier;

    IERC20 public immutable rewardToken;
    IReliquary public immutable reliquary;

    uint public immutable depositBonus;
    uint public immutable minimum;
    uint public immutable cadence;

    /// @notice Mapping from relicId to timestamp of last deposit
    mapping(uint => uint) public lastDepositTime;

    modifier onlyReliquary() {
        require(msg.sender == address(reliquary), "Only Reliquary can call this function.");
        _;
    }

    /// @notice Contructor called on deployment of this contract
    /// @param _rewardMultiplier Amount to multiply reward by, relative to BASIS_POINTS
    /// @param _depositBonus Bonus owed when cadence has elapsed since lastDepositTime
    /// @param _minimum The minimum deposit amount to be eligible for depositBonus
    /// @param _cadence The minimum elapsed time since lastDepositTime
    /// @param _rewardToken Address of token rewards are distributed in
    /// @param _reliquary Address of Reliquary this rewarder will read state from
    constructor(
        uint _rewardMultiplier,
        uint _depositBonus,
        uint _minimum,
        uint _cadence,
        IERC20 _rewardToken,
        IReliquary _reliquary
    ) {
        require(_minimum != 0, "no minimum set!");
        require(_cadence >= 1 days, "please set a reasonable cadence");
        rewardMultiplier = _rewardMultiplier;
        depositBonus = _depositBonus;
        minimum = _minimum;
        cadence = _cadence;
        rewardToken = _rewardToken;
        reliquary = _reliquary;
    }

    /// @notice Called by Reliquary harvest or withdrawAndHarvest function
    /// @param relicId The NFT ID of the position
    /// @param rewardAmount Amount of reward token owed for this position from the Reliquary
    /// @param to Address to send rewards to
    function onReward(
        uint relicId,
        uint rewardAmount,
        address to
    ) external override onlyReliquary {
        if (rewardMultiplier != 0) {
            uint pendingReward = rewardAmount * rewardMultiplier / BASIS_POINTS;
            rewardToken.safeTransfer(to, pendingReward);
        }
    }

    /// @notice Called by Reliquary _deposit function
    /// @param relicId The NFT ID of the position
    /// @param depositAmount Amount being deposited into the underlying Reliquary position
    /// @param to Address to send the depositBonus to
    function onDeposit(
        uint relicId,
        uint depositAmount,
        address to
    ) external override onlyReliquary {
        if (depositAmount >= minimum) {
            uint _lastDepositTime = lastDepositTime[relicId];
            uint timestamp = block.timestamp;
            lastDepositTime[relicId] = timestamp;
            _claimDepositBonus(to, timestamp, _lastDepositTime);
        }
    }

    /// @notice Called by Reliquary withdraw or withdrawAndHarvest function
    /// @param relicId The NFT ID of the position
    /// @param withdrawalAmount Amount being withdrawn from the underlying Reliquary position
    /// @param to Address to send the depositBonus to
    function onWithdraw(
        uint relicId,
        uint withdrawalAmount,
        address to
    ) external override onlyReliquary {
        uint _lastDepositTime = lastDepositTime[relicId];
        delete lastDepositTime[relicId];
        _claimDepositBonus(to, block.timestamp, _lastDepositTime);
    }

    /// @notice Claim depositBonus without making another deposit
    /// @param relicId The NFT ID of the position
    /// @param to Address to send the depositBonus to
    function claimDepositBonus(uint relicId, address to) external {
        require(reliquary.isApprovedOrOwner(msg.sender, relicId), "not owner or approved");
        uint _lastDepositTime = lastDepositTime[relicId];
        delete lastDepositTime[relicId];
        require(_claimDepositBonus(to, block.timestamp, _lastDepositTime), "nothing to claim");
    }

    /// @dev Internal claimDepositBonus function
    /// @param to Address to send the depositBonus to
    /// @param timestamp The current timestamp, passed in for gas efficiency
    /// @param _lastDepositTime Time of last deposit into this position, before being updated
    /// @return claimed Whether depositBonus was actually claimed
    function _claimDepositBonus(
        address to,
        uint timestamp,
        uint _lastDepositTime
    ) internal returns (bool claimed) {
        if (_lastDepositTime != 0 && timestamp - _lastDepositTime >= cadence) {
            rewardToken.safeTransfer(to, depositBonus);
            claimed = true;
        } else {
            claimed = false;
        }
    }

    /// @notice Returns the amount of pending tokens for a position from this rewarder
    ///         Interface supports multiple tokens
    /// @param relicId The NFT ID of the position
    /// @param rewardAmount Amount of reward token owed for this position from the Reliquary
    function pendingTokens(
        uint relicId,
        uint rewardAmount
    ) external view override returns (IERC20[] memory rewardTokens, uint[] memory rewardAmounts) {
        rewardTokens = new IERC20[](1);
        rewardTokens[0] = rewardToken;

        uint reward = rewardAmount * rewardMultiplier / BASIS_POINTS;
        uint _lastDepositTime = lastDepositTime[relicId];
        if (_lastDepositTime != 0 && block.timestamp - _lastDepositTime >= cadence) {
            reward += depositBonus;
        }
        rewardAmounts = new uint[](1);
        rewardAmounts[0] = reward;
    }
}
