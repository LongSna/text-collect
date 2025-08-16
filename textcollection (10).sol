// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

contract TC {
    address public owner;
    uint16 public protocolTax;
    uint16 public IprotocolTax;
    uint16 public inviterTax;
    uint256 public likeFee;
    uint256 public PlikeFee;

    constructor() {
        owner = msg.sender;
        protocolTax = 30;
        IprotocolTax = 5;
        inviterTax = 10;
        likeFee = 0.03 * 1 ether;
        PlikeFee = 0.02 * 1 ether;
    }

    struct collectionAmount {
        uint256 amount;
        uint256 marketnonce;
        mapping(uint256 => market) collectionsmarket;
    }
    struct market {
        uint256 listAmount;
        uint256 price;
        bool isSuccessful;
    }

    struct textCollection {
        uint256 maxSupply;
        uint256 supply;
        uint256 perMintLimit;
        uint256 time;
        uint256 like;
        uint8 tax;
        bytes4 text;
        address deployer;
    }
    event CreatNewTextCollection(
        bytes4 text,
        address deployer,
        uint256 maxSupply,
        uint256 perMintLimit,
        uint8 tax
    );
    event Transfer(
        bytes4 text,
        uint256 amount,
        address toaddress,
        address fromAddress
    );
    event MTransfer(
        bytes4 text,
        uint256 amount,
        address toaddress,
        address fromAddress,
        uint256 marketnonce
    );
    event Mint(bytes4 text, uint256 amount, address toaddress);

    event List(bytes4 text, address lister, uint256 price, uint256 amount,uint256 marketnonce);
    event UnList(bytes4 text, address lister, uint256 marketnonce);

    mapping(bytes4 => textCollection) textCollections;
    mapping(bytes4 => mapping(address => collectionAmount)) collectionsAmount;
    mapping(address => address) addressinviter;

    modifier collectionIsExist(bytes4 text) {
        require(textCollections[text].time > 0, "not exist");
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function WprotocolTax(uint16 ntax) public onlyOwner {
        protocolTax = ntax;
    }

    function WinviteTax(uint16 ntax) public onlyOwner {
        inviterTax = ntax;
    }

    function WlikeFee(uint256 pf, uint256 df) public onlyOwner {
        PlikeFee = pf;
        likeFee = df;
    }

    function creatNewTextColloction(
        bytes4 text,
        uint256 maxSupply,
        uint256 perMintLimit,
        uint8 tax
    ) public {
        require(text.length == 4, "text.length != 4");
        require(tax < 100, "tax must be < 100");

        textCollections[text] = textCollection({
            text: text,
            maxSupply: maxSupply,
            deployer: msg.sender,
            tax: tax,
            perMintLimit: perMintLimit,
            time: block.timestamp,
            like: 0,
            supply: 0
        });

        emit CreatNewTextCollection(
            text,
            msg.sender,
            maxSupply,
            perMintLimit,
            tax
        );
    }

    function mintNewTextColloction(bytes4 text, uint256 mintAmount)
        public
        collectionIsExist(text)
    {
        require(
            textCollections[text].perMintLimit % mintAmount == 0,
            "not divisible"
        );
        require(
            textCollections[text].perMintLimit >= mintAmount,
            "over perMintLimit"
        );
        require(
            textCollections[text].maxSupply >=
                textCollections[text].supply + mintAmount,
            "over maxSupply"
        );

        collectionsAmount[text][msg.sender].amount += mintAmount;
        textCollections[text].supply += mintAmount;
        emit Mint(text, mintAmount, msg.sender);
    }

    function transferTextColloction(
        bytes4 text,
        uint256 amount,
        address toaddress
    ) public collectionIsExist(text) {
        require(
            collectionsAmount[text][msg.sender].amount >= amount,
            "over sender collection amount"
        );

        collectionsAmount[text][msg.sender].amount -= amount;
        collectionsAmount[text][toaddress].amount += amount;
        emit Transfer(text, amount, toaddress, msg.sender);
    }

    function like(bytes4 text) public payable collectionIsExist(text) {
        require(msg.value == likeFee + PlikeFee, "incorrect amount");
        payable(textCollections[text].deployer).transfer(likeFee);
        payable(owner).transfer(PlikeFee);
        textCollections[text].like += 1;
    }

    function invite(address inviter) public {
        require(addressinviter[msg.sender] == address(0));
        addressinviter[msg.sender] = inviter;
    }

    function listCollection(
        bytes4 text,
        uint256 amount,
        uint256 price
    ) public collectionIsExist(text) {
        require(
            collectionsAmount[text][msg.sender].amount >= amount,
            "over sender collection amount"
        );
        collectionsAmount[text][msg.sender].amount -= amount;
        collectionsAmount[text][msg.sender].collectionsmarket[
            collectionsAmount[text][msg.sender].marketnonce
        ] = market({listAmount: amount, price: price, isSuccessful: false});
        collectionsAmount[text][msg.sender].marketnonce += 1;
        emit List(text, msg.sender, price, amount,collectionsAmount[text][msg.sender].marketnonce);
    }

    function unListCollection(bytes4 text, uint256 marketnonce)
        public
        collectionIsExist(text)
    {
        require(collectionsAmount[text][msg.sender].marketnonce >= marketnonce);
        require(
            collectionsAmount[text][msg.sender]
                .collectionsmarket[marketnonce]
                .isSuccessful == false
        );
        collectionsAmount[text][msg.sender].amount += collectionsAmount[text][
            msg.sender
        ].collectionsmarket[marketnonce].listAmount;
        collectionsAmount[text][msg.sender]
            .collectionsmarket[marketnonce]
            .isSuccessful = true;
        emit UnList(text, msg.sender, marketnonce);
    }

    function buyCollection(
        bytes4 text,
        address lister,
        uint256 marketnonce
    ) public payable collectionIsExist(text) {
        require(collectionsAmount[text][lister].marketnonce >= marketnonce);
        require(
            !collectionsAmount[text][lister]
                .collectionsmarket[marketnonce]
                .isSuccessful
        );
        collectionsAmount[text][lister]
            .collectionsmarket[marketnonce]
            .isSuccessful = true;

        uint256 originalPrice = collectionsAmount[text][lister]
            .collectionsmarket[marketnonce]
            .price *
            collectionsAmount[text][lister]
                .collectionsmarket[marketnonce]
                .listAmount;
        if (addressinviter[msg.sender] == address(0)) {
            uint256 protocolFee = ((originalPrice * protocolTax) / 1000);
            uint256 deployerFee = ((originalPrice * textCollections[text].tax) /
                100);
            require(msg.value >= originalPrice + protocolFee + deployerFee);

            payable(lister).transfer(originalPrice);
            payable(textCollections[text].deployer).transfer(deployerFee);
            payable(owner).transfer(msg.value - originalPrice - deployerFee);
            //这里的价格都是wei
            collectionsAmount[text][msg.sender].amount += collectionsAmount[
                text
            ][lister].collectionsmarket[marketnonce].listAmount;
            emit Transfer(
                text,
                collectionsAmount[text][lister]
                    .collectionsmarket[marketnonce]
                    .listAmount,
                msg.sender,
                lister
            );
        } else {
            uint256 protocolFee = ((originalPrice * IprotocolTax) / 1000);
            uint256 deployerFee = ((originalPrice * textCollections[text].tax) /
                100);
            uint256 inviterFee = ((originalPrice * inviterTax) / 1000);
            require(
                msg.value >=
                    originalPrice + protocolFee + deployerFee + inviterFee
            );

            payable(lister).transfer(originalPrice);
            payable(textCollections[text].deployer).transfer(deployerFee);
            payable(addressinviter[msg.sender]).transfer(inviterFee);
            payable(owner).transfer(
                msg.value - originalPrice - deployerFee - inviterFee
            );
            collectionsAmount[text][msg.sender].amount += collectionsAmount[
                text
            ][lister].collectionsmarket[marketnonce].listAmount;
            emit MTransfer(
                text,
                collectionsAmount[text][lister]
                    .collectionsmarket[marketnonce]
                    .listAmount,
                msg.sender,
                lister,
                marketnonce
            );
        }
    }

    function _addrInviter(address addr) public view returns (address) {
        return addressinviter[addr];
    }

    function _addrtextamount(address addr, bytes4 text)
        public
        view
        returns (uint256)
    {
        return collectionsAmount[text][addr].amount;
    }

    function _addrmarketnonce(address addr, bytes4 text)
        public
        view
        returns (uint256)
    {
        return collectionsAmount[text][addr].marketnonce;
    }

    function _addrlists(
        address addr,
        bytes4 text,
        uint256 marketnonce
    )
        public
        view
        returns (
            uint256 price,
            uint256 listAmount,
            bool isSuccessful
        )
    {
        price = collectionsAmount[text][addr]
            .collectionsmarket[marketnonce]
            .price;
        listAmount = collectionsAmount[text][addr]
            .collectionsmarket[marketnonce]
            .listAmount;
        isSuccessful = collectionsAmount[text][addr]
            .collectionsmarket[marketnonce]
            .isSuccessful;
    }

    function _text(bytes4 text)
        public
        view
        returns (
            uint256 maxSupply,
            uint256 supply,
            address deployer,
            uint8 tax,
            uint256 perMintLimit,
            uint256 time,
            uint256 _like
        )
    {
        maxSupply = textCollections[text].maxSupply;
        supply = textCollections[text].supply;
        deployer = textCollections[text].deployer;
        tax = textCollections[text].tax;
        perMintLimit = textCollections[text].perMintLimit;
        time = textCollections[text].time;
        _like = textCollections[text].like;
    }

    function getPrice(
        bytes4 text,
        address lister,
        uint256 marketnonce,
        address buyer
    ) public view returns (uint256) {
        uint256 originalPrice = collectionsAmount[text][lister]
            .collectionsmarket[marketnonce]
            .price *
            collectionsAmount[text][lister]
                .collectionsmarket[marketnonce]
                .listAmount;
        if (addressinviter[buyer] == address(0)) {
            uint256 protocolFee = ((originalPrice * protocolTax) / 1000);
            uint256 deployerFee = ((originalPrice * textCollections[text].tax) /
                100);
            return originalPrice + protocolFee + deployerFee;
        } else {
            uint256 protocolFee = ((originalPrice * IprotocolTax) / 1000);
            uint256 deployerFee = ((originalPrice * textCollections[text].tax) /
                100);
            uint256 inviterFee = ((originalPrice * inviterTax) / 1000);

            return originalPrice + protocolFee + deployerFee + inviterFee;
        }
    }
}
