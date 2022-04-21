Find our Code4Rena audit results [here](https://code4rena.com/reports/2022-04-backed/).

## Summary

Backed protocol enables peer-to-peer loans with NFT collateral. Its main unique features are
1. No back and forth negotations: Borrowers propose minimum viable terms (loan asset, minimum loan amount, minimum duration, max interest rate) and the loan starts immediately once a lender meets or beats the minimum terms. 
2. No oracles: borrowers and lenders agree to loan terms and that's all that matters. The only "liquidation" type event is that lenders can seize the NFT collateral if the loan is past due.
3. Composability: borrowers get Borrow Tickets and lenders get Lend Tickets. Control flows query for the current owner of these ticket, rather than a static borrower/lender address. For example, when a loan is repaid, the funds go to the Lend Ticket holder, whoever that happens to be at the moment of that transaction. 
4. Perpetual lender buyout: a lender can be boughtout at any time by a new lender who meets the existing terms and beats at least one term by at least 10%, e.g. 10% longer duration, 10% higher loan amount, 10% lower interest. The new lender pays the previous lender their principal + any interest owed. The loan duration restarts on buyout.

There is in depth, though slightly outdated, developer documentation of the protocol [here](https://github.com/code-423n4/2022-04-backed/blob/main/README.md).

#### Simple flow diagrams
A loan that was closed with no lender

<img width="412" alt="Screen Shot 2022-04-01 at 4 27 33 PM" src="https://user-images.githubusercontent.com/6678357/161338069-8c4f6410-7e42-4e92-a5f7-44406357ba81.png">


A repaid loan

<img width="616" alt="image" src="https://user-images.githubusercontent.com/6678357/161338082-2a150926-1843-47b8-a8e8-fcf678d5b61b.png">

A loan with seized collateral

<img width="622" alt="image" src="https://user-images.githubusercontent.com/6678357/161338113-a3bbfc85-0f82-4d22-9221-c6073eacfadc.png">

## Running the code
First install dependencies
```
$ yarn install
```

The repository has both Hardhat and Forge tests, run them with the following commands 
```
$ yarn hardhat test
$ forge test
```

## Addresses
The contracts are deployed on Ethereum networks Rinkeby and Mainnet. 
| Contract      | Address |
| ----------- | ----------- |
| BorrowTicketSVGHelper      | 0x31dc0b33F01F314A10B77C722dA34eA046b4daA2       |
| LendTicketSVGHelper   | 0x3F4D6CA3518D81C7152FC7A47B006d4343896E44        |
| BorrowTicketDescriptor   | 0xEe457DB5113Dc6fb0447C53Ab68131F7b494bf48        |
| LendTicketDescriptor   | 0x0982FED63643Cd69F2AF3eA824b462829FBD9703        |
| NFTLoanFacilitator   | 0x0bACCDD01FF681b07334362387559Ba140bD7b2A        |
| LendTicket   | 0xE8a91e8C8A8ff8Cab9BbBC5527891b9BD89a5F8e        |
| BorrowTicket   | 0xeF87894f0B37f8f1De2f23DB27d9aa43aCd50f51        |

## Disclaimer

Last Updated: April 21, 2022

The Backed Protocol is a community-driven, peer-to-peer set of blockchain-based smart contracts and tools that enable users to borrow and lend funds, using NFTs as loan collateral (the “Protocol”) maintained by Non-Fungible Ecosystem Foundation. The Protocol does not guarantee any profitability by borrowing or lending any crypto assets as applicable, nor does the Protocol guarantee any value of any crypto assets transferred thereon. Your use of the Protocol is entirely at your own risk.

The Protocol is available on an “as is” basis without warranties of any kind, either express or implied, including, but not limited to, warranties of merchantability, title, fitness for a particular purpose and non-infringement.

You assume all risks associated with using the Protocol, and digital assets and decentralized systems generally, including but not limited to, that: (a) digital assets are highly volatile; (b) using digital assets is inherently risky due to both features of such assets and the potential unauthorized acts of third parties; (c) you may not have ready access to assets; and (d) you may lose some or all of your tokens or other assets. You agree that you will have no recourse against anyone else for any losses due to the use of the Protocol. For example, these losses may arise from or relate to: (i) incorrect information; (ii) software or network failures; (iii) corrupted cryptocurrency wallet files; (iv) unauthorized access; (v) errors, mistakes, or inaccuracies; or (vi) third-party activities.

The Protocol does not collect any personal data, and your interaction with the Protocol will solely be through your public digital wallet address. Any personal or other data that you may make available in connection with the Protocol may not be private or secure.