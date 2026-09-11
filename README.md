# rain.erc4626.words

Rain subparser and extern words for
[ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) tokenised vaults.

## Usage

Provides two words that call conversion functions on any ERC-4626 vault
contract.

```rain
using-words-from <ERC4626Words address>

assets: erc4626-convert-to-assets(vault-address shares);
shares: erc4626-convert-to-shares(vault-address assets);
```

### `erc4626-convert-to-assets`

Converts vault shares to underlying assets.

|             |                                               |
| ----------- | --------------------------------------------- |
| **Input 0** | Vault contract address                        |
| **Input 1** | Share amount as a Float                       |
| **Output**  | Equivalent underlying asset amount as a Float |

```rain
assets: erc4626-convert-to-assets(0xVaultAddress 1e18);
```

### `erc4626-convert-to-shares`

Converts underlying assets to vault shares.

|             |                                          |
| ----------- | ---------------------------------------- |
| **Input 0** | Vault contract address                   |
| **Input 1** | Asset amount as a Float                  |
| **Output**  | Equivalent vault share amount as a Float |

```rain
shares: erc4626-convert-to-shares(0xVaultAddress 1e18);
```

Both words read `decimals()` from the vault share token and `decimals()` from
the underlying asset token to handle correct float conversion for any decimal
combination (e.g. an 18-decimal share token backed by 6-decimal USDC).

## Development

Enter the nix dev shell first — it provides `forge`, `rain`,
`erc4626-words-prelude`, and all other tools:

```sh
nix develop
```

Install Solidity dependencies (soldeer) after cloning or when `soldeer.lock`
changes:

```sh
nix develop github:rainlanguage/rainix#sol-shell -c forge soldeer install
```

### Build

Requires soldeer dependencies to be installed first (see above).

```sh
forge build
```

### Test

Requires soldeer dependencies to be installed first (see above).

```sh
forge test
```

### Regenerate meta and pointer artifacts

Two separate steps must run in order: first regenerate the CBOR-encoded meta,
then regenerate the pointer constants (which read the meta):

```sh
./script/build.sh
nix develop github:rainlanguage/rainix#sol-shell -c forge script script/Build.sol
nix develop github:rainlanguage/rainix#sol-shell -c forge fmt
```

Equivalent via flake prelude + pointer script:

```sh
nix run .#erc4626-words-prelude
nix develop github:rainlanguage/rainix#sol-shell -c forge script script/Build.sol
```

The generated files `src/generated/ERC4626Words.pointers.sol` and
`meta/ERC4626Words.rain.meta` must be committed. The **Git is clean** CI job
calls the reusable `rainix-copy-artifacts` workflow, which re-runs these steps
and fails with `git diff --exit-code` if any committed file has drifted.

### Deploy

```sh
ARBITRUM_RPC_URL=<url> BASE_RPC_URL=<url> BASE_SEPOLIA_RPC_URL=<url> \
  BSC_RPC_URL=<url> ETHEREUM_RPC_URL=<url> FLARE_RPC_URL=<url> \
  HYPEREVM_RPC_URL=<url> POLYGON_RPC_URL=<url> ROBINHOOD_RPC_URL=<url> \
  DEPLOYMENT_KEY=<private-key> \
  forge script script/Deploy.sol --slow --broadcast --verify
```

There is no `--rpc-url`: the script selects each network's fork itself from the
`[rpc_endpoints]` aliases in `foundry.toml`, which read the env vars above.

Or trigger the **Manual sol artifacts** GitHub Actions workflow from the Actions
tab. There is no network selection: the deploy script deterministically deploys
via the Zoltu factory to every rain supported network (arbitrum, base,
base_sepolia, bsc, ethereum, flare, hyperevm, polygon, robinhood), skipping
networks where the deterministic address already has code, and emits the
described-by meta to the MetaBoard.

Robinhood Chain (4663) is not indexed by Etherscan V2, so `--verify` there goes
to its Blockscout and can fail while the deploy itself lands. A failed run is
not a failed deploy: check `DEPLOYED_ADDRESS` on chain before re-dispatching,
and verify after the fact with
`forge verify-contract --verifier sourcify --chain 4663 ...`.

Deploying is a **manual dispatch, decoupled from merging**. Nothing in this
repository asserts that any network has been deployed, and no test reads chain
state for a deployment, so no pull request waits on a deploy. The deploy target
is `DEPLOYED_ADDRESS` in the generated pointers — the Zoltu address of the
source in the checkout being deployed — so redeploying changed bytecode lands at
a new address by construction, with `BYTECODE_HASH` pinning what must be there
when the script finishes.

## CI

| Workflow                 | Trigger         | What it does                                                                          |
| ------------------------ | --------------- | ------------------------------------------------------------------------------------- |
| **rainix-sol**           | push            | Reusable Rainix workflow: test, static analysis, REUSE (`rainix-sol`)                 |
| **Git is clean**         | push            | Reusable `rainix-copy-artifacts`: meta, pointers, format, fails if dirty              |
| **Manual sol artifacts** | manual dispatch | Deterministic Zoltu deploy to script-defined networks (`rainix-manual-sol-artifacts`) |

Secrets for the Manual sol artifacts deploy workflow are consumed by the rainix
reusable and reach it via `secrets: inherit`: `PRIVATE_KEY` (the deployer key),
`RPC_URL_<NETWORK>_FORK` for each deployed network (`ARBITRUM`, `BASE`,
`BASE_SEPOLIA`, `BSC`, `ETHEREUM`, `FLARE`, `HYPEREVM`, `POLYGON`, `ROBINHOOD` —
a repo/org variable of the same name also works, and where neither is set the
reusable's preflight falls back to its own default candidate list; either way it
binds the reachable one to `<NETWORK>_RPC_URL`), `EXPLORER_VERIFICATION_KEY` for
Etherscan-family verification, and `CI_DEPLOY_FLARE_ETHERSCAN_API_KEY` for
Flare, which is not Etherscan. The CI workflows also use `CACHIX_AUTH_TOKEN`
(org-level).
