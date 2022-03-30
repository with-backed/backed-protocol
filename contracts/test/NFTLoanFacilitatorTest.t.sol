pragma solidity 0.8.12;

import {DSTest} from "./helpers/test.sol";
import {Vm} from "./helpers/Vm.sol";

import {NFTLoanFacilitator} from "contracts/NFTLoanFacilitator.sol";
import {NFTLoanFacilitatorFactory} from "./NFTLoanFacilitatorFactory.sol";
import {BorrowTicket} from "contracts/BorrowTicket.sol";
import {LendTicket} from "contracts/LendTicket.sol";
import {CryptoPunks} from "./mocks/CryptoPunks.sol";
import {DAI} from "./mocks/DAI.sol";

contract NFTLoanFacilitatorGasBenchMarkTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    NFTLoanFacilitator facilitator;
    CryptoPunks punks = new CryptoPunks();
    DAI dai = new DAI();
    uint256 punkId;
    uint16 interestRate = 15;
    uint256 loanAmount = 1e20;
    uint32 loanDuration = 1000;
    uint256 startTimestamp = 5;

    function setUp() public {
        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (, , facilitator) = factory.newFacilitator(address(this));

        // approve for lending
        dai.mint(loanAmount * 3, address(this));
        dai.approve(address(facilitator), loanAmount * 3);

        // create a loan so we can close it or lend against it
        punkId = punks.mint();
        punks.approve(address(facilitator), punkId);
        facilitator.createLoan(
            punkId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            address(this)
        );

        // mint another punk so we can create a second loan
        punks.mint();
        punks.approve(address(facilitator), punkId + 1);

        // prevent errors from timestamp 0
        vm.warp(startTimestamp);

        // create another loan and lend against it so we can buyout or repay
        punks.mint();
        punks.approve(address(facilitator), punkId + 2);
        facilitator.createLoan(
            punkId + 2,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
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
            punkId + 1,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
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
    ) public returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract NFTLoanFacilitatorFuzzTests is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    NFTLoanFacilitator facilitator;
    CryptoPunks nftContract = new CryptoPunks();
    DAI erc20Contract = new DAI();
    uint256 nftId;
    uint16 interestRate = 15;
    uint256 loanAmount = 1e20;
    uint32 loanDuration = 1000;
    uint256 startTimestamp = 5;

    function setUp() public {
        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (, , facilitator) = factory.newFacilitator(address(this));

        vm.startPrank(address(1));
        nftId = nftContract.mint();
        nftContract.approve(address(facilitator), nftId);
        facilitator.createLoan(
            nftId,
            address(nftContract),
            interestRate,
            loanAmount,
            address(erc20Contract),
            loanDuration,
            address(address(1))
        );
        vm.stopPrank();
    }

    function testFuzzedLend(
        uint16 rate,
        uint256 amount,
        uint32 duration,
        address sendTo
    ) public {
        vm.assume(rate <= interestRate);
        vm.assume(amount >= loanAmount);
        vm.assume(duration >= loanDuration);
        vm.assume(sendTo != address(0));
        vm.assume(amount < type(uint256).max / 10); // else origination fee multiplication overflows

        erc20Contract.mint(amount, address(this));
        erc20Contract.approve(address(facilitator), amount);

        facilitator.lend(1, rate, amount, duration, sendTo);
    }

    function testCreateAndCloseLoan(
        address caller,
        uint16 maxPerAnumInterest,
        uint256 minLoanAmount,
        uint32 minDurationSeconds,
        address mintTo
    ) public {
        vm.assume(minLoanAmount > 0);
        vm.assume(minDurationSeconds > 0);
        vm.assume(mintTo != address(0));
        vm.assume(caller != address(0));

        vm.startPrank(caller);
        uint256 nftId = nftContract.mint();
        nftContract.approve(address(facilitator), nftId);

        uint256 loanId = facilitator.createLoan(
            nftId,
            address(nftContract),
            maxPerAnumInterest,
            minLoanAmount,
            address(erc20Contract),
            minDurationSeconds,
            mintTo
        );
        vm.stopPrank();

        vm.prank(mintTo);
        facilitator.closeLoan(loanId, mintTo);
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
    Vm vm = Vm(HEVM_ADDRESS);

    NFTLoanFacilitator facilitator;
    BorrowTicket borrowTicket;
    LendTicket lendTicket;

    address borrower = address(1);
    address lender = address(2);

    CryptoPunks punks = new CryptoPunks();
    DAI dai = new DAI();

    uint16 interestRate = 15;
    uint256 loanAmount = 1e20;
    uint32 loanDuration = 1000;
    uint256 startTimestamp = 5;

    function setUp() public {
        NFTLoanFacilitatorFactory factory = new NFTLoanFacilitatorFactory();
        (borrowTicket, lendTicket, facilitator) = factory.newFacilitator(
            address(this)
        );
        vm.warp(startTimestamp);
    }

    function testSuccessfulCreateLoan() public {
        vm.startPrank(borrower);

        uint256 punkId = punks.mint();
        punks.approve(address(facilitator), punkId);

        // ensure CreateLoan event gets emitted
        vm.expectEmit(true, true, false, true);
        emit CreateLoan(
            1,
            borrower,
            punkId,
            address(punks),
            interestRate,
            address(dai),
            loanAmount,
            loanDuration
        );
        uint256 loanId = facilitator.createLoan(
            punkId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            borrower
        );

        assertTrue(borrowTicket.ownerOf(loanId) == borrower); // make sure borrower was minted borrow ticket
        assertTrue(punks.ownerOf(punkId) == address(facilitator)); // make sure custody of punk was transferred to facilitator

        // verify mutable struct fields were stored on-chain
        (
            bool closed,
            uint16 perAnumInterestRate,
            uint32 durationSeconds,
            uint40 lastAccumulatedTimestamp,
            address collateralContractAddress,
            address loanAssetContractAddress,
            uint256 accumulatedInterest,
            uint256 loanAmountFromLoan,
            uint256 collateralTokenId
        ) = facilitator.loanInfo(loanId);
        assertTrue(!closed);
        assertEq(durationSeconds, loanDuration);
        assertEq(perAnumInterestRate, interestRate);
        assertEq(lastAccumulatedTimestamp, 0);
        assertEq(accumulatedInterest, 0);
        assertEq(collateralContractAddress, address(punks));
        assertEq(collateralTokenId, punkId);
        assertEq(loanAmountFromLoan, loanAmount);
    }

    function testBorrowTicketUnusableAsCollateral() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        // make sure user cannot use borrow ticket as collateral
        borrowTicket.approve(address(facilitator), loanId);
        vm.expectRevert("NFTLoanFacilitator: cannot use tickets as collateral");
        facilitator.createLoan(
            loanId,
            address(borrowTicket),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            borrower
        );
    }

    function testSuccessfulCloseLoan() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        facilitator.closeLoan(loanId, borrower);
        assertEq(punks.ownerOf(tokenId), borrower); // make sure borrower gets their NFT back
        (bool closed, , , , , , , , ) = facilitator.loanInfo(loanId);
        assertTrue(closed); // make sure loan was closed
    }

    function testClosingAlreadyClosedLoan() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        facilitator.closeLoan(loanId, borrower);

        // closing an already closed loan should revert
        vm.expectRevert("NFTLoanFacilitator: loan closed");
        facilitator.closeLoan(loanId, borrower);
    }

    function testClosingLoanWithLender() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        dai.mint(loanAmount, borrower);
        dai.approve(address(facilitator), loanAmount); // approve for lending
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
            "NFTLoanFacilitator: has lender, use repayAndCloseLoan"
        );
        facilitator.closeLoan(loanId, borrower);
    }

    function testClosingLoanFromNonBorrower() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);

        vm.startPrank(address(2));
        vm.expectRevert("NFTLoanFacilitator: borrower only");
        facilitator.closeLoan(loanId, borrower);
    }

    function testSuccessfulLend() public {
        (uint256 tokenId, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);
        uint256 lenderBalance = dai.balanceOf(lender);

        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            lender
        );
        (
            ,
            uint16 interest,
            ,
            uint40 lastAccumulatedTimestamp,
            ,
            ,
            uint256 accumulatedInterest,
            ,

        ) = facilitator.loanInfo(loanId);
        assertEq(lastAccumulatedTimestamp, startTimestamp);
        assertEq(accumulatedInterest, 0);

        // make sure lenders dai is transfered and lender gets lend ticket
        assertEq(dai.balanceOf(lender), lenderBalance - loanAmount);
        assertEq(lendTicket.ownerOf(loanId), lender);

        // make sure Facilitator subtracted origination fee
        uint256 facilitatorTake = (loanAmount *
            facilitator.originationFeeRate()) / facilitator.SCALAR();
        assertEq(dai.balanceOf(address(facilitator)), facilitatorTake);

        // make sure borrower got their loan in DAI
        assertEq(dai.balanceOf(borrower), loanAmount - facilitatorTake);
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
            address loanAssetContractAddress,
            uint256 accumulatedInterest,
            uint256 loanAmountFromLoan,
            uint256 collateralTokenId
        ) = facilitator.loanInfo(loanId);
        assertTrue(!closed);
        assertEq(interestRate, interest);
        assertEq(lastAccumulatedTimestamp, startTimestamp);
        assertEq(accumulatedInterest, 0);
        assertEq(collateralContractAddress, address(punks));
        assertEq(loanAssetContractAddress, address(dai));
        assertEq(loanAmountFromLoan, loanAmount);
        assertEq(collateralTokenId, tokenId);
    }

    function testLendFailsIfHigherInterestRate() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);
        vm.expectRevert("NFTLoanFacilitator: rate too high");
        facilitator.lend(
            loanId,
            interestRate + 1,
            loanAmount,
            loanDuration,
            lender
        );
    }

    function testLendFailsIfLowerAmount() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);
        vm.expectRevert("NFTLoanFacilitator: amount too low");
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount - 1,
            loanDuration,
            lender
        );
    }

    function testLendwriteFailsIfLowerDuration() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);

        setUpLender(lender);
        vm.startPrank(lender);
        vm.expectRevert("NFTLoanFacilitator: duration too low");
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration - 1,
            lender
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
        vm.warp(startTimestamp + (60*60*24*365));
        assertEq(facilitator.interestOwed(loanId), 999999999997963200);
    }

    function testBuyoutSuccessfulWithLowerInterest() public {
        (, uint256 loanId) = setUpLendwrittenLoanForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);

        uint256 newTimestamp = startTimestamp + 10;
        vm.warp(newTimestamp);
        uint256 interestAccrued = facilitator.interestOwed(loanId);
        dai.mint(interestAccrued, newLender); // make sure new lender has amount to pay back old lender + interest
        uint256 balanceOfNewLender = dai.balanceOf(newLender);

        uint16 newInterestRate = uint16(
            decreaseByMinPercent(uint256(interestRate))
        );
        facilitator.lend(
            loanId,
            newInterestRate,
            loanAmount,
            loanDuration,
            newLender
        );
        (
            ,
            uint16 newInterestRateFromLoan,
            ,
            uint40 lastAccumulatedTimestamp,
            ,
            ,
            uint256 accumulatedInterest,
            ,

        ) = facilitator.loanInfo(loanId);
        assertEq(newInterestRateFromLoan, newInterestRate);
        assertEq(lastAccumulatedTimestamp, newTimestamp);
        assertEq(accumulatedInterest, interestAccrued);

        // make sure lend ticket gets transferred
        assertEq(lendTicket.ownerOf(loanId), newLender);

        // make sure old lender gets their dai + interest back, and new lender has no dai
        assertEq(dai.balanceOf(lender), loanAmount + interestAccrued);
        assertEq(
            dai.balanceOf(newLender),
            balanceOfNewLender - (loanAmount + interestAccrued)
        );
    }

    function testBuyoutSuccessfulWithLowerDuration() public {
        (, uint256 loanId) = setUpLendwrittenLoanForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);

        uint32 newDuration = uint32(
            increaseByMinPercent(uint256(loanDuration))
        );
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            newDuration,
            newLender
        );
        (, , uint32 durationFromLoan, , , , , , ) = facilitator.loanInfo(
            loanId
        );
        assertEq(durationFromLoan, newDuration);

        // make sure lend ticket gets transferred
        assertEq(lendTicket.ownerOf(loanId), newLender);
    }

    function testBuyoutSuccessfulWithHigherAmount() public {
        (, uint256 loanId) = setUpLendwrittenLoanForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);

        uint256 newAmount = increaseByMinPercent(loanAmount);
        uint256 amountIncrease = newAmount - loanAmount;
        dai.mint(amountIncrease, newLender);
        uint256 balanceOfNewLender = dai.balanceOf(newLender);

        facilitator.lend(
            loanId,
            interestRate,
            newAmount,
            loanDuration,
            newLender
        );

        // make sure lend ticket gets transferred
        assertEq(lendTicket.ownerOf(loanId), newLender);

        uint256 facilitatorTake = calculateTake(newAmount);
        assertEq(dai.balanceOf(lender), loanAmount); // make sure ERC20 balances are correct -- we didn't warp timestamp, so no interest was accrued
        assertEq(dai.balanceOf(newLender), balanceOfNewLender - newAmount); // new lender lent out all their dai to improve terms in loan amount
        assertEq(dai.balanceOf(borrower), newAmount - facilitatorTake); // borrower gets new improved loan amount, minus facilitator take
    }

    function testBuyoutFailsIfTermsNotImproved() public {
        (, uint256 loanId) = setUpLendwrittenLoanForTest(borrower, lender);

        address newLender = address(3);
        setUpLender(newLender);
        vm.startPrank(newLender);
        vm.expectRevert(
            "NFTLoanFacilitator: proposed terms must be better than existing terms"
        );
        facilitator.lend(
            loanId,
            interestRate,
            loanAmount,
            loanDuration,
            newLender
        );
    }

    function testRepayAndCloseSuccessful() public {
        (uint256 tokenId, uint256 loanId) = setUpLendwrittenLoanForTest(
            borrower,
            lender
        );
        vm.warp(startTimestamp + 10); // warp so we have some interest accrued on the loan
        vm.startPrank(borrower);

        uint256 interestAccrued = facilitator.interestOwed(loanId);
        dai.mint(interestAccrued + calculateTake(loanAmount), borrower); // give borrower enough money to pay back the loan
        dai.approve(address(facilitator), loanAmount + interestAccrued);
        uint256 balanceOfBorrower = dai.balanceOf(borrower);

        facilitator.repayAndCloseLoan(loanId);

        // ensure ERC20 balances are correct
        assertEq(
            dai.balanceOf(borrower),
            balanceOfBorrower - (loanAmount + interestAccrued)
        );
        assertEq(dai.balanceOf(lender), loanAmount + interestAccrued);

        assertEq(punks.ownerOf(tokenId), borrower); // ensure borrower gets their NFT back
        (bool closed, , , , , , , , ) = facilitator.loanInfo(loanId); // ensure loan is closed on-chain
        assertTrue(closed);
    }

    function testRepayAndCloseFailsIfLoanClosed() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);
        facilitator.closeLoan(loanId, borrower);
        vm.expectRevert("NFTLoanFacilitator: loan closed");
        facilitator.repayAndCloseLoan(loanId);
    }

    function testSeizeCollateralSuccessful() public {
        (uint256 tokenId, uint256 loanId) = setUpLendwrittenLoanForTest(
            borrower,
            lender
        );
        vm.warp(startTimestamp + loanDuration + 1); // fast forward to timestamp where loan would be overdue
        vm.prank(lender);

        facilitator.seizeCollateral(loanId, lender);
        assertEq(punks.ownerOf(tokenId), lender); // ensure lender seized collateral

        (bool closed, , , , , , , , ) = facilitator.loanInfo(loanId); // ensure loan is closed on-chain
        assertTrue(closed);
    }

    function testSeizeCollateralFailsIfLoanNotOverdue() public {
        (uint256 tokenId, uint256 loanId) = setUpLendwrittenLoanForTest(
            borrower,
            lender
        );
        vm.warp(startTimestamp + loanDuration); // fast forward to timestamp where loan would not be overdue
        vm.prank(lender);

        vm.expectRevert("NFTLoanFacilitator: payment is not late");
        facilitator.seizeCollateral(loanId, lender);
    }

    function testSeizeCollateralFailsIfNonLoanOwnerCalls() public {
        (uint256 tokenId, uint256 loanId) = setUpLendwrittenLoanForTest(
            borrower,
            lender
        );
        address randomAddress = address(4);
        vm.prank(randomAddress);

        vm.expectRevert("NFTLoanFacilitator: loan ticket holder only");
        facilitator.seizeCollateral(loanId, randomAddress);
    }

    function testSeizeCollateralFailsIfLoanIsClosed() public {
        (, uint256 loanId) = setUpLoanForTest(borrower);
        vm.startPrank(borrower);
        facilitator.closeLoan(loanId, borrower);

        vm.startPrank(lender);
        vm.expectRevert("NFTLoanFacilitator: loan closed");
        facilitator.seizeCollateral(loanId, lender);
    }

    function testUpdateOriginationFeeRevertsIfNotCalledByManager() public {
        vm.startPrank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        facilitator.updateOriginationFeeRate(1);
    }

    function testUpdateOriginationFeeRevertsIfGreaterThanFivePercent() public {
        uint256 interestRateDecimals = facilitator.INTEREST_RATE_DECIMALS();
        vm.startPrank(address(this));
        vm.expectRevert("NFTLoanFacilitator: max fee 5%");
        facilitator.updateOriginationFeeRate(
            uint32(6 * (10**(interestRateDecimals - 2)))
        );
    }

    function testUpdateOriginationFeeWorks() public {
        uint256 interestRateDecimals = facilitator.INTEREST_RATE_DECIMALS();
        vm.startPrank(address(this));
        facilitator.updateOriginationFeeRate(
            uint32(2 * (10**(interestRateDecimals - 2)))
        );
        assertEq(
            facilitator.originationFeeRate(),
            uint32(2 * (10**(interestRateDecimals - 2)))
        );
    }

    function testUpdateRequiredImprovementRateRevertsIfNotCalledByManager()
        public
    {
        vm.startPrank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        facilitator.updateRequiredImprovementRate(1);
    }

    function testUpdateRequiredImprovementRateRevertsIf0()
        public
    {
        vm.startPrank(address(this));
        vm.expectRevert("NFTLoanFacilitator: 0 improvement rate");
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
        // create a lender address and give them some approved dai
        vm.startPrank(lenderAddress);
        dai.mint(loanAmount, lenderAddress);
        dai.approve(address(facilitator), 2**256 - 1); // approve for lending
        vm.stopPrank();
    }

    function setUpLendwrittenLoanForTest(
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
            lender
        );
    }

    // returns tokenId of NFT used as collateral for the loan and loanId to be used in other test methods
    function setUpLoanForTest(address borrowerAddress)
        public
        returns (uint256 tokenId, uint256 loanId)
    {
        vm.startPrank(borrowerAddress);
        tokenId = punks.mint();
        punks.approve(address(facilitator), tokenId);
        loanId = facilitator.createLoan(
            tokenId,
            address(punks),
            interestRate,
            loanAmount,
            address(dai),
            loanDuration,
            borrower
        );
        vm.stopPrank();
    }

    function increaseByMinPercent(uint256 old) public returns (uint256) {
        return
            old +
            old * 
            facilitator.requiredImprovementRate() /
            facilitator.SCALAR();
    }

    function decreaseByMinPercent(uint256 old) public returns (uint256) {
        return old - old * facilitator.requiredImprovementRate() / facilitator.SCALAR();
    }

    function calculateTake(uint256 amount) public returns (uint256) {
        return
            (amount * facilitator.originationFeeRate()) /
            facilitator.SCALAR();
    }
}

contract NFTLendTicketTest is DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    NFTLoanFacilitator facilitator;
    BorrowTicket borrowTicket;
    LendTicket lendTicket;

    function setUp() public {
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
