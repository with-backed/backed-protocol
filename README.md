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
| BorrowTicketSVGHelper      | 0xc37a73e2cE90eE073e70D95Cd73cD7ac8f8FF1b1       |
| LendTicketSVGHelper   | 0x3bffd69722073889793989eaC1b98cb1b721e294        |
| BorrowTicketDescriptor   | 0xDaC8316F24364FfEEa73A190ee7E332eaA04b8f2        |
| LendTicketDescriptor   | 0x007Ff7Eb7a45bE057192D8b7f660BeA70f3e141c        |
| NFTLoanFacilitator   | 0x0BacCDD05a729aB8B56e09Ef19c15f953E10885f        |
| LendTicket   | 0x4c6822204Ee5E13B4281942Ff231314Bf05f2D3D        |
| BorrowTicket   | 0xe01194534169DC6f38c9Aefea4917C623a99E7Ec        |

## Disclaimer

Last Updated: April 21, 2022

The Backed Protocol is a community-driven, peer-to-peer set of blockchain-based smart contracts and tools that enable users to borrow and lend funds, using NFTs as loan collateral (the “Protocol”) maintained by Non-Fungible Ecosystem Foundation. The Protocol does not guarantee any profitability by borrowing or lending any crypto assets as applicable, nor does the Protocol guarantee any value of any crypto assets transferred thereon. Your use of the Protocol is entirely at your own risk.

The Protocol is available on an “as is” basis without warranties of any kind, either express or implied, including, but not limited to, warranties of merchantability, title, fitness for a particular purpose and non-infringement.

You assume all risks associated with using the Protocol, and digital assets and decentralized systems generally, including but not limited to, that: (a) digital assets are highly volatile; (b) using digital assets is inherently risky due to both features of such assets and the potential unauthorized acts of third parties; (c) you may not have ready access to assets; and (d) you may lose some or all of your tokens or other assets. You agree that you will have no recourse against anyone else for any losses due to the use of the Protocol. For example, these losses may arise from or relate to: (i) incorrect information; (ii) software or network failures; (iii) corrupted cryptocurrency wallet files; (iv) unauthorized access; (v) errors, mistakes, or inaccuracies; or (vi) third-party activities.

The Protocol does not collect any personal data, and your interaction with the Protocol will solely be through your public digital wallet address. Any personal or other data that you may make available in connection with the Protocol may not be private or secure.