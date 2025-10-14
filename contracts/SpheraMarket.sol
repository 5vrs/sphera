// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SpheraMarket is ERC1155Holder, ReentrancyGuard, Ownable {
    // NFT contract interface
    IERC1155 public nftContract;
    
    // Fee percentage (in basis points: 250 = 2.5%)
    uint256 public marketFee = 250;
    
    // Listing structure
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerItem;
        bool active;
    }
    
    // Trade listing structure
    struct TradeListing {
        address seller;
        uint256 tokenId;
        bool active;
    }
    
    // Trade offer structure
    struct TradeOffer {
        address buyer;
        uint256[] offerTokenIds;
        bool active;
    }
    
    // Mapping of listingId to Listing
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId = 1;
    
    // Mapping of tradeListingId to TradeListing
    mapping(uint256 => TradeListing) public tradeListings;
    uint256 public nextTradeListingId = 1;
    
    // Mapping for trade offers (tradeListingId => offerId => TradeOffer)
    mapping(uint256 => mapping(uint256 => TradeOffer)) public tradeOffers;
    mapping(uint256 => uint256) public tradeOffersCount;
    
    // Events
    event ItemListed(uint256 indexed listingId, address indexed seller, uint256 indexed tokenId, uint256 amount, uint256 pricePerItem);
    event ItemSold(uint256 indexed listingId, address indexed buyer, address indexed seller, uint256 tokenId, uint256 amount, uint256 totalPrice);
    event ListingCancelled(uint256 indexed listingId);
    event MarketFeeChanged(uint256 newFee);
    
    // Trade events
    event ItemListedForTrade(uint256 indexed listingId, address indexed seller, uint256 indexed tokenId);
    event TradeOfferMade(uint256 indexed listingId, uint256 indexed offerId, address indexed buyer, uint256[] offerTokenIds);
    event TradeOfferAccepted(uint256 indexed listingId, uint256 indexed offerId);
    event TradeOfferRejected(uint256 indexed listingId, uint256 indexed offerId);
    event TradeListingCancelled(uint256 indexed listingId);
    
    constructor(address _nftContract) Ownable(0x75fC5aFeD0316aC283f746a3F4BB9C1f95FFCEb0) {
        nftContract = IERC1155(_nftContract);
    }
    
    // List an item for sale
    function listItem(uint256 tokenId, uint256 amount, uint256 pricePerItem) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        require(pricePerItem > 0, "Price must be greater than zero");
        
        // Check if NFT is already listed for trade
        for (uint256 i = 1; i < nextTradeListingId; i++) {
            if (tradeListings[i].active && tradeListings[i].seller == msg.sender && tradeListings[i].tokenId == tokenId) {
                revert("NFT is already listed for trade");
            }
        }
        
        // Check if seller has enough tokens and has approved the marketplace
        require(nftContract.balanceOf(msg.sender, tokenId) >= amount, "Insufficient token balance");
        
        // Transfer the NFT from the seller to the marketplace contract
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        
        // Create the listing
        listings[nextListingId] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            amount: amount,
            pricePerItem: pricePerItem,
            active: true
        });
        
        emit ItemListed(nextListingId, msg.sender, tokenId, amount, pricePerItem);
        nextListingId++;
    }
    
    // Buy a listed item
    function buyItem(uint256 listingId, uint256 amount) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        
        require(listing.active, "Listing is not active");
        require(amount > 0 && amount <= listing.amount, "Invalid amount");
        
        uint256 totalPrice = listing.pricePerItem * amount;
        require(msg.value >= totalPrice, "Insufficient funds sent");
        
        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
        }
        
        // Calculate fee and seller payment
        uint256 fee = (totalPrice * marketFee) / 10000;
        uint256 sellerPayment = totalPrice - fee;
        
        // Transfer NFT to buyer
        nftContract.safeTransferFrom(address(this), msg.sender, listing.tokenId, amount, "");
        
        // Transfer payment to seller
        (bool success, ) = payable(listing.seller).call{value: sellerPayment}("");
        require(success, "Failed to send funds to seller");
        
        emit ItemSold(listingId, msg.sender, listing.seller, listing.tokenId, amount, totalPrice);
        
        // Refund excess ETH
        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - totalPrice}("");
            require(refundSuccess, "Failed to refund excess");
        }
    }
    
    // Cancel a listing
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        
        require(listing.active, "Listing is not active");
        require(listing.seller == msg.sender, "Not the seller");
        
        // Transfer NFT back to seller
        nftContract.safeTransferFrom(address(this), msg.sender, listing.tokenId, listing.amount, "");
        
        // Deactivate listing
        listing.active = false;
        listing.amount = 0;
        
        emit ListingCancelled(listingId);
    }
    
    // List an item for trade
    function listItemForTrade(uint256 tokenId) external nonReentrant {
        // Check if NFT is already listed for sale
        for (uint256 i = 1; i < nextListingId; i++) {
            if (listings[i].active && listings[i].seller == msg.sender && listings[i].tokenId == tokenId) {
                revert("NFT is already listed for sale");
            }
        }
        
        // Check if NFT is already listed for trade
        for (uint256 i = 1; i < nextTradeListingId; i++) {
            if (tradeListings[i].active && tradeListings[i].seller == msg.sender && tradeListings[i].tokenId == tokenId) {
                revert("NFT is already listed for trade");
            }
        }
        
        require(nftContract.balanceOf(msg.sender, tokenId) >= 1, "Insufficient token balance");
        
        // Transfer the NFT from the seller to the marketplace contract
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId, 1, "");
        
        // Create the trade listing
        tradeListings[nextTradeListingId] = TradeListing({
            seller: msg.sender,
            tokenId: tokenId,
            active: true
        });
        
        emit ItemListedForTrade(nextTradeListingId, msg.sender, tokenId);
        nextTradeListingId++;
    }
    
    // Make a trade offer
    function makeTradeOffer(uint256 tradeListingId, uint256[] calldata offerTokenIds) external nonReentrant {
        TradeListing storage listing = tradeListings[tradeListingId];
        
        require(listing.active, "Trade listing is not active");
        require(offerTokenIds.length > 0, "Must offer at least one token");
        require(listing.seller != msg.sender, "Cannot make offers on your own listing");
        
        // Check token balances and transfer tokens to contract
        for (uint256 i = 0; i < offerTokenIds.length; i++) {
            require(nftContract.balanceOf(msg.sender, offerTokenIds[i]) >= 1, "Insufficient token balance");
            nftContract.safeTransferFrom(msg.sender, address(this), offerTokenIds[i], 1, "");
        }
        
        // Create the offer
        uint256 offerId = tradeOffersCount[tradeListingId];
        tradeOffers[tradeListingId][offerId] = TradeOffer({
            buyer: msg.sender,
            offerTokenIds: offerTokenIds,
            active: true
        });
        
        tradeOffersCount[tradeListingId]++;
        
        emit TradeOfferMade(tradeListingId, offerId, msg.sender, offerTokenIds);
    }
    
    // Accept a trade offer
    function acceptTradeOffer(uint256 tradeListingId, uint256 offerId) external nonReentrant {
        TradeListing storage listing = tradeListings[tradeListingId];
        TradeOffer storage offer = tradeOffers[tradeListingId][offerId];
        
        require(listing.active, "Trade listing is not active");
        require(offer.active, "Trade offer is not active");
        require(listing.seller == msg.sender, "Not the seller");
        
        // Transfer the listed NFT to the buyer
        nftContract.safeTransferFrom(address(this), offer.buyer, listing.tokenId, 1, "");
        
        // Transfer the offered NFTs to the seller
        for (uint256 i = 0; i < offer.offerTokenIds.length; i++) {
            nftContract.safeTransferFrom(address(this), msg.sender, offer.offerTokenIds[i], 1, "");
        }
        
        // Deactivate the listing and the accepted offer
        listing.active = false;
        offer.active = false;
        
        // Return NFTs for all other active offers
        for (uint256 i = 0; i < tradeOffersCount[tradeListingId]; i++) {
            if (i != offerId && tradeOffers[tradeListingId][i].active) {
                TradeOffer storage otherOffer = tradeOffers[tradeListingId][i];
                
                // Return NFTs to other offerers
                for (uint256 j = 0; j < otherOffer.offerTokenIds.length; j++) {
                    nftContract.safeTransferFrom(address(this), otherOffer.buyer, otherOffer.offerTokenIds[j], 1, "");
                }
                
                otherOffer.active = false;
            }
        }
        
        emit TradeOfferAccepted(tradeListingId, offerId);
    }
    
    // Reject a trade offer
    function rejectTradeOffer(uint256 tradeListingId, uint256 offerId) external nonReentrant {
        TradeListing storage listing = tradeListings[tradeListingId];
        TradeOffer storage offer = tradeOffers[tradeListingId][offerId];
        
        require(listing.active, "Trade listing is not active");
        require(offer.active, "Trade offer is not active");
        require(listing.seller == msg.sender, "Not the seller");
        
        // Return NFTs to the offerer
        for (uint256 i = 0; i < offer.offerTokenIds.length; i++) {
            nftContract.safeTransferFrom(address(this), offer.buyer, offer.offerTokenIds[i], 1, "");
        }
        
        // Deactivate the offer
        offer.active = false;
        
        emit TradeOfferRejected(tradeListingId, offerId);
    }
    
    // Cancel a trade listing
    function cancelTradeListing(uint256 tradeListingId) external nonReentrant {
        TradeListing storage listing = tradeListings[tradeListingId];
        
        require(listing.active, "Trade listing is not active");
        require(listing.seller == msg.sender, "Not the seller");
        
        // Transfer NFT back to seller
        nftContract.safeTransferFrom(address(this), msg.sender, listing.tokenId, 1, "");
        
        // Return NFTs from all active offers
        for (uint256 i = 0; i < tradeOffersCount[tradeListingId]; i++) {
            TradeOffer storage offer = tradeOffers[tradeListingId][i];
            
            if (offer.active) {
                for (uint256 j = 0; j < offer.offerTokenIds.length; j++) {
                    nftContract.safeTransferFrom(address(this), offer.buyer, offer.offerTokenIds[j], 1, "");
                }
                
                offer.active = false;
            }
        }
        
        // Deactivate listing
        listing.active = false;
        
        emit TradeListingCancelled(tradeListingId);
    }
    
    // Get trade listing details
    function getTradeListing(uint256 tradeListingId) external view returns (
        address seller,
        uint256 tokenId,
        bool active,
        uint256 offerCount
    ) {
        TradeListing storage listing = tradeListings[tradeListingId];
        return (
            listing.seller,
            listing.tokenId,
            listing.active,
            tradeOffersCount[tradeListingId]
        );
    }
    
    // Get trade offer details
    function getTradeOffer(uint256 tradeListingId, uint256 offerId) external view returns (
        address buyer,
        uint256[] memory tokenIds,
        bool active
    ) {
        TradeOffer storage offer = tradeOffers[tradeListingId][offerId];
        return (
            offer.buyer,
            offer.offerTokenIds,
            offer.active
        );
    }
    
    // Get the total number of trade listings
    function getTradeListingCount() external view returns (uint256) {
        return nextTradeListingId - 1;
    }
    
    // Set marketplace fee (owner only)
    function setMarketFee(uint256 _marketFee) external onlyOwner {
        require(_marketFee <= 1000, "Fee too high"); // Max 10%
        marketFee = _marketFee;
        emit MarketFeeChanged(_marketFee);
    }
    
    // Withdraw accumulated fees (owner only)
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    // Get all active listings (view function)
    function getActiveListing(uint256 listingId) external view returns (
        address seller, 
        uint256 tokenId, 
        uint256 amount, 
        uint256 pricePerItem, 
        bool active
    ) {
        Listing storage listing = listings[listingId];
        return (
            listing.seller,
            listing.tokenId,
            listing.amount,
            listing.pricePerItem,
            listing.active
        );
    }
    
    // Get the total number of listings for pagination
    function getListingCount() external view returns (uint256) {
        return nextListingId - 1;
    }
}