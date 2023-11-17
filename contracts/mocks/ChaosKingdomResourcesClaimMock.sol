// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC20} from "@animoca/ethereum-contracts/contracts/token/ERC20/interfaces/IERC20.sol";
import {IERC1155Mintable} from "@animoca/ethereum-contracts/contracts/token/ERC1155/interfaces/IERC1155Mintable.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {ChaosKingdomResourcesClaim} from "../payment/ChaosKingdomResourcesClaim.sol";

contract ChaosKingdomResourcesClaimMock is ChaosKingdomResourcesClaim {
    constructor(
        IERC20 feeContract_,
        IERC1155Mintable rewardContract_,
        IForwarderRegistry forwarderRegistry
    ) ChaosKingdomResourcesClaim(feeContract_, rewardContract_, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
