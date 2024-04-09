## Deployment Instructions

1. 
```
git clone git@github.com:sam-goldman/dca-v2-deployments.git
```

2. 
```
cd dca-v2-deployments
```

3. 
```
yarn install --ignore-scripts && yarn sphinx install && forge install
```

4. Change the `configureSphinx` function.

5. Fill in the `.env`.

6. Propose:
```
sh script/compile.sh && npx sphinx propose script/DCA_v2.s.sol --networks <NETWORK_NAMES>
```