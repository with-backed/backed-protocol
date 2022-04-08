pragma solidity 0.8.12;

import {DSTest} from "../helpers/test.sol";
import {Vm} from "../helpers/Vm.sol";

import {NFTLendOfferFacilitator} from "../../plugins/NFTLendOfferFacilitator.sol";
import {INFTLendOfferFacilitator} from "../../interfaces/INFTLendOfferFacilitator.sol";
import {NFTLoanFacilitator} from "../../NFTLoanFacilitator.sol";
import {NFTLoanFacilitatorFactory} from "../helpers/NFTLoanFacilitatorFactory.sol";
import {BorrowTicket} from "../../BorrowTicket.sol";
import {LendTicket} from "../../LendTicket.sol";
import {CryptoPunks} from "../mocks/CryptoPunks.sol";
import {DAI} from "../mocks/DAI.sol";

contract NFTLendOfferFacilitatorGasBenchmarkTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);

    NFTLendOfferFacilitator preBidder;
    NFTLoanFacilitator facilitator;

    address lender = address(1);
    address borrower = address(2);

    CryptoPunks punks = new CryptoPunks();
    DAI dai = new DAI();

    uint16 interestRate = 15;
    uint128 loanAmount = 1e20;
    uint32 loanDuration = 1000;

    uint256 tokenId;
    uint256 lendOfferId;
    uint256 loanId;

    function setUp() public {
        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (, , facilitator) = factory.newFacilitator(address(this));
        preBidder = new NFTLendOfferFacilitator(address(facilitator));

        vm.startPrank(borrower);
        tokenId = punks.mint();
        punks.approve(address(facilitator), tokenId);
        vm.stopPrank();

        vm.startPrank(lender);
        dai.mint(loanAmount, lender);
        dai.approve(address(preBidder), loanAmount);
        lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            int256(tokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );
        vm.stopPrank();

        vm.startPrank(borrower);
        loanId = facilitator.createLoan(
            tokenId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            address(borrower)
        );
        vm.stopPrank();

        vm.startPrank(address(preBidder));
        dai.approve(address(facilitator), type(uint256).max);
        vm.stopPrank();
    }

    function testCreateLendOfferForNFTGas() public {
        preBidder.createLendOfferForNFT(
            address(punks),
            int256(tokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );
    }

    function testfulfillLendOfferGas() public {
        vm.startPrank(borrower);
        preBidder.fulfillLendOffer(lendOfferId, loanId);
    }

    function testfulfillLendOfferWithNoApprovalsGas() public {
        vm.startPrank(borrower);
        preBidder.fulfillLendOfferWithNoApprovals(lendOfferId, loanId);
    }

    function testcancelLendOfferGas() public {
        vm.startPrank(lender);
        preBidder.cancelLendOffer(lendOfferId);
    }
}

contract NFTLendOfferFacilitatorTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);

    NFTLendOfferFacilitator preBidder;

    NFTLoanFacilitator facilitator;
    BorrowTicket borrowTicket;
    LendTicket lendTicket;

    address lender = address(1);
    address borrower = address(2);

    CryptoPunks punks = new CryptoPunks();
    DAI dai = new DAI();

    uint16 interestRate = 15;
    uint128 loanAmount = 1e20;
    uint32 loanDuration = 1000;

    function setUp() public {
        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (borrowTicket, lendTicket, facilitator) = factory.newFacilitator(
            address(this)
        );
        preBidder = new NFTLendOfferFacilitator(address(facilitator));
    }

    function testCreateBidSuccessful() public {
        vm.startPrank(lender);

        int256 tokenId = 1;
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            tokenId,
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );
        INFTLendOfferFacilitator.LendOffer memory lendOffer = preBidder
            .lendOfferInfoStruct(lendOfferId);
        assertEq(lendOffer.lender, lender);
        assertEq(lendOffer.collateralContractAddress, address(punks));
        assertEq(lendOffer.collateralTokenId, tokenId);
        assertEq(lendOffer.loanAssetContractAddress, address(dai));
        assertEq(lendOffer.minInterestRate, interestRate);
        assertEq(lendOffer.maxDurationSeconds, loanDuration);
        assertEq(lendOffer.maxLoanAmount, loanAmount);
    }

    function testfulfillLendOfferSuccessfulWithSpecifiedTokenId() public {
        uint256 tokenId = setUpWithPunk(borrower);
        setUpWithDai(lender);

        uint256 lenderBalance = dai.balanceOf(lender);
        uint256 borrowerBalance = dai.balanceOf(borrower);

        vm.startPrank(lender);
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            int256(tokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );
        vm.startPrank(borrower);
        uint256 loanId = facilitator.createLoan(
            tokenId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            address(borrower)
        );

        vm.startPrank(borrower);
        preBidder.fulfillLendOffer(lendOfferId, loanId);

        assertEq(punks.ownerOf(tokenId), address(facilitator));
        assertEq(dai.balanceOf(lender), lenderBalance - loanAmount);
        assertEq(
            dai.balanceOf(borrower),
            borrowerBalance + loanAmount - calculateTake(loanAmount)
        );
        assertEq(borrowTicket.ownerOf(loanId), borrower);
        assertEq(lendTicket.ownerOf(loanId), lender);
    }

    function testfulfillLendOfferSuccessfulWithUnspecifiedTokenId() public {
        uint256 tokenId = setUpWithPunk(borrower);
        setUpWithDai(lender);

        uint256 lenderBalance = dai.balanceOf(lender);
        uint256 borrowerBalance = dai.balanceOf(borrower);

        vm.startPrank(lender);
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            -1, // tokenId not specified
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );
        vm.startPrank(borrower);
        uint256 loanId = facilitator.createLoan(
            tokenId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            address(borrower)
        );

        preBidder.fulfillLendOffer(lendOfferId, loanId);

        assertEq(punks.ownerOf(tokenId), address(facilitator));
        assertEq(dai.balanceOf(lender), lenderBalance - loanAmount);
        assertEq(
            dai.balanceOf(borrower),
            borrowerBalance + loanAmount - calculateTake(loanAmount)
        );
        assertEq(borrowTicket.ownerOf(loanId), borrower);
        assertEq(lendTicket.ownerOf(loanId), lender);
    }

    function testfulfillLendOfferFailsIfWrongTokenId() public {
        uint256 desiredTokenId = 1;
        vm.startPrank(lender);
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            int256(desiredTokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );

        uint256 borrowerTokenId = setUpWithPunk(borrower);
        vm.startPrank(borrower);
        uint256 loanId = facilitator.createLoan(
            borrowerTokenId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            address(borrower)
        );

        vm.expectRevert("NFTLendOfferFacilitator: token ID mismatch");
        preBidder.fulfillLendOffer(lendOfferId, loanId);

        vm.expectRevert("NFTLendOfferFacilitator: token ID mismatch");
        preBidder.fulfillLendOfferWithNoApprovals(lendOfferId, loanId);
    }

    function testfulfillLendOfferRevertsIfLenderDoesNotHaveFunds() public {
        uint256 tokenId = setUpWithPunk(borrower);
        vm.startPrank(lender);
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            int256(tokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );
        vm.startPrank(borrower);
        uint256 loanId = facilitator.createLoan(
            tokenId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            address(borrower)
        );

        // approve spending so we don't get allowance revert
        vm.startPrank(lender);
        dai.approve(address(preBidder), loanAmount);

        vm.startPrank(borrower);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        preBidder.fulfillLendOffer(lendOfferId, loanId);

        vm.expectRevert("TRANSFER_FROM_FAILED");
        preBidder.fulfillLendOfferWithNoApprovals(lendOfferId, loanId);
    }

    function testfulfillLendOfferWithNoApprovalsSuccessful() public {
        uint256 tokenId = setUpWithPunk(borrower);
        setUpWithDai(lender);

        uint256 lenderBalance = dai.balanceOf(lender);
        uint256 borrowerBalance = dai.balanceOf(borrower);

        vm.startPrank(lender);
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            int256(tokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );
        vm.startPrank(borrower);
        uint256 loanId = facilitator.createLoan(
            tokenId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            address(borrower)
        );

        // a client would only call this if NFTLendOfferFacilitator contract has approved NFTLoanFacilitator to transfer loan asset ERC20
        vm.startPrank(address(preBidder));
        punks.setApprovalForAll(address(facilitator), true);
        dai.approve(address(facilitator), type(uint256).max);

        vm.startPrank(borrower);
        preBidder.fulfillLendOfferWithNoApprovals(lendOfferId, loanId);

        assertEq(punks.ownerOf(tokenId), address(facilitator));
        assertEq(dai.balanceOf(lender), lenderBalance - loanAmount);
        assertEq(
            dai.balanceOf(borrower),
            borrowerBalance + loanAmount - calculateTake(loanAmount)
        );
        assertEq(borrowTicket.ownerOf(loanId), borrower);
        assertEq(lendTicket.ownerOf(loanId), lender);
    }

    function testfulfillLendOfferWithNoApprovalsRevertsIfNoPriorApprovals()
        public
    {
        uint256 tokenId = setUpWithPunk(borrower);
        setUpWithDai(lender);

        vm.startPrank(lender);
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            int256(tokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );
        vm.startPrank(borrower);
        uint256 loanId = facilitator.createLoan(
            tokenId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            address(borrower)
        );

        vm.startPrank(borrower);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        preBidder.fulfillLendOfferWithNoApprovals(lendOfferId, loanId);
    }

    function testcancelLendOfferSuccessful() public {
        uint256 tokenId = setUpWithPunk(borrower);
        vm.startPrank(lender);
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            int256(tokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );

        // let's say lender wants to cancel their lendOffer
        preBidder.cancelLendOffer(lendOfferId);

        vm.startPrank(borrower);
        vm.expectRevert("NFTLendOfferFacilitator: lend offer does not exist");
        preBidder.fulfillLendOffer(lendOfferId, 1);
    }

    function testcancelLendOfferRevertsIfNotBidder() public {
        uint256 tokenId = setUpWithPunk(borrower);
        vm.startPrank(lender);
        uint256 lendOfferId = preBidder.createLendOfferForNFT(
            address(punks),
            int256(tokenId),
            address(dai),
            interestRate,
            loanAmount,
            loanDuration
        );

        // let's say an address that was not the lendOfferder wants to cancel the lendOffer
        vm.startPrank(borrower);
        vm.expectRevert("NFTLendOfferFacilitator: Only lender can cancel");
        preBidder.cancelLendOffer(lendOfferId);
    }

    function setUpWithPunk(address addr) public returns (uint256 tokenId) {
        vm.startPrank(addr);
        tokenId = punks.mint();

        punks.approve(address(facilitator), tokenId);
        vm.stopPrank();
    }

    function setUpWithDai(address addr) public {
        vm.startPrank(addr);
        dai.mint(loanAmount, addr);
        dai.approve(address(preBidder), loanAmount);
        vm.stopPrank();
    }

    function calculateTake(uint256 amount) public view returns (uint256) {
        return
            (amount * facilitator.originationFeeRate()) / facilitator.SCALAR();
    }
}
