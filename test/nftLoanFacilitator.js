
const { expect } = require("chai");
const { waffle } = require("hardhat");
const { singletons } = require('@openzeppelin/test-helpers');
const provider = waffle.provider;

describe("NFTLoanFacilitator contract", function () {

    let NFTLoanFacilitator;
    let LendTicket;
    let TestERC721;
    // defaults
    var interestRateDecimals
    var originationFeeRate
    var scalar
    var interest = ethers.BigNumber.from(10);
    var durationSeconds = ethers.BigNumber.from(10);
    var loanAmount = ethers.BigNumber.from(505).mul(ethers.BigNumber.from(10).pow(17))

    var erc721Id = ethers.BigNumber.from(1000);
    let BorrowTicketDescriptor;

    beforeEach(async function () {
        [manager, erc721Holder, erc20Holder, addr4, addr5, ...addrs] = await ethers.getSigners();   
        
        await singletons.ERC1820Registry(addr4.address);

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
        
        NFTLoanFacilitatorContract = await ethers.getContractFactory("NFTLoanFacilitator");
        NFTLoanFacilitator = await NFTLoanFacilitatorContract.deploy(manager.address);
        await NFTLoanFacilitator.deployed();

        interestRateDecimals = await NFTLoanFacilitator.INTEREST_RATE_DECIMALS();
        originationFeeRate = ethers.BigNumber.from(10).pow(interestRateDecimals - 2);
        scalar = ethers.BigNumber.from(10).pow(interestRateDecimals);

        LendTicketContract = await ethers.getContractFactory("LendTicket");
        LendTicket = await LendTicketContract.deploy(NFTLoanFacilitator.address, LendTicketDescriptor.address);
        await LendTicket.deployed();

        BorrowTicketContract = await ethers.getContractFactory("BorrowTicket");
        BorrowTicket = await BorrowTicketContract.deploy(NFTLoanFacilitator.address, BorrowTicketDescriptor.address);
        await BorrowTicket.deployed();

        await NFTLoanFacilitator.connect(manager).setLendTicketContract(LendTicket.address)
        await NFTLoanFacilitator.connect(manager).setBorrowTicketContract(BorrowTicket.address)

        TestERC721Contract = await ethers.getContractFactory("TestERC721");
        TestERC721 = await TestERC721Contract.deploy();
        await TestERC721.deployed();

        await TestERC721.connect(erc721Holder).mint();
        await TestERC721.connect(erc721Holder).approve(NFTLoanFacilitator.address, erc721Id)


        ERC20Contract = await ethers.getContractFactory("TestERC20");
        ERC20 = await ERC20Contract.deploy();
        await ERC20.deployed();  
        ERC20.mint(erc20Holder.address, ethers.BigNumber.from(10).pow(30));
      });
      
    describe("tokenURI", function() {
        it("retrieves successfully", async function(){
            await NFTLoanFacilitator.connect(erc721Holder).createLoan(
                erc721Id, 
                TestERC721.address, 
                interest,
                true,
                loanAmount, 
                ERC20.address, 
                durationSeconds, 
                erc721Holder.address
            )
            await expect(
                BorrowTicket.tokenURI("1")
            ).not.to.be.reverted
            const u = await BorrowTicket.tokenURI("1")
            // console.log(u)
        })
    })


    describe("createLoan", function () {
        it("sets values correctly", async function(){
            await NFTLoanFacilitator.connect(erc721Holder).createLoan(
                erc721Id,
                TestERC721.address,
                interest,
                true,
                loanAmount,
                ERC20.address,
                durationSeconds,
                addr4.address
            )
            const ticket = await NFTLoanFacilitator.loanInfo("1")
            expect(ticket.loanAssetContractAddress).to.equal(ERC20.address)
            expect(ticket.loanAmount).to.equal(loanAmount)
            expect(ticket.collateralTokenId).to.equal(erc721Id)
            expect(ticket.collateralContractAddress).to.equal(TestERC721.address)
            expect(ticket.perAnnumInterestRate).to.equal(interest)
            expect(ticket.durationSeconds).to.equal(durationSeconds)
            expect(ticket.accumulatedInterest).to.equal(0)
        })

        it("transfers NFT to contract, mints ticket", async function(){
            await NFTLoanFacilitator.connect(erc721Holder).createLoan(
                erc721Id,
                TestERC721.address,
                interest,
                true,
                loanAmount, 
                ERC20.address,
                durationSeconds,
                addr4.address
            )
            const erc721Owner = await  TestERC721.ownerOf(erc721Id)
            const ticketOwner = await BorrowTicket.ownerOf("1")
            expect(erc721Owner).to.equal(NFTLoanFacilitator.address)
            expect(ticketOwner).to.equal(addr4.address)
        })

        it('reverts if not approved', async function(){
            await TestERC721.connect(erc721Holder).mint();
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).createLoan(
                    erc721Id.add(1), 
                    TestERC721.address, 
                    interest, 
                    true,
                    loanAmount, 
                    ERC20.address,
                    durationSeconds, 
                    addr4.address
                )
            ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved")
        })

        it('reverts if collateral is loan ticket or borrow ticket', async function(){
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).createLoan(
                    erc721Id, 
                    LendTicket.address, 
                    interest,
                    true, 
                    loanAmount,
                    ERC20.address,
                    durationSeconds,
                    addr4.address
                )
            ).to.be.revertedWith('lend ticket collateral')
            
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).createLoan(
                    erc721Id,
                    BorrowTicket.address,
                    interest,
                    true,
                    loanAmount,
                    ERC20.address,
                    durationSeconds,
                    addr4.address
                )
            ).to.be.revertedWith('borrow ticket collateral')
        })

        it('reverts if duration is 0', async function(){
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).createLoan(
                    erc721Id,
                    TestERC721.address,
                    interest,
                    true,
                    loanAmount,
                    ERC20.address,
                    0,
                    addr4.address
                )
            ).to.be.revertedWith('0 duration')
        })

        it('reverts if loan amount is 0', async function(){
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).createLoan(
                    erc721Id,
                    TestERC721.address,
                    interest,
                    true,
                    0,
                    ERC20.address,
                    durationSeconds,
                    addr4.address
                )
            ).to.be.revertedWith('0 loan amount')
        })

        it('does not reverts if interest rate is 0', async function(){
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).createLoan(
                    erc721Id,
                    TestERC721.address,
                    0,
                    true,
                    loanAmount,
                    ERC20.address,
                    durationSeconds,
                    addr4.address
                )
            ).not.to.be.reverted
        })
    });

    describe("closeLoan", function () {
        beforeEach(async function() {
            await TestERC721.connect(erc721Holder).mint();
            await TestERC721.connect(erc721Holder).approve(NFTLoanFacilitator.address, erc721Id.add(1))
            await ERC20.connect(erc20Holder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))

            await NFTLoanFacilitator.connect(erc721Holder).createLoan(erc721Id.add(1), TestERC721.address, interest, true, loanAmount, ERC20.address, durationSeconds, erc721Holder.address)
        })

        it("transfers ERC721 and closes ticket", async function(){
            await NFTLoanFacilitator.connect(erc721Holder).closeLoan("1", addr4.address)
            const owner = await TestERC721.ownerOf(erc721Id.add(1))
            expect(owner).to.equal(addr4.address)
            const ticket = await NFTLoanFacilitator.loanInfo("1")
            expect(ticket.closed).to.equal(true)
        });

        it("reverts if loan does not exist", async function(){
            await expect(
                NFTLoanFacilitator.connect(erc20Holder).closeLoan("2", addr4.address)
                ).to.be.revertedWith("NOT_MINTED")
        });

        it("reverts if caller is not ticket owner", async function(){
            await expect(
                NFTLoanFacilitator.connect(erc20Holder).closeLoan("1", addr4.address)
                ).to.be.revertedWith("borrow ticket holder only")
        });

        it("reverts if loan closed", async function(){
            await NFTLoanFacilitator.connect(erc721Holder).closeLoan("1", addr4.address)
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).closeLoan("1", addr4.address)
            ).to.be.revertedWith("loan closed")
        });

        it("reverts if ticket has lender", async function(){
            await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).closeLoan("1", addr4.address)
            ).to.be.revertedWith("has lender")
        });
    })

    describe("lend", function () {
        context("when loan does not have lender", function () {
            beforeEach(async function() {
                await NFTLoanFacilitator.connect(erc721Holder).createLoan(erc721Id, TestERC721.address, interest, true, loanAmount, ERC20.address, durationSeconds, erc721Holder.address)
                await ERC20.connect(erc20Holder).approve(NFTLoanFacilitator.address, loanAmount)
            })

            it("reverts if loan does not exist", async function(){
                await expect(
                    NFTLoanFacilitator.connect(erc20Holder).lend("2", 0, 0, 0, erc20Holder.address)
                    ).to.be.revertedWith("invalid loan")
            })

            it("reverts if amount is too low", async function(){
                await expect(
                    NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount.sub(1), durationSeconds, erc20Holder.address)
                    ).to.be.revertedWith("amount too low")
            })

            it("reverts if interest is too high", async function(){
                await expect(
                    NFTLoanFacilitator.connect(erc20Holder).lend("1", interest.add(1), loanAmount, durationSeconds, erc20Holder.address)
                    ).to.be.revertedWith("rate too high")
            })

            it("reverts if block duration is too low", async function(){
                await expect(
                    NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds.sub(1), erc20Holder.address)
                    ).to.be.revertedWith("duration too low")
            })

            it("sets values correctly", async function(){
                await expect(
                        NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)
                        ).not.to.be.reverted
                const ticket = await NFTLoanFacilitator.loanInfo("1")
                expect(ticket.loanAmount).to.equal(loanAmount)
                expect(ticket.perAnnumInterestRate).to.equal(interest)
                expect(ticket.durationSeconds).to.equal(durationSeconds)
                expect(ticket.accumulatedInterest).to.equal(0)
                const block = await provider.getBlock()
                expect(ticket.lastAccumulatedTimestamp).to.equal(block.timestamp)
            })
            it("transfers loan NFT to lender", async function(){
                await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, addr5.address)
                const owner = await LendTicket.ownerOf("1")
                expect(owner).to.equal(addr5.address)
            });

            it("leaves origination fee in contract", async function(){
                var value = await ERC20.balanceOf(NFTLoanFacilitator.address)
                expect(value).to.equal(0)
                await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)
                value = await ERC20.balanceOf(NFTLoanFacilitator.address)
                expect(value).to.equal(loanAmount.mul(originationFeeRate).div(scalar))
            })

            it("transfers loan asset borrower", async function(){
                var value = await ERC20.balanceOf(erc721Holder.address)
                expect(value).to.equal(0)
                await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)
                value = await ERC20.balanceOf(erc721Holder.address)
                expect(value).to.equal(loanAmount.sub(loanAmount.mul(originationFeeRate).div(scalar)))
            })

        });

        context("malicious ERC20", function () {
            beforeEach(async function () {
                // deploy malicious erc20
                MaliciousERC20Contract = await ethers.getContractFactory("CloseLoanERC20");
                MAL = await MaliciousERC20Contract.connect(erc20Holder).deploy(NFTLoanFacilitator.address);
                await MAL.deployed();
                await MAL.mint(erc20Holder.address, loanAmount);
        
                // make sure we mint borrow ticket to the erc20 contract address
                await NFTLoanFacilitator.connect(erc721Holder).createLoan(erc721Id, TestERC721.address, interest, true, loanAmount, MAL.address, durationSeconds, MAL.address)
                await MAL.connect(erc20Holder).approve(NFTLoanFacilitator.address, loanAmount)
            })
        
            it("does not complete lend function if loan asset is malicious", async function () {
                var value = await MAL.balanceOf(erc721Holder.address)
                expect(value).to.equal(0)
        
                await expect(
                    NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)
                ).to.be.revertedWith("has lender")
        
                value = await MAL.balanceOf(erc721Holder.address)
                expect(value).to.equal(0)
            })
        })

        context("when loan has lender", function () {
            beforeEach(async function() {
                await ERC20.connect(erc20Holder).approve(NFTLoanFacilitator.address, loanAmount)

                await NFTLoanFacilitator.connect(erc721Holder).createLoan(erc721Id, TestERC721.address, interest, true, loanAmount, ERC20.address, durationSeconds, erc721Holder.address)
                await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)

                await ERC20.connect(erc20Holder).transfer(addr4.address, loanAmount.mul(2))
                await ERC20.connect(addr4).approve(NFTLoanFacilitator.address, loanAmount.mul(2))
            })

            it("reverts if terms are not improved", async function(){
                await expect(
                    NFTLoanFacilitator.connect(addr4).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)
                ).to.be.revertedWith("insufficient improvement")
            })

            it("reverts interest is already 0", async function(){
                await NFTLoanFacilitator.connect(addr4).lend("1", 0, loanAmount, durationSeconds, erc20Holder.address)
                await expect(
                    NFTLoanFacilitator.connect(addr4).lend("1", 0, loanAmount, durationSeconds, erc20Holder.address)
                ).to.be.revertedWith("insufficient improvement")
            })

            it("reverts if one value does not meet or beat exisiting, even if others are improved", async function(){
                await expect(
                        NFTLoanFacilitator.connect(addr4).lend("1", interest.mul(90).div(100), loanAmount.sub(1), durationSeconds, addr4.address)
                        ).to.be.reverted
            })

            it("does not revert if interest is less", async function(){
                await expect(
                        NFTLoanFacilitator.connect(addr4).lend("1", interest.mul(90).div(100), loanAmount, durationSeconds, addr4.address)
                        ).not.to.be.reverted
            })

            it("does not revert if durationSeconds greater", async function(){
                await expect(
                        NFTLoanFacilitator.connect(addr4).lend("1", interest, loanAmount, durationSeconds.add(durationSeconds.mul(10).div(100)), addr4.address)
                        ).not.to.be.reverted
            })

            it("does not revert if loan amount greater", async function(){
                await expect(
                        NFTLoanFacilitator.connect(addr4).lend("1", interest, loanAmount.add(loanAmount.mul(10).div(100)), durationSeconds, addr4.address)
                        ).not.to.be.reverted
            })

            it("transfers loan token to the new lender", async function(){
                await NFTLoanFacilitator.connect(addr4).lend("1", interest, loanAmount.add(loanAmount.mul(10).div(100)), durationSeconds, manager.address)
                const owner = await LendTicket.ownerOf("1")
                expect(owner).to.equal(manager.address)
            });

            it("pays back previous owner", async function(){
                const beforeValue = await ERC20.balanceOf(erc20Holder.address)
                await NFTLoanFacilitator.connect(addr4).lend("1", interest, loanAmount.add(loanAmount.mul(10).div(100)), durationSeconds, addr4.address)
                const interestOwed = await interestOwedTotal("1")
                const afterValue = await ERC20.balanceOf(erc20Holder.address)
                expect(afterValue).to.equal(beforeValue.add(loanAmount).add(interestOwed))
            })

            it("sets values correctly", async function(){
                const newLoanAmount = loanAmount.add(loanAmount.mul(10).div(100))
                await NFTLoanFacilitator.connect(addr4).lend("1", interest, newLoanAmount, durationSeconds, addr4.address)
                const accumulatedInterest = await interestOwedTotal("1")
                const ticket = await NFTLoanFacilitator.loanInfo("1")
                expect(ticket.loanAmount).to.equal(newLoanAmount)
                expect(ticket.perAnnumInterestRate).to.equal(interest)
                expect(ticket.durationSeconds).to.equal(durationSeconds)
                expect(ticket.accumulatedInterest).to.equal(accumulatedInterest)
                const block = await provider.getBlock()
                expect(ticket.lastAccumulatedTimestamp).to.equal(block.timestamp)
            })

            it("takes origination fee correctly", async function(){
                const increase = loanAmount.mul(10).div(100)
                const newLoanAmount = loanAmount.add(increase)
                await NFTLoanFacilitator.connect(addr4).lend("1", interest, newLoanAmount, durationSeconds, addr4.address)
                value = await ERC20.balanceOf(NFTLoanFacilitator.address)
                expect(value).to.equal(loanAmount.mul(originationFeeRate).div(scalar).add(increase.mul(originationFeeRate).div(scalar)))
            })

            context("when loan amount is the same", function () {
                it('does not increase cash drawer balance', async function(){
                    var valueBefore = await ERC20.balanceOf(NFTLoanFacilitator.address)
                    await NFTLoanFacilitator.connect(addr4).lend("1", interest, loanAmount, durationSeconds.add(durationSeconds.mul(10).div(100)), addr4.address)
                    var valueAfter = await ERC20.balanceOf(NFTLoanFacilitator.address)
                    expect(valueBefore).to.equal(valueAfter)
                })

                it("sets values correctly", async function(){
                    const newDuration = durationSeconds.add(durationSeconds.mul(10).div(100))
                    await NFTLoanFacilitator.connect(addr4).lend("1", interest, loanAmount, newDuration, addr4.address)
                    const accumulatedInterest = await interestOwedTotal("1")
                    const ticket = await NFTLoanFacilitator.loanInfo("1")
                    expect(ticket.loanAmount).to.equal(loanAmount)
                    expect(ticket.perAnnumInterestRate).to.equal(interest)
                    expect(ticket.durationSeconds).to.equal(newDuration)
                    expect(ticket.accumulatedInterest).to.equal(accumulatedInterest)
                    const block = await provider.getBlock()
                    expect(ticket.lastAccumulatedTimestamp).to.equal(block.timestamp)
                })

                it("pays back previous owner", async function(){
                    const beforeValue = await ERC20.balanceOf(erc20Holder.address)
                    await NFTLoanFacilitator.connect(addr4).lend("1", interest, loanAmount, durationSeconds.add(durationSeconds.mul(10).div(100)), addr4.address)
                    const interestOwed = await interestOwedTotal("1")
                    const afterValue = await ERC20.balanceOf(erc20Holder.address)
                    expect(afterValue).to.equal(beforeValue.add(loanAmount).add(interestOwed))
                })
            })

            context('when bought out again', function() {
                it('transfers payout correctly', async function(){
                    const buyout1LoanAmount = loanAmount.add(loanAmount.mul(10).div(100))
                    const buyout2LoanAmount = buyout1LoanAmount.add(buyout1LoanAmount.mul(10).div(100))
                    
                    await ERC20.connect(erc20Holder).approve(NFTLoanFacilitator.address, buyout2LoanAmount.mul(2))
                    
                    await NFTLoanFacilitator.connect(addr4).lend("1", interest, buyout1LoanAmount, durationSeconds, addr4.address)
                    const addr4BeforeBalance = await ERC20.balanceOf(addr4.address)
                    await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, buyout2LoanAmount, durationSeconds, erc20Holder.address)
                    const interestOwed = await interestOwedTotal("1")
                    const addr4AfterBalance = await ERC20.balanceOf(addr4.address)
                    expect(addr4AfterBalance).to.equal(addr4BeforeBalance.add(buyout1LoanAmount).add(interestOwed))
                })
            })
        });
        
    });

    describe("repayAndCloseLoan", function () {
        beforeEach(async function() {
            await ERC20.connect(erc20Holder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))

            await NFTLoanFacilitator.connect(erc721Holder).createLoan(erc721Id, TestERC721.address, interest, true, loanAmount, ERC20.address, durationSeconds, erc721Holder.address)
            await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)
            await ERC20.connect(erc20Holder).transfer(erc721Holder.address, loanAmount.mul(2))
            await ERC20.connect(erc721Holder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))
        })

        it("pays back lender", async function(){
            const balanceBefore = await ERC20.balanceOf(erc20Holder.address)
            await NFTLoanFacilitator.connect(erc721Holder).repayAndCloseLoan("1")
            const interest = await interestOwedTotal("1")
            const balanceAfter = await ERC20.balanceOf(erc20Holder.address)
            expect(balanceAfter).to.equal(balanceBefore.add(loanAmount.add(interest)))
        })

        it("transfers collateral back to lendee", async function(){
            await NFTLoanFacilitator.connect(erc721Holder).repayAndCloseLoan("1")
            const erc721Owner = await  TestERC721.ownerOf(erc721Id)
            expect(erc721Owner).to.equal(erc721Holder.address)
        })

        it("closes ticket", async function(){
            await NFTLoanFacilitator.connect(erc721Holder).repayAndCloseLoan("1")
            const ticket = await NFTLoanFacilitator.loanInfo("1")
            expect(ticket.closed).to.equal(true)
        })

        it("reverts if ticket is closed", async function(){
            await NFTLoanFacilitator.connect(erc721Holder).repayAndCloseLoan("1")
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).repayAndCloseLoan("1")
            ).to.be.revertedWith("loan closed")
        })

        it("reverts if loan does not exist", async function(){
            await expect(
                NFTLoanFacilitator.connect(erc721Holder).repayAndCloseLoan("10")
            ).to.be.revertedWith("NOT_MINTED")
        })
    })

    describe("seizeCollateral", function () {
        beforeEach(async function() {
            await TestERC721.connect(erc721Holder).mint();
            await TestERC721.connect(erc721Holder).approve(NFTLoanFacilitator.address, erc721Id.add(1))
            await ERC20.connect(erc20Holder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))

            await NFTLoanFacilitator.connect(erc721Holder).createLoan(erc721Id.add(1), TestERC721.address, interest, true, loanAmount, ERC20.address, 1, erc721Holder.address)
            await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, 1, erc20Holder.address)
        })

        it("transfers collateral to given address, closed", async function(){
            // mine on block
            await ERC20.connect(erc20Holder).transfer(addr4.address, ethers.BigNumber.from(1))
            // 
            await NFTLoanFacilitator.connect(erc20Holder).seizeCollateral("1", addr4.address)
            const ticket = await NFTLoanFacilitator.loanInfo("1")
            expect(ticket.closed).to.equal(true)
            const erc721Owner = await TestERC721.ownerOf(erc721Id.add(1))
            expect(erc721Owner).to.equal(addr4.address)
        })

        it('reverts if non-loan-owner calls', async function(){
            // mine on block
            await ERC20.connect(erc20Holder).transfer(addr4.address, ethers.BigNumber.from(1))
            // 
            await expect(
                NFTLoanFacilitator.connect(addr4).seizeCollateral("1", addr4.address)
            ).to.be.revertedWith("lend ticket holder only")
        })

        it("reverts if ticket is closed", async function(){
            await ERC20.connect(erc20Holder).approve(NFTLoanFacilitator.address, loanAmount.mul(1))
            // repay and close
            await ERC20.connect(erc20Holder).transfer(erc721Holder.address, loanAmount.mul(2))
            await ERC20.connect(erc721Holder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))
            await NFTLoanFacilitator.connect(erc721Holder).repayAndCloseLoan("1")
            // 
            await expect(
                NFTLoanFacilitator.connect(erc20Holder).seizeCollateral("1", addr4.address)
            ).to.be.revertedWith("loan closed")
        })

        it("reverts if payment is not late", async function(){
            await expect(
                NFTLoanFacilitator.connect(erc20Holder).seizeCollateral("1", addr4.address)
            ).to.be.revertedWith("payment is not late")
        })

        it("reverts loan does not exist", async function(){
            await expect(
                NFTLoanFacilitator.connect(erc20Holder).seizeCollateral("2", addr4.address)
            ).to.be.revertedWith("NOT_MINTED")
        })
    })

    describe("withdrawOriginationFees", function () {
        beforeEach(async function() {
            await ERC20.connect(erc20Holder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))

            await NFTLoanFacilitator.connect(erc721Holder).createLoan(erc721Id, TestERC721.address, interest, true, loanAmount, ERC20.address, durationSeconds, erc721Holder.address)
            await NFTLoanFacilitator.connect(erc20Holder).lend("1", interest, loanAmount, durationSeconds, erc20Holder.address)
            await ERC20.connect(erc20Holder).transfer(erc721Holder.address, loanAmount.mul(2))
            await ERC20.connect(erc721Holder).approve(NFTLoanFacilitator.address, loanAmount.mul(2))
            await NFTLoanFacilitator.connect(erc721Holder).repayAndCloseLoan("1")
        })

        it("transfers ERC20 value, reduces loan payment balance", async function(){
            await expect(
                NFTLoanFacilitator.connect(erc20Holder).withdrawOriginationFees(ERC20.address, loanAmount, manager.address)
                ).to.be.reverted
        });

        it("transfers ERC20 value, reduces loan payment balance", async function(){
            const balanceBefore = await ERC20.balanceOf(manager.address)
            const value = await ERC20.balanceOf(NFTLoanFacilitator.address)
            expect(value).to.be.above(0)
            await expect(
                NFTLoanFacilitator.connect(manager).withdrawOriginationFees(ERC20.address, value, manager.address)
                ).not.to.be.reverted
            const balanceAfter = await ERC20.balanceOf(manager.address)
            expect(balanceAfter).to.equal(balanceBefore.add(value))

        })
        
        it("reverts if amount is greater than what is available", async function(){
            const balanceBefore = await ERC20.balanceOf(manager.address)
            const value = await ERC20.balanceOf(NFTLoanFacilitator.address)
            await expect(
                NFTLoanFacilitator.connect(manager).withdrawOriginationFees(ERC20.address, value.add(1), manager.address)
                ).to.be.reverted
        })
    })

    describe("updateOriginationFee", function () {
        it("updates", async function(){
            const originalTake = ethers.BigNumber.from(1).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            var NFTLoanFacilitatorTakeRate = await NFTLoanFacilitator.originationFeeRate();
            expect(NFTLoanFacilitatorTakeRate).to.equal(originalTake)
            const newTake = ethers.BigNumber.from(5).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await NFTLoanFacilitator.connect(manager).updateOriginationFeeRate(newTake)
            await expect(
                NFTLoanFacilitator.connect(manager).updateOriginationFeeRate(newTake)
            ).to.emit(NFTLoanFacilitator, "UpdateOriginationFeeRate")
            NFTLoanFacilitatorTakeRate = await NFTLoanFacilitator.originationFeeRate();
            expect(NFTLoanFacilitatorTakeRate).to.equal(newTake)
        })

        it("reverts if take > 5%", async function(){
            const newTake = ethers.BigNumber.from(6).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await expect(
                NFTLoanFacilitator.connect(manager).updateOriginationFeeRate(newTake)
            ).to.be.revertedWith("max fee 5%")
        })

        it("reverts if not called by manager", async function(){
            const newTake = ethers.BigNumber.from(2).mul(ethers.BigNumber.from(10).pow(interestRateDecimals - 2))
            await expect(
                NFTLoanFacilitator.connect(erc20Holder).updateOriginationFeeRate(newTake)
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    describe("updateRequiredImprovementRate", function () {
        it("updates", async function(){ 
            const newPercentage = ethers.BigNumber.from(5);
            await expect(
                NFTLoanFacilitator.connect(manager).updateRequiredImprovementRate(newPercentage)
            ).to.emit(NFTLoanFacilitator, "UpdateRequiredImprovementRate")
            const percentage = await NFTLoanFacilitator.requiredImprovementRate();
            expect(percentage).to.eq(newPercentage)
        })

        it("reverts if not called by manager", async function(){
            await expect(
                NFTLoanFacilitator.connect(erc20Holder).updateRequiredImprovementRate(5)
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })
    })

    async function interestOwedTotal(ticketID) {
        const ticket = await NFTLoanFacilitator.loanInfo(ticketID)
        const interest = ticket.perAnnumInterestRate
        const startTimestamp = ticket.lastAccumulatedTimestamp
        const height = await provider.getBlockNumber()
        const curBlock = await provider.getBlock(height)
        const curTimestamp = curBlock.timestamp
        const secondsInYear = 60*60*24*365;
        return ticket.loanAmount
            .mul(ethers.BigNumber.from(curTimestamp - startTimestamp))
            .mul(Math.floor(interest * 1e18 / secondsInYear))
            .div(ethers.BigNumber.from(10).pow(18))
            .div(scalar)
            .add(ticket.accumulatedInterest)
    }
});
    