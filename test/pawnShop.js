
const { expect } = require("chai");
const { waffle } = require("hardhat");
const provider = waffle.provider;

describe("PawnShop contract", function () {

    let PawnShop;
    let PawnLoans;
    let CryptoPunks;
    // defaults
    var interestRateDecimals = 11
    var originationFeeRate = ethers.BigNumber.from(10).pow(interestRateDecimals - 2);
    var scalar = ethers.BigNumber.from(10).pow(interestRateDecimals);
    var interest = ethers.BigNumber.from(10).pow(4);
    var blocks = ethers.BigNumber.from(10);
    var loanAmount = ethers.BigNumber.from(505).mul(ethers.BigNumber.from(10).pow(17))

    var punkId = "1"
    let PawnTicketDescriptor;

    beforeEach(async function () {
        [manager, punkHolder, daiHolder, addr4, ...addrs] = await ethers.getSigners();        

        PawnShopNFTDescriptorContract = await ethers.getContractFactory("PawnShopNFTDescriptor");
        PawnShopNFTDescriptor = await PawnShopNFTDescriptorContract.deploy()
        await PawnShopNFTDescriptor.deployed();
        
        PawnShopContract = await ethers.getContractFactory("NFTPawnShop");
        PawnShop = await PawnShopContract.deploy(manager.address, PawnShopNFTDescriptor.address);
        await PawnShop.deployed();

        PawnLoansContract = await ethers.getContractFactory("PawnLoans");
        PawnLoans = await PawnLoansContract.deploy(PawnShop.address, PawnShopNFTDescriptor.address);
        await PawnLoans.deployed();

        await PawnShop.connect(manager).setPawnLoansContract(PawnLoans.address)

        CryptoPunksContract = await ethers.getContractFactory("CryptoPunks");
        CryptoPunks = await CryptoPunksContract.deploy();
        await CryptoPunks.deployed();

        await CryptoPunks.connect(punkHolder).mint();
        await CryptoPunks.connect(punkHolder).approve(PawnShop.address, punkId)


        DAIContract = await ethers.getContractFactory("DAI");
        DAI = await DAIContract.connect(daiHolder).deploy();
        await DAI.deployed();  
      });
      
    describe("tokenURI", function() {
        it("retrieves successfully", async function(){
            await expect(
                PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
            ).not.to.be.reverted
        })
    })


    describe("mintPawnTicket", function () {
        it("sets values correctly", async function(){
            await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
            const ticket = await PawnShop.ticketInfo("1")
            expect(ticket.loanAsset).to.equal(DAI.address)
            expect(ticket.loanAmount).to.equal(loanAmount)
            expect(ticket.collateralID).to.equal(punkId)
            expect(ticket.collateralAddress).to.equal(CryptoPunks.address)
            expect(ticket.perBlockInterestRate).to.equal(interest)
            expect(ticket.blockDuration).to.equal(blocks)
            expect(ticket.accumulatedInterest).to.equal(0)
        })
        it("transfers NFT to contract, mints ticket", async function(){
            await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
            const punkOwner = await  CryptoPunks.ownerOf(punkId)
            const ticketOwner = await PawnShop.ownerOf(punkId)
            expect(punkOwner).to.equal(PawnShop.address)
            expect(ticketOwner).to.equal(punkHolder.address)
        })
    });

    describe("underwritePawnLoan", function () {
        context("when no loan exists", function () {
            beforeEach(async function() {
                await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
                await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount)
            })

            it("reverts if amount is too low", async function(){
                await expect(
                    PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount.sub(1))
                    ).to.be.revertedWith("NFTPawnShop: Proposed terms do not qualify")
            })

            it("reverts if interest is too high", async function(){
                await expect(
                    PawnShop.connect(daiHolder).underwritePawnLoan("1", interest.add(1), blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: Proposed terms do not qualify")
            })

            it("reverts if block duration is too low", async function(){
                await expect(
                    PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks.sub(1), loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: Proposed terms do not qualify")
            })
            it("sets values correctly", async function(){
                await expect(
                        PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount)
                        ).not.to.be.reverted
                const ticket = await PawnShop.ticketInfo("1")
                expect(ticket.loanAmount).to.equal(loanAmount)
                expect(ticket.perBlockInterestRate).to.equal(interest)
                expect(ticket.blockDuration).to.equal(blocks)
                expect(ticket.accumulatedInterest).to.equal(0)
                const block = await provider.getBlockNumber()
                expect(ticket.lastAccumulatedInterestBlock).to.equal(block)
            })
            it("transfers loan NFT to underwriter", async function(){
                await PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount)
                const owner = await PawnLoans.ownerOf("1")
                expect(owner).to.equal(daiHolder.address)
            });

            it("updates cash drawer", async function(){
                var value = await PawnShop.cashDrawer(DAI.address)
                expect(value).to.equal(0)
                await PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount)
                value = await PawnShop.cashDrawer(DAI.address)
                expect(value).to.equal(loanAmount.mul(originationFeeRate).div(scalar))
            })

        });

        context("when loan exists", function () {
            beforeEach(async function() {
                await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount)

                await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
                await PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount)

                await DAI.connect(daiHolder).transfer(addr4.address, loanAmount.mul(2))
                await DAI.connect(addr4).approve(PawnShop.address, loanAmount.mul(2))
            })

            it("reverts if amount is too low", async function(){
                await expect(
                    PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: proposed terms must be better than existing terms")
            })

            it("reverts if interest is too high", async function(){
                await expect(
                    PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: proposed terms must be better than existing terms")
            })

            it("reverts if block duration is too low", async function(){
                await expect(
                    PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: proposed terms must be better than existing terms")
            })

            it("does not revert if interest is less", async function(){
                await expect(
                        PawnShop.connect(addr4).underwritePawnLoan("1", interest.sub(1), blocks, loanAmount)
                        ).not.to.be.reverted
            })

            it("does not revert if blocks greater", async function(){
                await expect(
                        PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks.add(1), loanAmount)
                        ).not.to.be.reverted
            })

            it("does not revert if loan amount greater", async function(){
                await expect(
                        PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks, loanAmount.add(1))
                        ).not.to.be.reverted
            })

            it("transfers loan token to the new underwriter", async function(){
                await PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks, loanAmount.add(1))
                const owner = await PawnLoans.ownerOf("1")
                expect(owner).to.equal(addr4.address)
            });

            it("updates payback balance of previous owner", async function(){
                const ticket = await PawnShop.ticketInfo("1")
                const interestOwed = await interestOwedTotal("1")
                await PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks, loanAmount.add(1))
                var loanPaymentBalance = await PawnShop.loanPaymentBalance("1", daiHolder.address)
                expect(loanPaymentBalance).to.equal(loanAmount.add(interestOwed))
            })

            it("sets values correctly", async function(){
                const accumulatedInterest = await interestOwedTotal("1")
                await PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks, loanAmount.add(1))
                const ticket = await PawnShop.ticketInfo("1")
                expect(ticket.loanAmount).to.equal(loanAmount.add(1))
                expect(ticket.perBlockInterestRate).to.equal(interest)
                expect(ticket.blockDuration).to.equal(blocks)
                expect(ticket.accumulatedInterest).to.equal(accumulatedInterest)
                const block = await provider.getBlockNumber()
                expect(ticket.lastAccumulatedInterestBlock).to.equal(block)
            })

            it("updates cash drawer", async function(){
                await PawnShop.connect(addr4).underwritePawnLoan("1", interest, blocks, loanAmount.add(100))
                value = await PawnShop.cashDrawer(DAI.address)
                expect(value).to.equal(loanAmount.mul(originationFeeRate).div(scalar).add(ethers.BigNumber.from(100).mul(originationFeeRate).div(scalar)))
            })
        });
        
    });

    describe("drawLoan", function () {
        beforeEach(async function() {
            await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount.mul(2))

            await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
            await PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount)

            // transfer extra DAI to the pawnshop, so that reverts do not rely on ERC20 balance
            await DAI.connect(daiHolder).transfer(PawnShop.address, loanAmount.mul(2))
        })
        
        it("transfers amount to lendee", async function(){
            const balanceBefore = await DAI.balanceOf(punkHolder.address);
            expect(balanceBefore).to.equal(0)
            await PawnShop.connect(punkHolder).drawLoan("1", drawableBalance());
            const balanceAfter = await DAI.balanceOf(punkHolder.address);
            expect(balanceAfter).to.equal(drawableBalance())
        })

        it("does not allow if amount exceeds drawable amount", async function(){
            await expect(
                PawnShop.connect(punkHolder).drawLoan("1", drawableBalance().add(1))
            ).to.be.reverted
        })

        it("does not allow if amount exceeds drawable amount", async function(){
            PawnShop.connect(punkHolder).drawLoan("1", drawableBalance().sub(10))
            await expect(
                PawnShop.connect(punkHolder).drawLoan("1", drawableBalance().add(11))
            ).to.be.reverted
        })

        it("does not allow if amount exceeds drawable amount", async function(){
            PawnShop.connect(punkHolder).drawLoan("1", drawableBalance().sub(10))
            await expect(
                PawnShop.connect(punkHolder).drawLoan("1", drawableBalance().sub(4))
            ).to.be.reverted
        })

        it("does not allow if ticket is closed be repayment", async function(){
            await DAI.connect(daiHolder).transfer(punkHolder.address, loanAmount.mul(2))
            await DAI.connect(punkHolder).approve(PawnShop.address, loanAmount.mul(2))
            await PawnShop.connect(punkHolder).repayAndCloseTicket("1")
            await expect(
                PawnShop.connect(punkHolder).drawLoan("1", drawableBalance())
            ).to.be.revertedWith("NFTPawnShop: ticket closed")

        })

        it("does allow if ticket is closed by seizure", async function(){
            await CryptoPunks.connect(punkHolder).mint();
            await CryptoPunks.connect(punkHolder).approve(PawnShop.address, "2")
            await PawnShop.connect(punkHolder).mintPawnTicket("2", CryptoPunks.address, interest, loanAmount, DAI.address, 1)
            await PawnShop.connect(daiHolder).underwritePawnLoan("2", interest, 1, loanAmount)
            // mine on block
            await DAI.connect(daiHolder).transfer(addr4.address, loanAmount)
            // 
            await PawnShop.connect(daiHolder).seizeCollateral("2")
            await PawnShop.connect(punkHolder).drawLoan("2", drawableBalance());
            const balanceAfter = await DAI.balanceOf(punkHolder.address);
            expect(balanceAfter).to.equal(drawableBalance())

        })

        it("reverts if caller is not owner of pawned item", async function(){
            await expect( 
                PawnShop.connect(addr4).drawLoan("1", drawableBalance())
            ).to.be.revertedWith("NFTPawnShop: must be owner of pawned item")
        })

        it("updates loan amount drawn", async function(){
            var ticket = await PawnShop.ticketInfo("1")
            expect(ticket.loanAmountDrawn).to.equal(0);
            await PawnShop.connect(punkHolder).drawLoan("1", drawableBalance());
            ticket = await PawnShop.ticketInfo("1")
            expect(ticket.loanAmountDrawn).to.equal(drawableBalance());
        })

    })

    describe("repayAndCloseTicket", function () {
        beforeEach(async function() {
            await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount.mul(2))

            await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
            await PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount)
            await DAI.connect(daiHolder).transfer(punkHolder.address, loanAmount.mul(2))
            await DAI.connect(punkHolder).approve(PawnShop.address, loanAmount.mul(2))
            await PawnShop.connect(punkHolder).drawLoan("1", drawableBalance())
        })

        it("updates lenders loan payment balance", async function(){
            const interest = await interestOwedTotal("1")
            await PawnShop.connect(punkHolder).repayAndCloseTicket("1")
            const balance = await PawnShop.loanPaymentBalance("1", daiHolder.address)
            expect(balance).to.equal(loanAmount.add(interest))
        })

        it("transfers collateral back to lendee", async function(){
            await PawnShop.connect(punkHolder).repayAndCloseTicket("1")
            const punkOwner = await  CryptoPunks.ownerOf(punkId)
            expect(punkOwner).to.equal(punkHolder.address)
        })

        it("closes ticket and sets amount withdrawn to 0", async function(){
            await PawnShop.connect(punkHolder).repayAndCloseTicket("1")
            const ticket = await PawnShop.ticketInfo("1")
            expect(ticket.closed).to.equal(true)
            expect(ticket.loanAmountDrawn).to.equal(0)
        })

        it("reverts if ticket is closed", async function(){
            await PawnShop.connect(punkHolder).repayAndCloseTicket("1")
            await expect(
                PawnShop.connect(punkHolder).repayAndCloseTicket("1")
            ).to.be.revertedWith("NFTPawnShop: ticket closed")
        })

    })

    describe("seizeCollateral", function () {
        beforeEach(async function() {
             await CryptoPunks.connect(punkHolder).mint();
            await CryptoPunks.connect(punkHolder).approve(PawnShop.address, "2")
            await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount.mul(2))

            await PawnShop.connect(punkHolder).mintPawnTicket("2", CryptoPunks.address, interest, loanAmount, DAI.address, 1)
            await PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, 1, loanAmount)
        })

        it("transfers collateral to loan owner, closed", async function(){
            // mine on block
            await DAI.connect(daiHolder).transfer(addr4.address, ethers.BigNumber.from(1))
            // 
            await PawnShop.connect(daiHolder).seizeCollateral("1")
            const ticket = await PawnShop.ticketInfo("1")
            expect(ticket.closed).to.equal(true)
            expect(ticket.collateralSeized).to.equal(true)
            const punkOwner = await CryptoPunks.ownerOf("2")
            expect(punkOwner).to.equal(daiHolder.address)
        })

        it("reverts if ticket is closed", async function(){
            await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount.mul(1))
            // repay and close
            await DAI.connect(daiHolder).transfer(punkHolder.address, loanAmount.mul(2))
            await DAI.connect(punkHolder).approve(PawnShop.address, loanAmount.mul(2))
            await PawnShop.connect(punkHolder).repayAndCloseTicket("1")
            // 
            await expect(
                PawnShop.connect(punkHolder).seizeCollateral("1")
            ).to.be.revertedWith("NFTPawnShop: ticket closed")
        })

        it("reverts if payment is not late", async function(){
            await expect(
                PawnShop.connect(punkHolder).seizeCollateral("1")
            ).to.be.revertedWith("NFTPawnShop: payment is not late")
        })
    })

    describe("withdrawLoanPayment", function () {
        beforeEach(async function() {
            await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount.mul(2))

            await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
            await PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount)
            await DAI.connect(daiHolder).transfer(punkHolder.address, loanAmount.mul(2))
            await DAI.connect(punkHolder).approve(PawnShop.address, loanAmount.mul(2))
            await PawnShop.connect(punkHolder).drawLoan("1", drawableBalance())
            await PawnShop.connect(punkHolder).repayAndCloseTicket("1")
        })

        it("transfers ERC20 value, reduces loan payment balance", async function(){
            const balanceBefore = await DAI.balanceOf(daiHolder.address)
            const value = await PawnShop.loanPaymentBalance("1", daiHolder.address)
            await expect(
                PawnShop.connect(daiHolder).withdrawLoanPayment("1", value)
                ).not.to.be.reverted
            const balanceAfter = await DAI.balanceOf(daiHolder.address)
            expect(balanceAfter).to.equal(balanceBefore.add(value))
        })
        
        it("reverts if amount is greater than what is available", async function(){
            const value = await PawnShop.loanPaymentBalance("1", daiHolder.address)
            await expect(
                PawnShop.connect(daiHolder).withdrawLoanPayment("1", value.add(1))
                ).to.be.reverted
        })
    })

    describe("withdrawFromCashDrawer", function () {
        beforeEach(async function() {
            await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount.mul(2))

            await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
            await PawnShop.connect(daiHolder).underwritePawnLoan("1", interest, blocks, loanAmount)
            await DAI.connect(daiHolder).transfer(punkHolder.address, loanAmount.mul(2))
            await DAI.connect(punkHolder).approve(PawnShop.address, loanAmount.mul(2))
            await PawnShop.connect(punkHolder).drawLoan("1", drawableBalance())
            await PawnShop.connect(punkHolder).repayAndCloseTicket("1")
        })

        it("transfers ERC20 value, reduces loan payment balance", async function(){
            await expect(
                PawnShop.connect(daiHolder).withdrawFromCashDrawer(DAI.address, loanAmount, manager.address)
                ).to.be.reverted
        });

        it("transfers ERC20 value, reduces loan payment balance", async function(){
            const balanceBefore = await DAI.balanceOf(manager.address)
            const value = await PawnShop.cashDrawer(DAI.address)
            expect(value).to.be.above(0)
            await expect(
                PawnShop.connect(manager).withdrawFromCashDrawer(DAI.address, value, manager.address)
                ).not.to.be.reverted
            const balanceAfter = await DAI.balanceOf(manager.address)
            expect(balanceAfter).to.equal(balanceBefore.add(value))

        })
        
        it("reverts if amount is greater than what is available", async function(){
            const balanceBefore = await DAI.balanceOf(manager.address)
            const value = await PawnShop.cashDrawer(DAI.address)
            await expect(
                PawnShop.connect(manager).withdrawFromCashDrawer(DAI.address, value.add(1), manager.address)
                ).to.be.reverted
        })
    })

    describe("closeTicket", function () {
        beforeEach(async function() {
            await CryptoPunks.connect(punkHolder).mint();
            await CryptoPunks.connect(punkHolder).approve(PawnShop.address, "2")
            await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount.mul(2))

            await PawnShop.connect(punkHolder).mintPawnTicket("2", CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
        })

        it("returns ERC721 to owner and closes ticket", async function(){
            await PawnShop.connect(punkHolder).closeTicket("1")
            const owner = await CryptoPunks.ownerOf("2")
            expect(owner).to.equal(punkHolder.address)
            const ticket = await PawnShop.ticketInfo("1")
            expect(ticket.closed).to.equal(true)
        });

        it("reverts if caller is not ticket owner", async function(){
            await expect(
                PawnShop.connect(daiHolder).closeTicket("1")
                ).to.be.revertedWith("NFTPawnShop: must be owner of pawned item")
        });

        it("reverts if ticket closed", async function(){
            await PawnShop.connect(punkHolder).closeTicket("1")
            await expect(
                PawnShop.connect(punkHolder).closeTicket("1")
                ).to.be.revertedWith("NFTPawnShop: ticket closed")
        });
    })

    describe("updateOriginationFee", function () {
        it("updates", async function(){
            const originalTake = ethers.BigNumber.from(1).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            var pawnShopTakeRate = await PawnShop.originationFeeRate();
            expect(pawnShopTakeRate).to.equal(originalTake)
            const newTake = ethers.BigNumber.from(5).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await PawnShop.connect(manager).updateOriginationFeeRate(newTake)
            pawnShopTakeRate = await PawnShop.originationFeeRate();
            expect(pawnShopTakeRate).to.equal(newTake)
        })

        it("reverts if take > 5%", async function(){
            const newTake = ethers.BigNumber.from(6).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await expect(
                PawnShop.connect(manager).updateOriginationFeeRate(newTake)
            ).to.be.revertedWith("NFTPawnShop: max fee 5%")
        })

        it("reverts if not called by manager", async function(){
            const newTake = ethers.BigNumber.from(2).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await expect(
                PawnShop.connect(daiHolder).updateOriginationFeeRate(newTake)
            ).to.be.revertedWith("NFTPawnShop: manager only")
        })
    })

    async function interestOwedTotal(ticketID) {
        const ticket = await PawnShop.ticketInfo(ticketID)
        const interest = ticket.perBlockInterestRate
        const startBlock = ticket.lastAccumulatedInterestBlock
        const curBlockNumber = await provider.getBlockNumber()
        return ticket.loanAmount
            .mul(ethers.BigNumber.from(curBlockNumber - startBlock))
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
    