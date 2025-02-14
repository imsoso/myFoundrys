// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from 'forge-std/Test.sol';
import { NFTMarket } from '../src/NFTs/NFTMarket.sol';
import '../src/BaseTokens/TokenWithCallback.sol';
import '../src/NFTs/MyNFT.sol';

contract NFTMarketTest is Test {
    NFTMarket public aNftMarket;
    TokenWithCallback public aToken;
    SoNFT public aNFT;
    uint256 nftId;

    address public owner;
    address seller = makeAddr('seller');
    address buyer = makeAddr('buyer');

    function setUp() public {
        owner = address(this);
        aToken = new TokenWithCallback(owner);
        aNFT = new SoNFT(owner);
        aNftMarket = new NFTMarket(address(aNFT), address(aToken));

        nftId = aNFT.mint(
            seller,
            'https://chocolate-acceptable-hawk-967.mypinata.cloud/ipfs/QmRWFi6XoDFchaZ25g8fTRxY3tc4E289AUQvpUcTqP3w7L'
        );
    }

    function test_list_not_owner() public {
        vm.expectRevert(NFTMarket.MustBeTheOwner.selector);
        aNftMarket.listNFT(nftId, 100);
    }

    function test_list_zero_price() public {
        vm.startPrank(seller);
        aNFT.approve(address(aNftMarket), nftId);
        vm.expectRevert(NFTMarket.PriceGreaterThanZero.selector);
        aNftMarket.listNFT(nftId, 0);
        vm.stopPrank();
    }

    function test_list_succeed() public {
        vm.startPrank(seller);
        aNFT.approve(address(aNftMarket), nftId);
        aNftMarket.listNFT(nftId, 100);
        vm.stopPrank();
    }

    function test_buy_insuficient_balance() public {
        vm.startPrank(seller);
        aNFT.approve(address(aNftMarket), nftId);

        aNftMarket.listNFT(nftId, 100);
        vm.stopPrank();

        deal(address(aToken), buyer, 10);
        vm.prank(buyer);
        aToken.approve(address(aNftMarket), 100);

        vm.expectRevert(NFTMarket.NotEnoughToken.selector);
        aNftMarket.buyNFT(buyer, nftId);
    }
    function test_buy_own() public {
        vm.startPrank(seller);
        aNFT.approve(address(aNftMarket), nftId);
        aNftMarket.listNFT(nftId, 100);
        vm.expectRevert(NFTMarket.MustNotBeTheOwner.selector);
        aNftMarket.buyNFT(seller, nftId);
        vm.stopPrank();
    }

    function test_buy_succeed() public {
        vm.startPrank(seller);
        aNFT.approve(address(aNftMarket), nftId);

        aNftMarket.listNFT(nftId, 100);
        vm.stopPrank();

        deal(address(aToken), buyer, 10000);
        vm.prank(buyer);
        aToken.approve(address(aNftMarket), 200);

        aNftMarket.buyNFT(buyer, nftId);
        assertEq(aNFT.ownerOf(nftId), buyer, 'NFT is not belong to you');
    }

    function test_buy_twice() public {
        vm.startPrank(seller);
        aNFT.approve(address(aNftMarket), nftId);

        aNftMarket.listNFT(nftId, 100);
        vm.stopPrank();

        deal(address(aToken), buyer, 10000);
        vm.prank(buyer);
        aToken.approve(address(aNftMarket), 300);

        aNftMarket.buyNFT(buyer, nftId);

        vm.expectRevert(NFTMarket.NFTNotListed.selector);
        aNftMarket.buyNFT(buyer, nftId);
    }
    /// forge-config: default.fuzz.runs = 100
    function test_fuzz_buy(uint256 price, address buyer2) public {
        vm.startPrank(seller);
        price = bound(price, 0.01 ether, 10000 ether);
        vm.assume(price > 0.01 ether && price < 10000 ether);

        aNFT.approve(address(aNftMarket), nftId);
        // Test with random price
        aNftMarket.listNFT(nftId, price);
        vm.stopPrank();

        vm.prank(buyer2);
        aToken.approve(address(aNftMarket), price);
        deal(address(aToken), buyer2, price);

        // Test with random address
        aNftMarket.buyNFT(buyer2, nftId);
    }

    //不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓
    function invariant_noTokenHoldings() public view {
        uint256 contractBalance = aToken.balanceOf(address(aNftMarket));
        assertEq(contractBalance, 0, 'NFTMarket self should not hold any Tokens');
    }
}
