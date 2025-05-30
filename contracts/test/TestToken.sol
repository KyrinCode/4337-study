// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestToken20 is ERC20 {
    constructor() ERC20("TestToken20", "TST20") {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

contract TestToken721 is ERC721 {
    constructor() ERC721("TestToken721", "TST721") {}

    function mint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }
}

contract TestToken1155 is ERC1155 {
    constructor() ERC1155("https://justfortest/{id}.json") {}

    function mint(uint256 tokenId, uint256 amount) public {
        _mint(msg.sender, tokenId, amount, "");
    }
}
