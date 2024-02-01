// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ITokenMetadataResolver} from "@animoca/ethereum-contracts/contracts/token/metadata/interfaces/ITokenMetadataResolver.sol";
import {IOperatorFilterRegistry} from "@animoca/ethereum-contracts/contracts/token/royalty/interfaces/IOperatorFilterRegistry.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {ChaosKingdomResources} from "../ERC1155/ChaosKingdomResources.sol";

contract ChaosKingdomResourcesMock is ChaosKingdomResources {
    constructor(
        ITokenMetadataResolver metadataResolver,
        IOperatorFilterRegistry filterRegistry,
        IForwarderRegistry forwarderRegistry
    ) ChaosKingdomResources(metadataResolver, filterRegistry, forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
