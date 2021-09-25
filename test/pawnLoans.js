const { expect } = require("chai");

describe("PawnLoans contract", function () {
    beforeEach(async function () {
        [pretendPawnShop, pretendDescriptor, addr1, addr2, ...addrs] = await ethers.getSigners();

        PawnLoansContract = await ethers.getContractFactory("PawnLoans");
        PawnLoans = await PawnLoansContract.deploy(pretendPawnShop.address, pretendDescriptor.address)
        await PawnLoans.deployed();

        await PawnLoans.connect(pretendPawnShop).mint(addr1.address, "1");
    })

    describe("pawnShopTransferLoan", function () {
        it('reverts if caller is not pawn shop', async function(){
            await expect(
                PawnLoans.connect(addr1).pawnShopTransferLoan(addr1.address, addr2.address, "1")
            ).to.be.revertedWith("Only pawn shop")
        })

        it('transfers correctly if caller is pawn shop', async function(){
            await expect(
                PawnLoans.connect(pretendPawnShop).pawnShopTransferLoan(addr1.address, addr2.address, "1")
            ).not.to.be.reverted
            const owner = await PawnLoans.ownerOf("1")
            expect(owner).to.equal(addr2.address)
        })
    })  
})