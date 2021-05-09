
const { expect } = require("chai");
const { waffle } = require("hardhat");
const provider = waffle.provider;

describe("PawnShop contract", function () {

    let PawnShop;
    let PawnLoans;
    let CryptoPunks;
    // defaults
    var interest = ethers.BigNumber.from(10).pow(14);
    var blocks = ethers.BigNumber.from(10);
    var loanAmount = ethers.BigNumber.from(500).mul(ethers.BigNumber.from(10).pow(18))

    var punkId = "1"

    beforeEach(async function () {
        [manager, punkHolder, daiHolder, addr4, ...addrs] = await ethers.getSigners();        

        
        PawnShopContract = await ethers.getContractFactory("NFTPawnShop");
        PawnShop = await PawnShopContract.deploy(manager.address);
        await PawnShop.deployed();

        PawnLoansContract = await ethers.getContractFactory("PawnLoans");
        PawnLoans = await PawnLoansContract.deploy(PawnShop.address);
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
        let maxInterest;
        context("when no loan exists", function () {
            beforeEach(async function() {
                maxInterest = await getMaxInterest();
                await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
                await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount)
            })

            it("reverts if amount is too low", async function(){
                await expect(
                    PawnShop.connect(daiHolder).underwritePawnLoan("1", maxInterest, blocks, loanAmount.sub(1))
                    ).to.be.revertedWith("NFTPawnShop: Proposed terms do not qualify")
            })

            it("reverts if interest is too high", async function(){
                await expect(
                    PawnShop.connect(daiHolder).underwritePawnLoan("1", maxInterest.add(1), blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: Proposed terms do not qualify")
            })

            it("reverts if block duration is too low", async function(){
                await expect(
                    PawnShop.connect(daiHolder).underwritePawnLoan("1", maxInterest, blocks.sub(1), loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: Proposed terms do not qualify")
            })
            it("sets values correctly", async function(){
                await expect(
                        PawnShop.connect(daiHolder).underwritePawnLoan("1", maxInterest, blocks, loanAmount)
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
                await PawnShop.connect(daiHolder).underwritePawnLoan("1", maxInterest, blocks, loanAmount)
                const owner = await PawnLoans.ownerOf("1")
                expect(owner).to.equal(daiHolder.address)
            });

        });

        context("when loan exists", function () {
            beforeEach(async function() {
                await DAI.connect(daiHolder).approve(PawnShop.address, loanAmount)

                await PawnShop.connect(punkHolder).mintPawnTicket(punkId, CryptoPunks.address, interest, loanAmount, DAI.address, blocks)
                await PawnShop.connect(daiHolder).underwritePawnLoan("1", maxInterest, blocks, loanAmount)
                maxInterest = await getMaxInterest();

                await DAI.connect(daiHolder).transfer(addr4.address, loanAmount.mul(2))
                await DAI.connect(addr4).approve(PawnShop.address, loanAmount.mul(2))
            })

            it("reverts if amount is too low", async function(){
                await expect(
                    PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: proposed terms must be better than existing terms")
            })

            it("reverts if interest is too high", async function(){
                await expect(
                    PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: proposed terms must be better than existing terms")
            })

            it("reverts if block duration is too low", async function(){
                await expect(
                    PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: proposed terms must be better than existing terms")
            })

            it("does not revert if interest is less", async function(){
                await expect(
                        PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest.sub(1), blocks, loanAmount)
                        ).not.to.be.reverted
            })

            it("does not revert if blocks greater", async function(){
                await expect(
                        PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks.add(1), loanAmount)
                        ).not.to.be.reverted
            })

            it("does not revert if loan amount greater", async function(){
                await expect(
                        PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount.add(1))
                        ).not.to.be.reverted
            })

            it("transfers loan token to the new underwriter", async function(){
                await PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount.add(1))
                const owner = await PawnLoans.ownerOf("1")
                expect(owner).to.equal(addr4.address)
            });

            it("updates payback balance of previous owner", async function(){
                const ticket = await PawnShop.ticketInfo("1")
                const interest = await interestOwed("1")
                await PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount.add(1))
                var loanPaymentBalance = await PawnShop.loanPaymentBalance("1", daiHolder.address)
                expect(loanPaymentBalance).to.equal(loanAmount.add(interest))
            })

            it("sets values correctly", async function(){
                const accumulatedInterest = await interestOwed("1")
                await PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount.add(1))
                const ticket = await PawnShop.ticketInfo("1")
                expect(ticket.loanAmount).to.equal(loanAmount.add(1))
                expect(ticket.perBlockInterestRate).to.equal(interest)
                expect(ticket.blockDuration).to.equal(blocks)
                expect(ticket.accumulatedInterest).to.equal(accumulatedInterest)
                const block = await provider.getBlockNumber()
                expect(ticket.lastAccumulatedInterestBlock).to.equal(block)
            })
        });
        
    });

    describe("drawLoan", function () {
        it("transfers amount to lendee", async function(){
            
        })

        it("does not allow if amount exceeds drawable amount", async function(){
            
        })

        it("does not allow if loan is closed", async function(){

        })

    })

    async function interestOwed(ticketID) {
        const ticket = await PawnShop.ticketInfo(ticketID)
        const interest = await PawnShop.lenderInterestRateAfterPawnShopTake(ticket.perBlockInterestRate)
        const startBlock = ticket.lastAccumulatedInterestBlock
        const curBlockNumber = await provider.getBlockNumber()
        return ticket.loanAmount
            .mul(ethers.BigNumber.from(curBlockNumber - startBlock))
            .mul(interest)
            .div(ethers.BigNumber.from(10).pow(18))
            .add(ticket.accumulatedInterest)
    }

    async function getMaxInterest() {
        return await PawnShop.lenderInterestRateAfterPawnShopTake(interest);
    }
});
    