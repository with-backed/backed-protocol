
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
                const block = await provider.getBlockNumber()
                expect(ticket.lastAccumulatedInterestBlock).to.equal(block)
            })
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
                    ).to.be.revertedWith("NFTPawnShop: loan terms must be better than existing loan")
            })

            it("reverts if interest is too high", async function(){
                await expect(
                    PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: loan terms must be better than existing loan")
            })

            it("reverts if block duration is too low", async function(){
                await expect(
                    PawnShop.connect(addr4).underwritePawnLoan("1", maxInterest, blocks, loanAmount)
                    ).to.be.revertedWith("NFTPawnShop: loan terms must be better than existing loan")
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
        });
        
    });

    async function getMaxInterest() {
        return await PawnShop.lenderInterestRateAfterPawnShopTake(interest);
    }
});
    