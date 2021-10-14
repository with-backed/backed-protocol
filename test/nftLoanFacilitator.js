
const { expect } = require("chai");
const { waffle } = require("hardhat");
const provider = waffle.provider;

describe("NFTLoanFacilitator contract", function () {

    let NFTLoanFacilitator;
    let LendTicket;
    let CryptoPunks;
    // defaults
    var interestRateDecimals = 12
    var originationFeeRate = ethers.BigNumber.from(10).pow(interestRateDecimals - 2);
    var scalar = ethers.BigNumber.from(10).pow(interestRateDecimals);
    var interest = ethers.BigNumber.from(10).pow(4);
    var durationSeconds = ethers.BigNumber.from(10);
    var loanAmount = ethers.BigNumber.from(505).mul(ethers.BigNumber.from(10).pow(17))

    var punkId = ethers.BigNumber.from(1000);
    let BorrowTicketDescriptor;

    beforeEach(async function () {
        [manager, punkHolder, daiHolder, addr4, addr5, ...addrs] = await ethers.getSigners();        

        BorrowTicketSVGHelperContract = await ethers.getContractFactory("BorrowTicketSVGHelper");
        BorrowTicketSVGHelper = await BorrowTicketSVGHelperContract.deploy()
        await BorrowTicketSVGHelper.deployed();

        LendTicketSVGHelperContract = await ethers.getContractFactory("LendTicketSVGHelper");
        LendTicketSVGHelper = await LendTicketSVGHelperContract.deploy()
        await LendTicketSVGHelper.deployed();

        BorrowTicketDescriptorContract = await ethers.getContractFactory("BorrowTicketDescriptor");
        BorrowTicketDescriptor = await BorrowTicketDescriptorContract.deploy(BorrowTicketSVGHelper.address)
        await BorrowTicketDescriptor.deployed();

        LendTicketDescriptorContract = await ethers.getContractFactory("LendTicketDescriptor");
        LendTicketDescriptor = await LendTicketDescriptorContract.deploy(LendTicketSVGHelper.address)
        await LendTicketDescriptor.deployed();
        
        NFTLoanFacilitatorCOntract = await ethers.getContractFactory("NFTLoanFacilitator");
        NFTLoanFacilitator = await NFTLoanFacilitatorCOntract.deploy(manager.address);
        await NFTLoanFacilitator.deployed();

        LendTicketContract = await ethers.getContractFactory("LendTicket");
        LendTicket = await LendTicketContract.deploy(NFTLoanFacilitator.address, LendTicketDescriptor.address);
        await LendTicket.deployed();

        BorrowTicketContract = await ethers.getContractFactory("BorrowTicket");
        BorrowTicket = await BorrowTicketContract.deploy(NFTLoanFacilitator.address, BorrowTicketDescriptor.address);
        await BorrowTicket.deployed();

        await NFTLoanFacilitator.connect(manager).setLendTicketContract(LendTicket.address)
        await NFTLoanFacilitator.connect(manager).setBorrowTicketContract(BorrowTicket.address)

        CryptoPunksContract = await ethers.getContractFactory("CryptoPunks");
        CryptoPunks = await CryptoPunksContract.deploy();
        await CryptoPunks.deployed();

        await CryptoPunks.connect(punkHolder).mint();
        await CryptoPunks.connect(punkHolder).approve(NFTLoanFacilitator.address, punkId)


        DAIContract = await ethers.getContractFactory("DAI");
        DAI = await DAIContract.connect(daiHolder).deploy();
        await DAI.deployed();  
      });
      
    describe("tokenURI", function() {
        it("retrieves successfully", async function(){
            await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, punkHolder.address)
            // await expect(
            //     BorrowTicket.tokenURI("1")
            // ).not.to.be.reverted
            const u = await BorrowTicket.tokenURI("1")
            console.log(u)
        })
    })


    describe("createLoan", function () {
        it("sets values correctly", async function(){
            await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, addr4.address)
            const ticket = await NFTLoanFacilitator.loanInfo("1")
            expect(ticket.loanAssetContractAddress).to.equal(DAI.address)
            expect(ticket.loanAmount).to.equal(loanAmount)
            expect(ticket.collateralTokenId).to.equal(punkId)
            expect(ticket.collateralContractAddress).to.equal(CryptoPunks.address)
            expect(ticket.perSecondInterestRate).to.equal(interest)
            expect(ticket.durationSeconds).to.equal(durationSeconds)
            expect(ticket.accumulatedInterest).to.equal(0)
        })
        it("transfers NFT to contract, mints ticket", async function(){
            await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, addr4.address)
            const punkOwner = await  CryptoPunks.ownerOf(punkId)
            const ticketOwner = await BorrowTicket.ownerOf("1")
            expect(punkOwner).to.equal(NFTLoanFacilitator.address)
            expect(ticketOwner).to.equal(addr4.address)
        })

        it('reverts if not approved', async function(){
            await CryptoPunks.connect(punkHolder).mint();
            await expect(
                NFTLoanFacilitator.connect(punkHolder).createLoan(punkId.add(1), CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, addr4.address)
            ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved")
        })
    });

    describe("underwriteLoan", function () {
        context("when no loan exists", function () {
            beforeEach(async function() {
                await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, punkHolder.address)
                await DAI.connect(daiHolder).approve(NFTLoanFacilitator.address, loanAmount)
            })

            it("reverts if amount is too low", async function(){
                await expect(
                    NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount.sub(1), durationSeconds, daiHolder.address)
                    ).to.be.revertedWith("NFTLoanFacilitator: Proposed terms do not qualify")
            })

            it("reverts if interest is too high", async function(){
                await expect(
                    NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest.add(1), loanAmount, durationSeconds, daiHolder.address)
                    ).to.be.revertedWith("NFTLoanFacilitator: Proposed terms do not qualify")
            })

            it("reverts if block duration is too low", async function(){
                await expect(
                    NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds.sub(1), daiHolder.address)
                    ).to.be.revertedWith("NFTLoanFacilitator: Proposed terms do not qualify")
            })
            it("sets values correctly", async function(){
                await expect(
                        NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds, daiHolder.address)
                        ).not.to.be.reverted
                const ticket = await NFTLoanFacilitator.loanInfo("1")
                expect(ticket.loanAmount).to.equal(loanAmount)
                expect(ticket.perSecondInterestRate).to.equal(interest)
                expect(ticket.durationSeconds).to.equal(durationSeconds)
                expect(ticket.accumulatedInterest).to.equal(0)
                const block = await provider.getBlock()
                expect(ticket.lastAccumulatedTimestamp).to.equal(block.timestamp)
            })
            it("transfers loan NFT to underwriter", async function(){
                await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds, addr5.address)
                const owner = await LendTicket.ownerOf("1")
                expect(owner).to.equal(addr5.address)
            });

            it("leaves origination fee in contract", async function(){
                var value = await DAI.balanceOf(NFTLoanFacilitator.address)
                expect(value).to.equal(0)
                await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds, daiHolder.address)
                value = await DAI.balanceOf(NFTLoanFacilitator.address)
                expect(value).to.equal(loanAmount.mul(originationFeeRate).div(scalar))
            })

            it("transfers loan asset borrower", async function(){
                var value = await DAI.balanceOf(punkHolder.address)
                expect(value).to.equal(0)
                await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds, daiHolder.address)
                value = await DAI.balanceOf(punkHolder.address)
                expect(value).to.equal(loanAmount.sub(loanAmount.mul(originationFeeRate).div(scalar)))
            })

        });

        context("when loan exists", function () {
            beforeEach(async function() {
                await DAI.connect(daiHolder).approve(NFTLoanFacilitator.address, loanAmount)

                await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, punkHolder.address)
                await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds, daiHolder.address)

                await DAI.connect(daiHolder).transfer(addr4.address, loanAmount.mul(2))
                await DAI.connect(addr4).approve(NFTLoanFacilitator.address, loanAmount.mul(2))
            })

            it("reverts if terms are not improved", async function(){
                await expect(
                    NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, loanAmount, durationSeconds, daiHolder.address)
                ).to.be.revertedWith("NFTLoanFacilitator: proposed terms must be better than existing terms")
            })

            it("reverts if one value does not meet or beat exisiting, even if others are improved", async function(){
                await expect(
                        NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest.mul(90).div(100), loanAmount.sub(1), durationSeconds, addr4.address)
                        ).to.be.revertedWith("NFTLoanFacilitator: Proposed terms do not qualify")
            })

            it("does not revert if interest is less", async function(){
                await expect(
                        NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest.mul(90).div(100), loanAmount, durationSeconds, addr4.address)
                        ).not.to.be.reverted
            })

            it("does not revert if durationSeconds greater", async function(){
                await expect(
                        NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, loanAmount, durationSeconds.add(durationSeconds.mul(10).div(100)), addr4.address)
                        ).not.to.be.reverted
            })

            it("does not revert if loan amount greater", async function(){
                await expect(
                        NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, loanAmount.add(loanAmount.mul(10).div(100)), durationSeconds, addr4.address)
                        ).not.to.be.reverted
            })

            it("transfers loan token to the new underwriter", async function(){
                await NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, loanAmount.add(loanAmount.mul(10).div(100)), durationSeconds, manager.address)
                const owner = await LendTicket.ownerOf("1")
                expect(owner).to.equal(manager.address)
            });

            it("pays back previous owner", async function(){
                const beforeValue = await DAI.balanceOf(daiHolder.address)
                await NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, loanAmount.add(loanAmount.mul(10).div(100)), durationSeconds, addr4.address)
                const interestOwed = await interestOwedTotal("1")
                const afterValue = await DAI.balanceOf(daiHolder.address)
                expect(afterValue).to.equal(beforeValue.add(loanAmount).add(interestOwed))
            })

            it("sets values correctly", async function(){
                const newLoanAmount = loanAmount.add(loanAmount.mul(10).div(100))
                await NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, newLoanAmount, durationSeconds, addr4.address)
                const accumulatedInterest = await interestOwedTotal("1")
                const ticket = await NFTLoanFacilitator.loanInfo("1")
                expect(ticket.loanAmount).to.equal(newLoanAmount)
                expect(ticket.perSecondInterestRate).to.equal(interest)
                expect(ticket.durationSeconds).to.equal(durationSeconds)
                expect(ticket.accumulatedInterest).to.equal(accumulatedInterest)
                const block = await provider.getBlock()
                expect(ticket.lastAccumulatedTimestamp).to.equal(block.timestamp)
            })

            it("takes origination fee correctly", async function(){
                const increase = loanAmount.mul(10).div(100)
                const newLoanAmount = loanAmount.add(increase)
                await NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, newLoanAmount, durationSeconds, addr4.address)
                value = await DAI.balanceOf(NFTLoanFacilitator.address)
                expect(value).to.equal(loanAmount.mul(originationFeeRate).div(scalar).add(increase.mul(originationFeeRate).div(scalar)))
            })

            context("when loan amount is the same", function () {
                it('does not increase cash drawer balance', async function(){
                    var valueBefore = await DAI.balanceOf(NFTLoanFacilitator.address)
                    await NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, loanAmount, durationSeconds.add(durationSeconds.mul(10).div(100)), addr4.address)
                    var valueAfter = await DAI.balanceOf(NFTLoanFacilitator.address)
                    expect(valueBefore).to.equal(valueAfter)
                })
            })

            context('when bought out again', function() {
                it('transfers payout correctly', async function(){
                    const buyout1LoanAmount = loanAmount.add(loanAmount.mul(10).div(100))
                    const buyout2LoanAmount = buyout1LoanAmount.add(buyout1LoanAmount.mul(10).div(100))
                    
                    await DAI.connect(daiHolder).approve(NFTLoanFacilitator.address, buyout2LoanAmount.mul(2))
                    
                    await NFTLoanFacilitator.connect(addr4).underwriteLoan("1", interest, buyout1LoanAmount, durationSeconds, addr4.address)
                    const addr4BeforeBalance = await DAI.balanceOf(addr4.address)
                    await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, buyout2LoanAmount, durationSeconds, daiHolder.address)
                    const interestOwed = await interestOwedTotal("1")
                    const addr4AfterBalance = await DAI.balanceOf(addr4.address)
                    expect(addr4AfterBalance).to.equal(addr4BeforeBalance.add(buyout1LoanAmount).add(interestOwed))
                })
            })
        });
        
    });

    describe("repayAndcloseLoan", function () {
        beforeEach(async function() {
            await DAI.connect(daiHolder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))

            await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, punkHolder.address)
            await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds, daiHolder.address)
            await DAI.connect(daiHolder).transfer(punkHolder.address, loanAmount.mul(2))
            await DAI.connect(punkHolder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))
        })

        it("pays back lender", async function(){
            const balanceBefore = await DAI.balanceOf(daiHolder.address)
            await NFTLoanFacilitator.connect(punkHolder).repayAndcloseLoan("1")
            const interest = await interestOwedTotal("1")
            const balanceAfter = await DAI.balanceOf(daiHolder.address)
            expect(balanceAfter).to.equal(balanceBefore.add(loanAmount.add(interest)))
        })

        it("transfers collateral back to lendee", async function(){
            await NFTLoanFacilitator.connect(punkHolder).repayAndcloseLoan("1")
            const punkOwner = await  CryptoPunks.ownerOf(punkId)
            expect(punkOwner).to.equal(punkHolder.address)
        })

        it("closes ticket", async function(){
            await NFTLoanFacilitator.connect(punkHolder).repayAndcloseLoan("1")
            const ticket = await NFTLoanFacilitator.loanInfo("1")
            expect(ticket.closed).to.equal(true)
        })

        it("reverts if ticket is closed", async function(){
            await NFTLoanFacilitator.connect(punkHolder).repayAndcloseLoan("1")
            await expect(
                NFTLoanFacilitator.connect(punkHolder).repayAndcloseLoan("1")
            ).to.be.revertedWith("NFTLoanFacilitator: loan closed")
        })

    })

    describe("seizeCollateral", function () {
        beforeEach(async function() {
            await CryptoPunks.connect(punkHolder).mint();
            await CryptoPunks.connect(punkHolder).approve(NFTLoanFacilitator.address, punkId.add(1))
            await DAI.connect(daiHolder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))

            await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId.add(1), CryptoPunks.address, interest, loanAmount, DAI.address, 1, punkHolder.address)
            await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, 1, daiHolder.address)
        })

        it("transfers collateral to given address, closed", async function(){
            // mine on block
            await DAI.connect(daiHolder).transfer(addr4.address, ethers.BigNumber.from(1))
            // 
            await NFTLoanFacilitator.connect(daiHolder).seizeCollateral("1", addr4.address)
            const ticket = await NFTLoanFacilitator.loanInfo("1")
            expect(ticket.closed).to.equal(true)
            const punkOwner = await CryptoPunks.ownerOf(punkId.add(1))
            expect(punkOwner).to.equal(addr4.address)
        })

        it('reverts if non-loan-owner calls', async function(){
            // mine on block
            await DAI.connect(daiHolder).transfer(addr4.address, ethers.BigNumber.from(1))
            // 
            await expect(
                NFTLoanFacilitator.connect(addr4).seizeCollateral("1", addr4.address)
            ).to.be.revertedWith("NFTLoanFacilitator: underwriter only")
        })

        it("reverts if ticket is closed", async function(){
            await DAI.connect(daiHolder).approve(NFTLoanFacilitator.address, loanAmount.mul(1))
            // repay and close
            await DAI.connect(daiHolder).transfer(punkHolder.address, loanAmount.mul(2))
            await DAI.connect(punkHolder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))
            await NFTLoanFacilitator.connect(punkHolder).repayAndcloseLoan("1")
            // 
            await expect(
                NFTLoanFacilitator.connect(daiHolder).seizeCollateral("1", addr4.address)
            ).to.be.revertedWith("NFTLoanFacilitator: loan closed")
        })

        it("reverts if payment is not late", async function(){
            await expect(
                NFTLoanFacilitator.connect(daiHolder).seizeCollateral("1", addr4.address)
            ).to.be.revertedWith("NFTLoanFacilitator: payment is not late")
        })
    })

    describe("withdrawFromCashDrawer", function () {
        beforeEach(async function() {
            await DAI.connect(daiHolder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))

            await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, punkHolder.address)
            await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds, daiHolder.address)
            await DAI.connect(daiHolder).transfer(punkHolder.address, loanAmount.mul(2))
            await DAI.connect(punkHolder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))
            await NFTLoanFacilitator.connect(punkHolder).repayAndcloseLoan("1")
        })

        it("transfers ERC20 value, reduces loan payment balance", async function(){
            await expect(
                NFTLoanFacilitator.connect(daiHolder).withdrawFromCashDrawer(DAI.address, loanAmount, manager.address)
                ).to.be.reverted
        });

        it("transfers ERC20 value, reduces loan payment balance", async function(){
            const balanceBefore = await DAI.balanceOf(manager.address)
            const value = await DAI.balanceOf(NFTLoanFacilitator.address)
            expect(value).to.be.above(0)
            await expect(
                NFTLoanFacilitator.connect(manager).withdrawFromCashDrawer(DAI.address, value, manager.address)
                ).not.to.be.reverted
            const balanceAfter = await DAI.balanceOf(manager.address)
            expect(balanceAfter).to.equal(balanceBefore.add(value))

        })
        
        it("reverts if amount is greater than what is available", async function(){
            const balanceBefore = await DAI.balanceOf(manager.address)
            const value = await DAI.balanceOf(NFTLoanFacilitator.address)
            await expect(
                NFTLoanFacilitator.connect(manager).withdrawFromCashDrawer(DAI.address, value.add(1), manager.address)
                ).to.be.reverted
        })
    })

    describe("closeLoan", function () {
        beforeEach(async function() {
            await CryptoPunks.connect(punkHolder).mint();
            await CryptoPunks.connect(punkHolder).approve(NFTLoanFacilitator.address, punkId.add(1))
            await DAI.connect(daiHolder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))

            await NFTLoanFacilitator.connect(punkHolder).createLoan(punkId.add(1), CryptoPunks.address, interest, loanAmount, DAI.address, durationSeconds, punkHolder.address)
        })

        it("transfers ERC721 and closes ticket", async function(){
            await NFTLoanFacilitator.connect(punkHolder).closeLoan("1", addr4.address)
            const owner = await CryptoPunks.ownerOf(punkId.add(1))
            expect(owner).to.equal(addr4.address)
            const ticket = await NFTLoanFacilitator.loanInfo("1")
            expect(ticket.closed).to.equal(true)
        });

        it("reverts if caller is not ticket owner", async function(){
            await expect(
                NFTLoanFacilitator.connect(daiHolder).closeLoan("1", addr4.address)
                ).to.be.revertedWith("NFTLoanFacilitator: borrower only")
        });

        it("reverts if loan closed", async function(){
            await NFTLoanFacilitator.connect(punkHolder).closeLoan("1", addr4.address)
            await expect(
                NFTLoanFacilitator.connect(punkHolder).closeLoan("1", addr4.address)
            ).to.be.revertedWith("NFTLoanFacilitator: loan closed")
        });

        it("reverts if ticket has underwriter", async function(){
            await NFTLoanFacilitator.connect(daiHolder).underwriteLoan("1", interest, loanAmount, durationSeconds, daiHolder.address)
            await expect(
                NFTLoanFacilitator.connect(punkHolder).closeLoan("1", addr4.address)
            ).to.be.revertedWith("NFTLoanFacilitator: underwritten, use repayAndcloseLoan")
        });
    })

    describe("updateOriginationFee", function () {
        it("updates", async function(){
            const originalTake = ethers.BigNumber.from(1).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            var NFTLoanFacilitatorTakeRate = await NFTLoanFacilitator.originationFeeRate();
            expect(NFTLoanFacilitatorTakeRate).to.equal(originalTake)
            const newTake = ethers.BigNumber.from(5).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await NFTLoanFacilitator.connect(manager).updateOriginationFeeRate(newTake)
            NFTLoanFacilitatorTakeRate = await NFTLoanFacilitator.originationFeeRate();
            expect(NFTLoanFacilitatorTakeRate).to.equal(newTake)
        })

        it("reverts if take > 5%", async function(){
            const newTake = ethers.BigNumber.from(6).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await expect(
                NFTLoanFacilitator.connect(manager).updateOriginationFeeRate(newTake)
            ).to.be.revertedWith("NFTLoanFacilitator: max fee 5%")
        })

        it("reverts if not called by manager", async function(){
            const newTake = ethers.BigNumber.from(2).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await expect(
                NFTLoanFacilitator.connect(daiHolder).updateOriginationFeeRate(newTake)
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    async function interestOwedTotal(ticketID) {
        const ticket = await NFTLoanFacilitator.loanInfo(ticketID)
        const interest = ticket.perSecondInterestRate
        const startTimestamp = ticket.lastAccumulatedTimestamp
        const height = await provider.getBlockNumber()
        const curBlock = await provider.getBlock(height)
        const curTimestamp = curBlock.timestamp
        return ticket.loanAmount
            .mul(ethers.BigNumber.from(curTimestamp - startTimestamp))
            .mul(interest)
            .div(scalar)
            .add(ticket.accumulatedInterest)
    }

    function drawableBalance() {
        return loanAmount
        .mul(
            scalar.sub(originationFeeRate)
        )
        .div(scalar)
    }
});
    