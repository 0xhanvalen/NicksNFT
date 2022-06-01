//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract NickNFT is ERC721A {
    using Strings for uint256;

    struct ThisData {
        bool isPublicSale;
        bool isPreSale;
        bool isRevealed;
        uint16 totalSupply;
        uint16 totalMinted;
        uint16 presaleSupply;
        string baseURI;
        string unrevealedURI;
        bytes32 boardedList;
        bytes32 doubleList;
        bytes32 premintList;
        uint256 publicMintPrice;
        uint256 presaleMintPrice;
        uint256 amountHeld;
        address owner;
        mapping(address => uint8) publicMintCounter;
        mapping(address => uint8) presaleMintCounter;
    }

    ThisData thisData;

    constructor() ERC721A("NickNFT", "NNFT") {
        thisData.isPublicSale = false;
        thisData.isPreSale = false;
        thisData.isRevealed = false;
        thisData.totalSupply = 10000;
        thisData.totalMinted = 0;
        thisData.presaleSupply = 2000;
        thisData.baseURI = "";
        thisData.unrevealedURI = "https://skatebirds.s3.us-west-1.amazonaws.com/prereveal/prereveal.json";
        thisData.boardedList = 0x0;
        thisData.doubleList = 0x0;
        thisData.premintList = 0x0;
        thisData.owner = msg.sender;
        thisData.publicMintPrice = 0.125 ether;
        thisData.presaleMintPrice = 0.099 ether;
    }

    modifier isPublicSale() {
        require(thisData.isPublicSale == true, "Not Minting");
        _;
    }

    modifier isPreSale() {
        require(thisData.isPreSale == true, "Not Minting");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == thisData.owner, "Not Owner");
        _;
    }

    /**
    @notice uint controls list to update - 0: boarded, 1: double, 2: premint
     */
    function setAllowList(bytes32 _root, uint8 list) external onlyOwner {
        if (list == 0) {
            thisData.boardedList = _root;
        }
        if (list == 1) {
            thisData.doubleList = _root;
        }
        if (list == 0) {
            thisData.premintList = _root;
        }
    }

    function setPublicSale(bool _newVal) external onlyOwner {
        thisData.isPublicSale = _newVal;
    }

    function setPreSale(bool _newVal) external onlyOwner {
        thisData.isPreSale = _newVal;
    }

    function setReveal(bool _newVal) external onlyOwner {
        thisData.isRevealed = _newVal;
    }

    function setBaseURI(string calldata _newURI) external onlyOwner {
        thisData.baseURI = _newURI;
    }

    function setUnrevealedURI(string calldata _newURI) external onlyOwner {
        thisData.unrevealedURI = _newURI;
    }

    function publicMint(uint8 quantity) external payable isPublicSale {
        uint256 value = msg.value;
        address minter = msg.sender;
        require(
            value >= (thisData.publicMintPrice * quantity),
            "Not Enough ETH"
        );
        require(
            thisData.publicMintCounter[minter] + quantity <= 3,
            "Too Many Mints"
        );
        require(
            thisData.totalMinted + quantity <= thisData.totalSupply,
            "Overflow ID"
        );
        thisData.publicMintCounter[minter] += quantity;
        thisData.totalMinted += quantity;
        // _safeMint's second argument now takes in a quantity, not a tokenId.
        thisData.amountHeld = value;
        _safeMint(minter, quantity);
    }

    function boardedOrDoubleMint(
        uint8 _quantity,
        bytes32[] calldata _merkleProof,
        bool boardedMint
    ) external payable isPreSale {
        uint256 value = msg.value;
        address minter = msg.sender;

        require(
            thisData.totalMinted + _quantity >= thisData.presaleSupply,
            "Out of wl"
        );
        bytes32 leaf = keccak256(abi.encodePacked(minter));
        if (boardedMint) {
            bool isBoarded = MerkleProof.verify(
                _merkleProof,
                thisData.boardedList,
                leaf
            );
            require(isBoarded, "No wl");
            require(_quantity <= 1, "Too many mints");
            require(
                thisData.presaleMintCounter[minter] + _quantity <= 1,
                "Too many mints"
            );
        }
        if (!boardedMint) {
            bool isDouble = MerkleProof.verify(
                _merkleProof,
                thisData.doubleList,
                leaf
            );
            require(isDouble, "no wl");

            require(_quantity <= 1, "Too many mints");
            require(
                thisData.presaleMintCounter[minter] + _quantity <= 1,
                "Too many mints"
            );
        }
        thisData.presaleMintCounter[minter] += _quantity;
        thisData.totalMinted += _quantity;
        require(value >= 0.099 ether * _quantity, "wrong price");
        thisData.amountHeld = value;
        _safeMint(minter, _quantity);
    }

    function preMint(uint8 _quantity, bytes32[] calldata _merkleProof)
        external
        payable
        isPreSale
    {
        uint256 value = msg.value;
        address minter = msg.sender;
        require(_quantity <= 2, "Too many mints");
        require(
            thisData.presaleMintCounter[minter] + _quantity <= 2,
            "Too many mints"
        );
        require(
            thisData.totalMinted + _quantity >= thisData.presaleSupply,
            "Out of wl"
        );
        bytes32 leaf = keccak256(abi.encodePacked(minter));
        bool ispreMint = MerkleProof.verify(
            _merkleProof,
            thisData.premintList,
            leaf
        );
        require(ispreMint, "No wl");
        thisData.presaleMintCounter[minter] += _quantity;
        thisData.totalMinted += _quantity;
        require(value >= _quantity * 0.125 ether, "wrong price");
        thisData.amountHeld = value;
        _safeMint(minter, _quantity);
    }

    function tokenURI(uint256 _tokenID)
        public
        view
        override
        returns (string memory)
    {
        require(_tokenID <= thisData.totalMinted, "Unreal Token");
        if (thisData.isRevealed) {
            return
                string(abi.encodePacked(thisData.baseURI, _tokenID.toString()));
        } else {
            return string(abi.encodePacked(thisData.unrevealedURI));
        }
    }

    function withdraw() external payable onlyOwner {
        address withdrawTarget = msg.sender;
        uint256 amountToSend = thisData.amountHeld;
        thisData.amountHeld = 0;
        payable(withdrawTarget).transfer(amountToSend);
    }
}
