// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.12;

import {DSTest} from "./helpers/test.sol";
import {Vm} from "./helpers/Vm.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {INFTLoanFacilitator} from "contracts/interfaces/INFTLoanFacilitator.sol";
import {NFTLoanFacilitator} from "contracts/NFTLoanFacilitator.sol";
import {NFTLoanFacilitatorFactory} from "./helpers/NFTLoanFacilitatorFactory.sol";
import {BorrowTicket} from "contracts/BorrowTicket.sol";
import {LendTicket} from "contracts/LendTicket.sol";
import {TestERC721} from "./mocks/TestERC721.sol";
import {TestERC20} from "./mocks/TestERC20.sol";
import {TestERC777} from "./mocks/TestERC777.sol";
import {FeeOnTransferERC20} from "./mocks/FeeOnTransferERC20.sol";
import {RepayAndCloseERC20} from "./mocks/RepayAndCloseERC20.sol";
import {ReLendERC20} from "./mocks/ReLendERC20.sol";
import {ERC1820Registry} from "./mocks/ERC1820Registry.sol";

contract NFTLoanFacilitatorGasBenchMarkTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    NFTLoanFacilitator facilitator;
    TestERC721 erc721 = new TestERC721();
    TestERC20 erc20 = new TestERC20();
    uint256 erc721Id;
    uint16 interestRate = 15;
    uint128 loanAmount = 1e20;
    uint32 loanDuration = 1000;
    uint256 startTimestamp = 5;

    function setUp() public {
        ERC1820Registry registery = new ERC1820Registry();
        vm.etch(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24, address(registery).code);

        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (, , facilitator) = factory.newFacilitator(address(this));

        // approve for lending
        erc20.mint(address(this), loanAmount * 3);
        erc20.approve(address(facilitator), loanAmount * 3);

        // create a loan so we can close it or lend against it
        erc721Id = erc721.mint();
        erc721.approve(address(facilitator), erc721Id);
        facilitator.createLoan(
            erc721Id,
            address(erc721),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            address(this)
        );

        // mint another erc721 so we can create a second loan
        erc721.mint();
        erc721.approve(address(facilitator), erc721Id + 1);

        // prevent errors from timestamp 0
        vm.warp(startTimestamp);

        // create another loan and lend against it so we can buyout or repay
        erc721.mint();
        erc721.approve(address(facilitator), erc721Id + 2);
        facilitator.createLoan(
            erc721Id + 2,
            address(erc721),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            address(this)
        );
        facilitator.lend(
            2,
            interestRate,
            loanAmount,
            loanDuration,
            address(this)
        );
    }

    function testCreateLoan() public {
        facilitator.createLoan(
            erc721Id + 1,
            address(erc721),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            address(this)
        );
    }

    function testCloseLoan() public {
        facilitator.closeLoan(1, address(this));
    }

    function testLend() public {
        facilitator.lend(
            1,
            interestRate,
            loanAmount,
            loanDuration,
            address(this)
        );
    }

    function testLendBuyout() public {
        facilitator.lend(
            2,
            interestRate,
            loanAmount + ((loanAmount * 10) / 100),
            loanDuration,
            address(this)
        );
    }

    function testRepayAndClose() public {
        facilitator.repayAndCloseLoan(2);
    }

    function testSeizeCollateral() public {
        vm.warp(startTimestamp + loanDuration + 1);
        facilitator.seizeCollateral(2, address(this));
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract NFTLoanFacilitatorTest is DSTest {
    event CreateLoan(
        uint256 indexed id,
        address indexed minter,
        uint256 collateralTokenId,
        address collateralContract,
        uint256 maxInterestRate,
        address loanAssetContract,
        uint256 minLoanAmount,
        uint256 minDurationSeconds
    );

    event Lend(
        uint256 indexed id,
        address indexed lender,
        uint256 interestRate,
        uint256 loanAmount,
        uint256 durationSeconds
    );

    event BuyoutLender(
        uint256 indexed id,
        address indexed lender,
        address indexed replacedLoanOwner,
        uint256 interestEarned,
        uint256 replacedAmount
    );

    Vm vm = Vm(HEVM_ADDRESS);

    NFTLoanFacilitator facilitator;
    BorrowTicket borrowTicket;
    LendTicket lendTicket;

    address borrower = address(1);
    address lender = address(2);

    TestERC721 erc721 = new TestERC721();
    TestERC20 erc20 = new TestERC20();

    uint16 interestRate = 15;
    uint128 loanAmount = 1e20;
    uint32 loanDuration = 1000;
    uint256 startTimestamp = 5;
    uint256 erc721Id;

    function setUp() public {
        ERC1820Registry registery = new ERC1820Registry();
        vm.etch(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24, address(registery).code);

        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (borrowTicket, lendTicket, facilitator) = factory.newFacilitator(
            address(this)
        );
        vm.warp(startTimestamp);

        vm.startPrank(borrower);
        erc721Id = erc721.mint();
        erc721.approve(address(facilitator), erc721Id);
        vm.stopPrank();
    }

    function testCreateLoanEmitsCorrectly() public {
        vm.expectEmit(true, true, true, true);
        emit CreateLoan(
            1,
            borrower,
            erc721Id,
            address(erc721),
            interestRate,
            address(erc20),
            loanAmount,
            loanDuration
        );
        vm.prank(borrower);
        facilitator.createLoan(
            erc721Id,
            address(erc721),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            borrower
        );
    }

    function testCreateLoanTransfersCollateralToSelf() public {
        vm.prank(borrower);
        facilitator.createLoan(
            erc721Id,
            address(erc721),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            borrower
        );

        assertEq(erc721.ownerOf(erc721Id), address(facilitator));
    }

    function testCreateLoanMintsBorrowTicketCorrectly() public {
        address mintBorrowTicketTo = address(3);
        vm.prank(borrower);
        uint256 loanId = facilitator.createLoan(
            erc721Id,
            address(erc721),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            mintBorrowTicketTo
        );

        assertEq(borrowTicket.ownerOf(loanId), mintBorrowTicketTo);
    }

    function testCreateLoanSetsValuesCorrectly(
        uint16 maxPerAnumInterest,
        uint128 minLoanAmount,
        uint32 minDurationSeconds,
        address mintTo
    ) public {
        vm.assume(minLoanAmount > 0);
        vm.assume(minDurationSeconds > 0);
        vm.assume(mintTo != address(0));

        vm.prank(borrower);
        uint256 loanId = facilitator.createLoan(
            erc721Id,
            address(erc721),
            maxPerAnumInterest,
            minLoanAmount,
            address(erc20),
            minDurationSeconds,
            mintTo
        );
     
        INFTLoanFacilitator.Loan memory loan = facilitator.loanInfoStruct(loanId);

        assertTrue(!loan.closed);
        assertEq(loan.durationSeconds, minDurationSeconds);
        assertEq(loan.perAnumInterestRate, maxPerAnumInterest);
        assertEq(loan.loanAmount, minLoanAmount);
        assertEq(loan.lastAccumulatedTimestamp, 0);
        assertEq(loan.accumulatedInterest, 0);
        assertEq(loan.collateralContractAddress, address(erc721));
        assertEq(loan.collateralTokenId, erc721Id);
        assertEq(loan.loanAssetContractAddress, address(erc20));
        assertEq(loan.originationFeeRate, facilitator.originationFeeRate());
    }

    function testCreateLoanZeroDurationNotAllowed() public {
        vm.startPrank(borrower);
        vm.expectRevert("0 duration");
        facilitator.createLoan(
            erc721Id,
            address(erc721),
            interestRate,
            loanAmount,
            address(erc20),
            0,
            borrower
        );
    }

    function testCreateLoanZeroAmountNotAllowed() public {
        vm.startPrank(borrower);
        vm.expectRevert("0 loan amount");
        facilitator.createLoan(
            erc721Id,
            address(erc721),
            interestRate,
            0,
            address(erc20),
            loanDuration,
            borrower
        );
    }

    function testCreateLoanAddressZeroCollateralFails() public {
        vm.startPrank(borrower);
        vm.expectRevert(bytes(""));
        facilitator.createLoan(
            erc721Id,
            address(0),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            borrower
        );
    }

    function testBorrowTicketUnusableAsCollateral() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        borrowTicket.approve(address(facilitator), loanId);
        vm.expectRevert("borrow ticket collateral");
        facilitator.createLoan(
            loanId,
            address(borrowTicket),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            borrower
        );
    }

    function testLendTicketUnusableAsCollateral() public {
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);
        vm.startPrank(lender);

        lendTicket.approve(address(facilitator), loanId);
        vm.expectRevert("lend ticket collateral");
        facilitator.createLoan(
            loanId,
            address(lendTicket),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            borrower
        );
    }

    function testSuccessfulCloseLoan() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        facilitator.closeLoan(loanId, borrower);
        assertEq(erc721.ownerOf(tokenId), borrower); // make sure borrower gets their NFT back
        (bool closed, , , , , , , , , ) = facilitator.loanInfo(loanId);
        assertTrue(closed); // make sure loan was closed
    }

    function testClosingAlreadyClosedLoan() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        facilitator.closeLoan(loanId, borrower);

        // closing an already closed loan should revert
        vm.expectRevert("loan closed");
        facilitator.closeLoan(loanId, borrower);
    }

    function testClosingLoanWithLender() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        erc20.mint(borrower, loanAmount);
        erc20.approve(address(facilitator), loanAmount); // approve for lending
        vm.warp(startTimestamp); // make sure there's a non-zero timestamp
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            borrower
        ); // have borrower lend, this is not realistic, but will do for this test

        // loan has lender, should now revert
        vm.expectRevert(
            "has lender"
        );
        facilitator.closeLoan(loanId, borrower);
    }

    function testClosingLoanFromNonBorrower() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);

        vm.startPrank(address(2));
        vm.expectRevert("borrow ticket holder only");
        facilitator.closeLoan(loanId, borrower);
        vm.stopPrank();
    }

    function testInterestExceedingUint128BuyoutReverts() public {
        loanAmount = type(uint128).max;
        // 100% APR
        interestRate = 1000;
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);
        facilitator.interestOwed(loanId);
        vm.warp(startTimestamp + 366 days);

        vm.expectRevert(
            "interest exceeds uint128"
        );
        facilitator.lend(loanId, 0, loanAmount, loanDuration, address(4));
    }

    function testInterestExceedingUint128InterestOwed() public {
        loanAmount = type(uint128).max;
        // 100% APR
        interestRate = 1000;
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);
        vm.warp(startTimestamp + 366 days);
        facilitator.interestOwed(loanId);
    }

    function testRepayInterestOwedExceedingUint128() public {
        loanAmount = type(uint128).max;
        // 100% APR
        interestRate = 1000;
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);
        vm.warp(startTimestamp + 366 days);
        uint256 t = facilitator.totalOwed(loanId);
        vm.startPrank(address(3));
        erc20.mint(address(3), t);
        erc20.approve(address(facilitator), t);
        facilitator.repayAndCloseLoan(loanId);
        vm.stopPrank();
    }

    function testLendMintsLendTicketCorrectly() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        setUpLender(lender);
        vm.startPrank(lender);
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lender
        );

        assertEq(lendTicket.ownerOf(loanId), lender);
    }

    function testLendFailsWithAddressZeroLoanAsset() public {
        erc20 = TestERC20(address(0));
        (, uint256 loanId) = setUpLoanForTest(borrower);
    
        vm.expectRevert('invalid loan');
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lender
        );
    }

    function testLendFailsWithERC777Token() public {
        TestERC777 token = new TestERC777();
        erc20 = TestERC20(address(token));
        (, uint256 loanId) = setUpLoanForTest(borrower);

        erc20.mint(address(this), loanAmount);
        erc20.approve(address(facilitator), loanAmount);

        vm.expectRevert("ERC777 unsupported");
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lender
        );
    }

    function testLendFailsWithEOALoanAsset() public {
        erc20 = TestERC20(address(1));
        (, uint256 loanId) = setUpLoanForTest(borrower);
    
        vm.expectRevert('invalid loan');
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lender
        );
    }

    function testLendTransfersERC20Correctly() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        setUpLender(lender);

        uint256 lenderBalance = erc20.balanceOf(lender);

        vm.startPrank(lender);
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lender
        );

        assertEq(erc20.balanceOf(lender), lenderBalance - loanAmount);
        uint256 facilitatorTake = (loanAmount *
            facilitator.originationFeeRate()) / facilitator.SCALAR();
        assertEq(erc20.balanceOf(address(facilitator)), facilitatorTake);
        assertEq(erc20.balanceOf(borrower), loanAmount - facilitatorTake);
    }

    function testLendUpdatesValuesCorrectly(
        uint16 rate,
        uint128 amount,
        uint32 duration,
        address sendTo
    ) public {
        vm.assume(rate <= interestRate);
        vm.assume(amount >= loanAmount);
        vm.assume(duration >= loanDuration);
        vm.assume(sendTo != address(0));

        (uint256 tokenId, uint256 loanId) = setUpLoanForTest(borrower);

        erc20.mint(address(this), amount);
        erc20.approve(address(facilitator), amount);

        facilitator.lend(loanId, rate, amount, duration, sendTo);
       
        INFTLoanFacilitator.Loan memory loan = facilitator.loanInfoStruct(loanId);

        assertTrue(!loan.closed);
        assertEq(loan.durationSeconds, duration);
        assertEq(loan.perAnumInterestRate, rate);
        assertEq(loan.loanAmount, amount);
        assertEq(loan.lastAccumulatedTimestamp, block.timestamp);
        assertEq(loan.accumulatedInterest, 0);
        assertEq(loan.collateralContractAddress, address(erc721));
        assertEq(loan.collateralTokenId, tokenId);
        assertEq(loan.loanAssetContractAddress, address(erc20));
        assertEq(loan.originationFeeRate, facilitator.originationFeeRate());
    }

    function testLendEmitsCorrectly() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);

        erc20.mint(address(this), loanAmount);
        erc20.approve(address(facilitator), loanAmount);

        vm.expectEmit(true, true, false, true);
        emit Lend(
            loanId,
            address(this),
            interestRate,
            loanAmount,
            loanDuration
        );

        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            address(1)
        );
    }

    function testSuccessfulLend() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);
        uint256 lenderBalance = erc20.balanceOf(lender);

        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lender
        );
        (
            ,
            ,
            ,
            uint40 lastAccumulatedTimestamp,
            ,
            ,
            ,
            uint256 accumulatedInterest,
            ,

        ) = facilitator.loanInfo(loanId);
        assertEq(lastAccumulatedTimestamp, startTimestamp);
        assertEq(accumulatedInterest, 0);

        // make sure lenders erc20 is transfered and lender gets lend ticket
        assertEq(erc20.balanceOf(lender), lenderBalance - loanAmount);
        assertEq(lendTicket.ownerOf(loanId), lender);

        // make sure Facilitator subtracted origination fee
        uint256 facilitatorTake = (loanAmount *
            facilitator.originationFeeRate()) / facilitator.SCALAR();
        assertEq(erc20.balanceOf(address(facilitator)), facilitatorTake);

        // make sure borrower got their loan in TestERC20
        assertEq(erc20.balanceOf(borrower), loanAmount - facilitatorTake);
    }

    function testLoanValuesNotChangedAfterLend() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);

        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lender
        );
        (
            bool closed,
            uint16 interest,
            uint32 durationSeconds,
            uint40 lastAccumulatedTimestamp,
            address collateralContractAddress,
            uint96 originationFeeRate,
            address loanAssetContractAddress,
            uint128 accumulatedInterest,
            uint128 loanAmountFromLoan,
            uint256 collateralTokenId
        ) = facilitator.loanInfo(loanId);

        assertTrue(!closed);
        assertEq(interestRate, interest);
        assertEq(lastAccumulatedTimestamp, startTimestamp);
        assertEq(durationSeconds, loanDuration);
        assertEq(accumulatedInterest, 0);
        assertEq(loanAmountFromLoan, loanAmount);
        assertEq(collateralContractAddress, address(erc721));
        assertEq(loanAssetContractAddress, address(erc20));
        assertEq(collateralTokenId, tokenId);
    }

    function testLendFailsIfHigherInterestRate(
        uint16 rate,
        uint32 duration,
        uint128 amount
    ) public {
        vm.assume(rate > interestRate);
        vm.assume(duration >= loanDuration);
        vm.assume(amount >= loanAmount);
        (, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);
        vm.expectRevert("rate too high");
        facilitator.lend(loanId, rate, amount, duration, lender);
    }

    function testLendFailsIfLowerAmount(
        uint16 rate,
        uint32 duration,
        uint128 amount
    ) public {
        vm.assume(rate <= interestRate);
        vm.assume(duration >= loanDuration);
        vm.assume(amount < loanAmount);
        (, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);
        vm.expectRevert("amount too low");
        facilitator.lend(loanId, rate, amount, duration, lender);
    }

    function testLendFailsIfLowerDuration(
        uint16 rate,
        uint32 duration,
        uint128 amount
    ) public {
        vm.assume(rate <= interestRate);
        vm.assume(duration < loanDuration);
        vm.assume(amount >= loanAmount);
        (, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);
        vm.expectRevert("duration too low");
        facilitator.lend(loanId, rate, amount, duration, lender);
    }

    function testLendWithFeeOnTransferToken(
        uint128 amount
    ) public {
        vm.assume(amount > 0);
        loanAmount = amount;
        FeeOnTransferERC20 token = new FeeOnTransferERC20();
        erc20 = TestERC20(address(token));
        (, uint256 loanId) = setUpLoanForTest(borrower);
        erc20.mint(address(this), loanAmount);
        erc20.approve(address(facilitator), loanAmount);

        facilitator.lend(loanId, interestRate, loanAmount, loanDuration, borrower);

        uint256 facilitatorBalance = erc20.balanceOf(address(facilitator));
        uint256 borrowerBalance = erc20.balanceOf(borrower);

        uint256 normalTake = calculateTake(loanAmount);
        uint256 expectedTake = normalTake - (normalTake * token.feeBips() / 10_000);
        uint256 normalBorrowerBalance = (loanAmount - normalTake);
        uint256 expectedBorrowerBalance = normalBorrowerBalance - (normalBorrowerBalance * token.feeBips() / 10_000);

        assertEq(
            facilitatorBalance,
            expectedTake
        );
        assertEq(
            borrowerBalance,
            expectedBorrowerBalance
        );
    }

    function testInterestAccruesCorrectly() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        setUpLender(lender);
        vm.startPrank(lender);
        facilitator.lend(
            loanId,
            10, // 1% annual rate
            loanAmount,
            loanDuration,
            lender
        );

        uint256 interestAccrued = facilitator.interestOwed(loanId);
        assertEq(interestAccrued, 0);

        uint256 elapsedTime = 1; // simulate fast forwarding 100 seconds
        vm.warp(startTimestamp + elapsedTime);

        // 1 second with 1% annual = 0.000000031709792% per second
        // 0.00000000031709792 * 10^20 = 31709791983
        assertEq(facilitator.interestOwed(loanId), 31709791983);

        // 1 year with 1% annual on 10^20 = 10^18
        // tiny loss of precision, 10^18 - 999999999997963200 = 2036800
        // => 0.000000000002037 in the case of currencies with 18 decimals
        vm.warp(startTimestamp + 365 days);
        assertEq(facilitator.interestOwed(loanId), 999999999997963200);
    }

    function testBuyoutSucceedsIfRateImproved(uint16 rate) public {
        vm.assume(rate <= decreaseByMinPercent(interestRate));
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);

        facilitator.lend(loanId, rate, loanAmount, loanDuration, newLender);
    }

    function testBuyoutSucceedsIfAmountImproved(uint128 amount) public {
        vm.assume(amount >= increaseByMinPercent(loanAmount));
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        uint256 amountIncrease = amount - loanAmount;
        erc20.mint(newLender, amountIncrease);

        vm.startPrank(newLender);
        facilitator.lend(loanId, interestRate, amount, loanDuration, newLender);
    }

    function testBuyoutSucceedsIfDurationImproved(uint32 duration) public {
        vm.assume(duration >= increaseByMinPercent(loanDuration));
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);

        facilitator.lend(loanId, interestRate, loanAmount, duration, newLender);
    }

    function testBuyoutUpdatesValuesCorrectly() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanWithLenderForTest(
            borrower,
            lender
        );

        address newLender = address(3);
        setUpLender(newLender);
        uint32 newDuration = uint32(increaseByMinPercent(loanDuration));

        vm.prank(newLender);
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            newDuration,
            address(1)
        );
        (
            bool closed,
            uint16 interest,
            uint32 durationSeconds,
            uint40 lastAccumulatedTimestamp,
            address collateralContractAddress,
            uint96 originationFeeRate,
            address loanAssetContractAddress,
            uint128 accumulatedInterest,
            uint128 loanAmountFromLoan,
            uint256 collateralTokenId
        ) = facilitator.loanInfo(loanId);

        assertTrue(!closed);
        assertEq(interestRate, interest);
        assertEq(newDuration, durationSeconds);
        assertEq(loanAmount, loanAmountFromLoan);
        assertEq(lastAccumulatedTimestamp, startTimestamp);
        assertEq(accumulatedInterest, 0);
        // does not change immutable values
        assertEq(collateralContractAddress, address(erc721));
        assertEq(loanAssetContractAddress, address(erc20));
        assertEq(collateralTokenId, tokenId);
    }

    function testBuyoutUpdatesAccumulatedInterestCorrectly() public {
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);
        uint256 elapsedTime = 100;
        vm.warp(startTimestamp + elapsedTime);
        uint256 interest = facilitator.interestOwed(loanId);
        uint32 newDuration = uint32(increaseByMinPercent(loanDuration));

        erc20.mint(address(this), loanAmount + interest);
        erc20.approve(address(facilitator), loanAmount + interest);

        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            newDuration,
            address(1)
        );
        (
            ,
            ,
            ,
            uint40 lastAccumulatedTimestamp,
            ,
            ,
            ,
            uint256 accumulatedInterest,
            ,

        ) = facilitator.loanInfo(loanId);

        assertEq(lastAccumulatedTimestamp, startTimestamp + elapsedTime);
        assertEq(accumulatedInterest, interest);
    }

    function testBuyoutTransfersLendTicket() public {
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        uint32 newDuration = uint32(increaseByMinPercent(loanDuration));

        vm.prank(newLender);
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            newDuration,
            newLender
        );

        assertEq(lendTicket.ownerOf(loanId), newLender);
    }

    function testBuyoutPaysPreviousLenderCorrectly(uint128 amount) public {
        vm.assume(amount >= loanAmount);
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        vm.warp(startTimestamp + 100);
        uint256 interest = facilitator.interestOwed(loanId);

        erc20.mint(address(this), amount + interest);
        erc20.approve(address(facilitator), amount + interest);

        uint256 beforeBalance = erc20.balanceOf(lender);

        facilitator.lend(
            loanId,
            interestRate,
            amount,
            uint32(increaseByMinPercent(loanDuration)),
            address(1)
        );

        assertEq(beforeBalance + loanAmount + interest, erc20.balanceOf(lender));
    }

    function testBuyoutPaysBorrowerCorrectly(uint128 amount) public {
        vm.assume(amount >= loanAmount);
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        erc20.mint(address(this), amount);
        erc20.approve(address(facilitator), amount);

        uint256 beforeBalance = erc20.balanceOf(borrower);

        facilitator.lend(
            loanId,
            interestRate,
            amount,
            uint32(increaseByMinPercent(loanDuration)),
            address(1)
        );

        uint256 amountIncrease = amount - loanAmount;
        uint256 originationFee = (amountIncrease *
            facilitator.originationFeeRate()) / facilitator.SCALAR();
        assertEq(
            beforeBalance + (amountIncrease - originationFee),
            erc20.balanceOf(borrower)
        );
    }

    function testBuyoutPaysFacilitatorCorrectly(uint128 amount) public {
        vm.assume(amount >= loanAmount);
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        erc20.mint(newLender, amount);
        vm.startPrank(newLender);
        erc20.approve(address(facilitator), amount);

        uint256 beforeBalance = erc20.balanceOf(address(facilitator));

        facilitator.lend(
            loanId,
            interestRate,
            amount,
            uint32(increaseByMinPercent(loanDuration)),
            address(1)
        );

        uint256 amountIncrease = amount - loanAmount;
        uint256 originationFee = (amountIncrease *
            facilitator.originationFeeRate()) / facilitator.SCALAR();
        assertEq(
            beforeBalance + originationFee,
            erc20.balanceOf(address(facilitator))
        );
    }
    
    function testBuyoutFeeOnTransferPaysPreviousLenderCorrectly(
        uint128 amount
    ) public {
        vm.assume(amount >= loanAmount);
        FeeOnTransferERC20 token = new FeeOnTransferERC20();
        erc20 = TestERC20(address(token));
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        vm.warp(startTimestamp + 100);
        uint256 interest = facilitator.interestOwed(loanId);

        erc20.mint(address(this), amount + interest);
        erc20.approve(address(facilitator), amount + interest);

        uint256 beforeBalance = erc20.balanceOf(lender);

        facilitator.lend(
            loanId,
            interestRate,
            amount,
            uint32(increaseByMinPercent(loanDuration)),
            address(1)
        );

        uint256 expectedIncrease = (loanAmount + interest)
            - ((loanAmount + interest) * token.feeBips() / 10_000);
        assertEq(beforeBalance + expectedIncrease, erc20.balanceOf(lender));
    }

    function testBuyoutFeeOnTransferPaysBorrowerCorrectly(
        uint128 amount
    ) public {
        vm.assume(amount >= loanAmount);
        FeeOnTransferERC20 token = new FeeOnTransferERC20();
        erc20 = TestERC20(address(token));
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        erc20.mint(address(this), amount);
        erc20.approve(address(facilitator), amount);

        uint256 beforeBalance = erc20.balanceOf(borrower);

        facilitator.lend(
            loanId,
            interestRate,
            amount,
            uint32(increaseByMinPercent(loanDuration)),
            address(1)
        );

        uint256 amountIncrease = amount - loanAmount;
        uint256 originationFee = calculateTake(amountIncrease);
        uint256 expectedIncrease = (amountIncrease - originationFee)
            - ((amountIncrease - originationFee) * token.feeBips() / 10_000);
        assertEq(
            beforeBalance + expectedIncrease,
            erc20.balanceOf(borrower)
        );
    }

    function testBuyoutFeeOnTransferPaysFacilitatorCorrectly(uint128 amount) public {
        vm.assume(amount >= loanAmount);
        FeeOnTransferERC20 token = new FeeOnTransferERC20();
        erc20 = TestERC20(address(token));
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        erc20.mint(newLender, amount);
        vm.startPrank(newLender);
        erc20.approve(address(facilitator), amount);

        uint256 beforeBalance = erc20.balanceOf(address(facilitator));

        facilitator.lend(
            loanId,
            interestRate,
            amount,
            uint32(increaseByMinPercent(loanDuration)),
            address(1)
        );

        uint256 amountIncrease = amount - loanAmount;
        uint256 originationFee = calculateTake(amountIncrease)
            - calculateTake(amountIncrease) * token.feeBips() / 10_000;
        assertEq(
            beforeBalance + originationFee,
            erc20.balanceOf(address(facilitator))
        );
    }

    function testBuyoutPaysFacilitatorCorrectlyWhenFeeChanged(uint128 amount) public {
        vm.assume(amount >= loanAmount);
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);
        uint256 oldOriginationFee = facilitator.originationFeeRate();
        facilitator.updateOriginationFeeRate(50);

        address newLender = address(3);
        erc20.mint(newLender, amount);
        vm.startPrank(newLender);
        erc20.approve(address(facilitator), amount);

        uint256 beforeBalance = erc20.balanceOf(address(facilitator));

        facilitator.lend(
            loanId,
            interestRate,
            amount,
            uint32(increaseByMinPercent(loanDuration)),
            address(1)
        );

        uint256 amountIncrease = amount - loanAmount;
        uint256 originationFee = (amountIncrease *
            oldOriginationFee) / facilitator.SCALAR();
        assertEq(
            beforeBalance + originationFee,
            erc20.balanceOf(address(facilitator))
        );
    }

    function testBuyoutEmitsCorrectly() public {
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        uint32 newDuration = uint32(increaseByMinPercent(loanDuration));

        vm.expectEmit(true, true, true, true);
        emit BuyoutLender(loanId, newLender, lender, 0, loanAmount);

        vm.expectEmit(true, true, false, true);
        emit Lend(loanId, newLender, interestRate, loanAmount, newDuration);

        vm.prank(newLender);
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            newDuration,
            address(1)
        );
    }

    function testBuyoutFailsIfTermsNotImproved() public {
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);
        vm.expectRevert(
            "insufficient improvement"
        );
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            newLender
        );
    }

    function testBuyoutFailsIfLoanAmountNotSufficientlyImproved(uint128 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount < decreaseByMinPercent(type(uint128).max));
        loanAmount = amount;
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);
        uint256 newAmount = increaseByMinPercent(loanAmount) - 1;
        vm.expectRevert(
            "insufficient improvement"
        );
        facilitator.lend(
            loanId,
            interestRate,
            uint128(newAmount),
            loanDuration,
            newLender
        );
        vm.stopPrank();
    }

    function testBuyoutFailsIfLoanDurationNotSufficientlyImproved(uint32 duration) public {
        vm.assume(duration > 0);
        vm.assume(duration < decreaseByMinPercent(type(uint32).max));
        loanDuration = duration;
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);
        uint32 newDuration = uint32(increaseByMinPercent(duration) - 1);
        vm.expectRevert(
            "insufficient improvement"
        );
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            newDuration,
            newLender
        );
        vm.stopPrank();
    }

    function testBuyoutFailsIfInterestRateNotSufficientlyImproved(uint16 rate) public {
        interestRate = rate;
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);
        uint16 newRate = uint16(decreaseByMinPercent(rate) + 1);
        // handle case where rate is 0
        newRate = newRate < rate ? newRate : rate;
        emit log_uint(rate);
        emit log_uint(newRate);
        vm.expectRevert(
            "insufficient improvement"
        );
        facilitator.lend(loanId, newRate, loanAmount, loanDuration, newLender);
        vm.stopPrank();
    }

    function testBuyoutFailsIfLoanAmountRegressed(
        uint16 newRate,
        uint32 newDuration,
        uint128 newAmount
    ) public {
        vm.assume(newRate <= interestRate);
        vm.assume(newDuration >= loanDuration);
        vm.assume(newAmount < loanAmount);
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        facilitator.lend(
            loanId,
            newRate,
            uint128(newAmount),
            newDuration,
            newLender
        );
        vm.stopPrank();
    }

    function testBuyoutFailsIfInterestRateRegressed(
        uint16 newRate,
        uint32 newDuration,
        uint128 newAmount
    ) public {
        vm.assume(newRate > interestRate);
        vm.assume(newDuration >= loanDuration);
        vm.assume(newAmount >= loanAmount);
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);
        vm.expectRevert("rate too high");
        facilitator.lend(
            loanId,
            newRate,
            uint128(newAmount),
            newDuration,
            newLender
        );
        vm.stopPrank();
    }

    function testBuyoutFailsIfDurationRegressed(
        uint16 newRate,
        uint32 newDuration,
        uint128 newAmount
    ) public {
        vm.assume(newRate <= interestRate);
        vm.assume(newDuration < loanDuration);
        vm.assume(newAmount >= loanAmount);
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);
        vm.expectRevert("duration too low");
        facilitator.lend(
            loanId,
            newRate,
            uint128(newAmount),
            newDuration,
            newLender
        );
        vm.stopPrank();
    }

    function testRepayReentryOnBuyoutPaysNewOwner() public {
        vm.prank(borrower);
        RepayAndCloseERC20 token = new RepayAndCloseERC20(address(facilitator));
        erc20 = TestERC20(address(token));
        (uint256 tokenId, uint256 loanId) = setUpLoanWithLenderForTest(
            borrower,
            borrower
        );
        token.mint(lender, loanAmount);
        vm.startPrank(lender);
        token.approve(address(facilitator), loanAmount);
        facilitator.lend(loanId, interestRate, loanAmount, uint32(increaseByMinPercent(loanDuration)), lender);
        INFTLoanFacilitator.Loan memory loan = facilitator.loanInfoStruct(loanId);
        // before the fix the previous lender could reenter and pay themselves 
        // and close the loan
        assertEq(loan.loanAmount, token.balanceOf(lender));
    }

    function testLendReentryOnBuyoutIsNormalLend() public {
        address attacker = address(4);
        vm.prank(attacker);
        ReLendERC20 token = new ReLendERC20(address(facilitator));
        erc20 = TestERC20(address(token));
        (uint256 tokenId, uint256 loanId) = setUpLoanWithLenderForTest(
            attacker,
            attacker
        );
        token.mint(lender, loanAmount);
        vm.startPrank(lender);
        token.approve(address(facilitator), loanAmount);
        facilitator.lend(loanId, interestRate, loanAmount, uint32(increaseByMinPercent(loanDuration)), lender);
        INFTLoanFacilitator.Loan memory loan = facilitator.loanInfoStruct(loanId);
        // before the fix the previous lender could reenter, change loan terms
        // and leave other lender with them
        assertEq(loan.loanAmount, token.balanceOf(lender));
        assertEq(lendTicket.ownerOf(loanId), attacker);
    }

    function testRepayAndCloseSuccessful() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanWithLenderForTest(
            borrower,
            lender
        );
        vm.warp(startTimestamp + 10); // warp so we have some interest accrued on the loan
        vm.startPrank(borrower);

        uint256 interestAccrued = facilitator.interestOwed(loanId);
        erc20.mint(borrower, interestAccrued + calculateTake(loanAmount)); // give borrower enough money to pay back the loan
        erc20.approve(address(facilitator), loanAmount + interestAccrued);
        uint256 balanceOfBorrower = erc20.balanceOf(borrower);

        facilitator.repayAndCloseLoan(loanId);

        // ensure ERC20 balances are correct
        assertEq(
            erc20.balanceOf(borrower),
            balanceOfBorrower - (loanAmount + interestAccrued)
        );
        assertEq(erc20.balanceOf(lender), loanAmount + interestAccrued);

        assertEq(erc721.ownerOf(tokenId), borrower); // ensure borrower gets their NFT back
        (bool closed, , , , , , , , , ) = facilitator.loanInfo(loanId); // ensure loan is closed on-chain
        assertTrue(closed);
    }

    function testRepayAndCloseFailsIfLoanClosed() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);
        facilitator.closeLoan(loanId, borrower);
        vm.expectRevert("loan closed");
        facilitator.repayAndCloseLoan(loanId);
    }

    function testRepayAndCloseFailsIfNoLender() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);
        vm.expectRevert("no lender, use closeLoan");
        facilitator.repayAndCloseLoan(loanId);
    }

    function testSeizeCollateralSuccessful() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanWithLenderForTest(
            borrower,
            lender
        );
        vm.warp(startTimestamp + loanDuration + 1); // fast forward to timestamp where loan would be overdue
        vm.prank(lender);

        facilitator.seizeCollateral(loanId, lender);
        assertEq(erc721.ownerOf(tokenId), lender); // ensure lender seized collateral

        (bool closed, , , , , , , , , ) = facilitator.loanInfo(loanId); // ensure loan is closed on-chain
        assertTrue(closed);
    }

    function testSeizeCollateralFailsIfLoanNotOverdue() public {
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);
        vm.warp(startTimestamp + loanDuration); // fast forward to timestamp where loan would not be overdue
        vm.prank(lender);

        vm.expectRevert("payment is not late");
        facilitator.seizeCollateral(loanId, lender);
    }

    function testSeizeCollateralFailsIfNonLoanOwnerCalls() public {
        (, uint256 loanId) = setUpLoanWithLenderForTest(borrower, lender);
        address randomAddress = address(4);
        vm.prank(randomAddress);

        vm.expectRevert("lend ticket holder only");
        facilitator.seizeCollateral(loanId, randomAddress);
    }

    function testSeizeCollateralFailsIfLoanIsClosed() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.prank(borrower);
        facilitator.closeLoan(loanId, borrower);

        vm.startPrank(lender);
        vm.expectRevert("loan closed");
        facilitator.seizeCollateral(loanId, lender);
        vm.stopPrank();
    }

    function testUpdateOriginationFeeRevertsIfNotCalledByManager() public {
        vm.startPrank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        facilitator.updateOriginationFeeRate(1);
    }

    function testUpdateOriginationFeeRevertsIfGreaterThanFivePercent() public {
        uint256 interestRateDecimals = facilitator.INTEREST_RATE_DECIMALS();
        vm.startPrank(address(this));
        vm.expectRevert("max fee 5%");
        facilitator.updateOriginationFeeRate(
            uint32(6 * (10**(interestRateDecimals - 2)))
        );
    }

    function testUpdateOriginationFeeWorks() public {
        uint256 oldRate = facilitator.originationFeeRate();
        (, uint256 loanId) = setUpLoanForTest(address(this));

        uint256 interestRateDecimals = facilitator.INTEREST_RATE_DECIMALS();
        uint256 newRate = 2 * (10**(interestRateDecimals - 2));
        facilitator.updateOriginationFeeRate(
            uint32(newRate)
        );
        assertEq(
            facilitator.originationFeeRate(),
            uint32(newRate)
        );

        (, uint256 loanId2) = setUpLoanForTest(address(this));
        assertEq(facilitator.loanInfoStruct(loanId2).originationFeeRate, uint96(newRate));
        assertEq(facilitator.loanInfoStruct(loanId).originationFeeRate, uint96(oldRate));
    }

    function testUpdateRequiredImprovementRateRevertsIfNotCalledByManager()
        public
    {
        vm.startPrank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        facilitator.updateRequiredImprovementRate(1);
    }

    function testUpdateRequiredImprovementRateRevertsIf0() public {
        vm.startPrank(address(this));
        vm.expectRevert("0 improvement rate");
        facilitator.updateRequiredImprovementRate(0);
    }

    function testUpdateRequiredImprovementRateWorks() public {
        vm.startPrank(address(this));
        facilitator.updateRequiredImprovementRate(20 * facilitator.SCALAR());
        assertEq(
            facilitator.requiredImprovementRate(),
            20 * facilitator.SCALAR()
        );
    }

    function setUpLender(address lenderAddress) public {
        // create a lender address and give them some approved erc20
        vm.startPrank(lenderAddress);
        erc20.mint(lenderAddress, loanAmount);
        erc20.approve(address(facilitator), 2**256 - 1); // approve for lending
        vm.stopPrank();
    }

    function setUpLoanWithLenderForTest(
        address borrowerAddress,
        address lenderAddress
    ) public returns (uint256 tokenId, uint256 loanId) {
        (tokenId, loanId) = setUpLoanForTest(borrowerAddress);
        setUpLender(lenderAddress);
        vm.startPrank(lenderAddress);
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lenderAddress
        );
        vm.stopPrank();
    }

    // returns tokenId of NFT used as collateral for the loan and loanId to be used in other test methods
    function setUpLoanForTest(address borrowerAddress)
        public
        returns (uint256 tokenId, uint256 loanId)
    {
        vm.startPrank(borrowerAddress);
        tokenId = erc721.mint();
        erc721.approve(address(facilitator), tokenId);
        loanId = facilitator.createLoan(
            tokenId,
            address(erc721),
            interestRate,
            loanAmount,
            address(erc20),
            loanDuration,
            borrowerAddress
        );
        vm.stopPrank();
    }

    function increaseByMinPercent(uint256 old) public view returns (uint256) {
        return
            old +
            Math.ceilDiv(old * facilitator.requiredImprovementRate(),
            facilitator.SCALAR());
    }

    function decreaseByMinPercent(uint256 old) public view returns (uint256) {
        return
            old -
            Math.ceilDiv(old * facilitator.requiredImprovementRate(),
            facilitator.SCALAR());
    }

    function calculateTake(uint256 amount) public view returns (uint256) {
        return
            (amount * facilitator.originationFeeRate()) / facilitator.SCALAR();
    }
}

contract NFTLendTicketTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    NFTLoanFacilitator facilitator;
    BorrowTicket borrowTicket;
    LendTicket lendTicket;

    function setUp() public {
        ERC1820Registry registery = new ERC1820Registry();
        vm.etch(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24, address(registery).code);

        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (borrowTicket, lendTicket, facilitator) = factory.newFacilitator(
            address(this)
        );
    }

    function testLoanFacilitatorTransferSuccessful() public {
        address holder = address(1);
        address receiver = address(2);
        uint256 loanId = 0;

        vm.startPrank(address(facilitator));

        lendTicket.mint(holder, loanId);
        assertEq(lendTicket.ownerOf(loanId), holder);

        lendTicket.loanFacilitatorTransfer(holder, receiver, 0);
        assertEq(lendTicket.ownerOf(loanId), receiver);
    }

    function testLoanFacilitatorTransferRevertsIfNotFacilitator() public {
        vm.startPrank(address(1));
        vm.expectRevert("NFTLoanTicket: only loan facilitator");
        lendTicket.loanFacilitatorTransfer(address(1), address(2), 0);
    }
}
