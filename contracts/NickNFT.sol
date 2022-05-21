//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

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
        bytes32 allowList;
        uint256 publicMintPrice;
        uint256 presaleMintPrice;
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
        thisData.unrevealedURI = "";
        thisData.allowList = 0x0;
        thisData.owner = msg.sender;
        thisData.publicMintPrice = 0.125 ether;
        thisData.presaleMintPrice = 0.099 ether;
    }

    modifier isPublicSale {
        require(thisData.isPublicSale == true, "Not Minting");
        _;
    }

    modifier isPreSale {
        require(thisData.isPreSale == true, "Not Minting");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == thisData.owner, "Not Owner");
        _;
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
        _safeMint(minter, quantity);
    }

    function presaleMint(uint8 _quantity, bytes32[] calldata _merkleProof)
        external
        payable
        isPreSale
    {
        uint256 value = msg.value;
        address minter = msg.sender;

        if (thisData.totalMinted + _quantity <= 300) {
            require(_quantity <= 2, "Too many mints");
            require(
                thisData.presaleMintCounter[minter] + _quantity <= 2,
                "Too many mints"
            );
        }
        if (thisData.totalMinted + _quantity > 300) {
            require(_quantity == 1, "Too many mints");
            require(thisData.presaleMintCounter[minter] < 1, "Too many mints");
        }
        require(
            thisData.totalMinted + _quantity >= thisData.presaleSupply,
            "Out of wl"
        );
        bytes32 leaf = keccak256(abi.encodePacked(minter));
        bool isLeaf = MerkleProof.verify(
            _merkleProof,
            thisData.allowList,
            leaf
        );
        require(isLeaf, "No wl");
        thisData.presaleMintCounter[minter] += _quantity;
        thisData.totalMinted += _quantity;
        if (thisData.totalMinted + _quantity <= 33) {
            _safeMint(minter, _quantity);
        }
        if (thisData.totalMinted + _quantity > 33) {
            require(
                value >= (_quantity * thisData.presaleMintPrice),
                "Not Enough ETH"
            );
            _safeMint(minter, _quantity);
        }
    }

    function tokenURI(uint256 _tokenID) public view override returns (string memory) {
        require(_tokenID <= thisData.totalMinted, "Unreal Token");
        if (thisData.isRevealed) {
            return string(abi.encodePacked(thisData.baseURI, _tokenID.toString()));
        } else {
            return string(abi.encodePacked(thisData.unrevealedURI));
        }
    }
}
