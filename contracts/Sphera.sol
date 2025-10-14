// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Pausable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Sphera is ERC1155, Ownable, ERC1155Pausable, ERC1155Supply {
    string public name = "Sphera Collection";
    uint256 public price =  0.01 ether;
    uint256 public supplyLimit = 1;
    bool public allowMint = true;
 
    constructor() 
        ERC1155("ipfs://bafybeihlluxsxvi2le6kh5josgvsxtynbvwjszbgmy5wgqoxfauymrv6ni")
        Ownable(0x75fC5aFeD0316aC283f746a3F4BB9C1f95FFCEb0)
    {}

    // Allows the owner to edit the minting window 
    function editMintWindow(bool _allowMint) external onlyOwner {
        allowMint = _allowMint;
    }
    
    // Allows the owner to edit the URI 
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
    
    // Allows the owner to pause contract
    function pause() public onlyOwner {
        _pause();
    }

    // Allows the owner to unpause contract
    function unpause() public onlyOwner {
        _unpause();
    }

    // Check the amount of boots in a wallet, and checks if amount minted will cause overflow
    function _checkWalletLimit(address account) internal view {
        uint256 total;
        for (uint256 i = 1; i <= 256; i++) {
            total += balanceOf(account, i);
        }
        require(total + 1 <= 15, "ERROR -> Wallet Can Hold Maximum 15 Boots!");
    }

   // Mint function that randomly selects an available NFT ID
    function mint() public payable {
        require(allowMint, "ERROR -> Minting Window Closed!");
        require(msg.value == price, "ERROR -> Invalid ether sent!");
        _checkWalletLimit(msg.sender);
        
        // Find an available token ID randomly
        uint256 id = findAvailableTokenId();
        require(id > 0, "ERROR -> No available NFTs to mint");
        
        _mint(msg.sender, id, 1, "");
    }
    
    // Helper function to find an available token ID
    function findAvailableTokenId() internal view returns (uint256) {
        // Generate a pseudo-random seed
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            blockhash(block.number - 1),
            msg.sender,
            gasleft()
        )));
        
        // Start with a random position
        uint256 startId = (seed % 256) + 1;
        
        // Search sequentially from the random starting point
        for (uint256 i = 0; i < 256; i++) {
            uint256 id = ((startId + i) % 256) + 1;
            if (totalSupply(id) + 1 <= supplyLimit) {
                return id;
            }
        }
        
        return 0; // No available token found
    }

    // Allows for the minting of multiple boots at once
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner{
        _mintBatch(to, ids, amounts, data);
    }

    // Withdraw function, allows owner to withdraw all ether in contract
    function withdraw(address _addr) external onlyOwner {
        uint256 balance = address(this).balance;
        payable(_addr).transfer(balance);
    }


function uri(uint256 _id) public view virtual override returns (string memory) {
    require(exists(_id), "ERROR -> URI : Nonexistent Token");
    
    // Make sure there's a separator (/) between base URI and token ID
    string memory baseURI = super.uri(_id);
    // If the baseURI doesn't end with a slash, add one
    if (bytes(baseURI).length > 0 && bytes(baseURI)[bytes(baseURI).length - 1] != bytes1('/')) {
        return string(abi.encodePacked(baseURI, "/", Strings.toString(_id), ".json"));
    }
    return string(abi.encodePacked(baseURI, Strings.toString(_id), ".json"));
}


    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

}