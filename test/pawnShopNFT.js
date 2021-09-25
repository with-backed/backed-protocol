const { expect } = require("chai");

describe("PawnShopNFT contract", function () {
    let name = 'Pawn Shop'
    let symbol = 'PWNS'

    beforeEach(async function () {
        [pretendPawnShop, pretendDescriptor, addr1, ...addrs] = await ethers.getSigners();

        PawnShopNFTContract = await ethers.getContractFactory("PawnShopNFT");
        PawnShopNFT = await PawnShopNFTContract.deploy(name, symbol, pretendPawnShop.address, pretendDescriptor.address)
        await PawnShopNFT.deployed();
    })

    describe("contructor", function () {
        it("sets name correctly", async function(){
            const n = await PawnShopNFT.name();
            expect(n).to.equal(name)
        })

        it("sets symbol correctly", async function(){
            const s = await PawnShopNFT.symbol();
            expect(s).to.equal(symbol)
        })

        it("sets pawnShop correctly", async function(){
            const p = await PawnShopNFT.pawnShop();
            expect(p).to.equal(pretendPawnShop.address)
        })

        it("sets descriptor correctly", async function(){
            const d = await PawnShopNFT.descriptor();
            expect(d).to.equal(pretendDescriptor.address)
        })
    })

    describe("mint", function () {
        it('reverts if caller is not pawn shop', async function(){
            await expect(
                PawnShopNFT.connect(addr1).mint(addr1.address, "1")
            ).to.be.revertedWith("Only pawn shop")
        })

        it('mints if caller is pawn shop', async function(){
            await expect(
                PawnShopNFT.connect(pretendPawnShop).mint(addr1.address, "1")
            ).not.to.be.reverted
            const owner = await PawnShopNFT.ownerOf("1")
            expect(owner).to.equal(addr1.address)
        })
    })
})