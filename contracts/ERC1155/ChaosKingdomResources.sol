// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {IOperatorFilterRegistry} from "@animoca/ethereum-contracts/contracts/token/royalty/interfaces/IOperatorFilterRegistry.sol";
import {ITokenMetadataResolver} from "@animoca/ethereum-contracts/contracts/token/metadata/interfaces/ITokenMetadataResolver.sol";
import {ERC1155FullBurn} from "@animoca/ethereum-contracts/contracts/token/ERC1155/preset/ERC1155FullBurn.sol";

contract ChaosKingdomResources is ERC1155FullBurn {
    constructor(
        ITokenMetadataResolver metadataResolver,
        IOperatorFilterRegistry filterRegistry,
        IForwarderRegistry forwarderRegistry
    ) ERC1155FullBurn("Chaos Kingdom Resources", "RESOURCES", metadataResolver, filterRegistry, forwarderRegistry) {}
}
