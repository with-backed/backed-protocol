### testing
1. `yarn install`
2. `yarn hardhat test`

### running locally for dev
1. `yarn install`
2. (in seperate terminal) `yarn hardhat node`
3. `mkdir scripts`
4. `touch scripts/deploy.js`
5. Ask wilson for deploy.js code
6. `npx hardhat node` (in a separate terminal tab)
7. `yarn hardhat run scripts/deploy.js --network localhost`
8. Use printed contract values to update `.env.local` (ask Wilson for `.env.local`)
