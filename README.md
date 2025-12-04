# Clash of Bots Move package (Aptos)

Move modules implementing the Clash of Bots on-chain logic for Aptos. UI and backend remain unchanged; this package contains only on-chain storage, minting, battle, liquidity, and leaderboard logic per the spec.

## Features (POC → MVP)
- Fixed-price mint (10 units of a chosen coin, e.g. USDT) with deterministic base traits (aggression, defense, adaptability, confidence, optional speed) stored on-chain.
- Deterministic battle engine (no randomness in results) with strategy bonus; 5% liquidity transfer from loser to winner.
- Trait evolution: +1 confidence to winner, +1 adaptability to loser; optional post-battle randomness for extra confidence and rare event emission (1–3%).
- Rolling on-chain battle history (last 10 entries) including tx hash.
- Value helper: `liquidity + wins * WIN_BONUS_PER_WIN` (0.1 units of the chosen coin per win).
- Leaderboards: top 5 by wins or liquidity; battle counters per bot.

## Repository layout
- `Move.toml` — package definition; named address `clashofbots`.
- `sources/`
  - `storage.move` — core structs, registry, history buffer, rare event handle, constants.
  - `liquidity.move` — token vault (e.g. USDT) and deterministic redistribution helper.
  - `mint.move` — `entry fun mint_bot` (locks fixed-price payment in the chosen coin, refunds excess, deterministic traits).
  - `battle_engine.move` — `entry fun battle` (deterministic scoring, liquidity move, evolution, history).
  - `randomness.move` — bounded randomness for post-battle evolution only.
  - `leaderboard.move` — top-5 queries by wins/liquidity.
- `scripts/` — local publish helper (`deploy.sh`) kept tracked; folder is gitignored for future local tooling.
- `.gitignore` — ignores build artifacts, `.aptos`, logs, `.DS_Store`, and `scripts/` for cleanliness.

## Prerequisites (what you need)
- Aptos CLI installed: https://aptos.dev/cli-tools/aptos-cli/
- An Aptos profile configured: `aptos init` (or `aptos config set-global`) pointing to your deployer account.
- Funded deployer account (`DEPLOY_ADDR`) on target network (faucet for devnet/testnet; funded for mainnet).

## Deploy (publish modules)
You can use the helper script or run the command directly.
```
DEPLOY_ADDR=0xYOURADDR APTOS_PROFILE=default smart_contracts/scripts/deploy.sh
```
What it does:
- Calls `aptos move publish` with `--named-addresses clashofbots=${DEPLOY_ADDR}` so modules are published under your account.
- Assumes `APTOS_PROFILE` is set to your configured profile.

If running manually:
```
cd smart_contracts
aptos move publish \
  --named-addresses clashofbots=0xYOURADDR \
  --profile default \
  --assume-yes
```

## Initialize on-chain state
After publish (with the deployer signer `@clashofbots`):
1) Create registries and event handles:
```
aptos move run \
  --function-address 0xYOURADDR \
  --profile default \
  --function 0xYOURADDR::storage::init_module
```
2) Create liquidity vault for the coin type you want to use (e.g. USDT). This function is generic; you must pass the coin type:
```
aptos move run \
  --function-address 0xYOURADDR \
  --profile default \
  --function 0xYOURADDR::liquidity::init_module<0xUSDTADDR::usdt::USDT>
```

## Entry functions for users
- Mint (generic over coin type; intended for USDT):\
  `0xYOURADDR::mint::mint_bot<0xUSDTADDR::usdt::USDT>(payment: Coin<0xUSDTADDR::usdt::USDT>)` — requires `MINT_PRICE` units of USDT; derives traits deterministically.
- Battle: `0xYOURADDR::battle_engine::battle(attacker_bot_id, defender_bot_id)` — called by attacker owner.

Key constants (in `storage`):
- `MINT_PRICE = 1_000_000_000` (example value; interpreted as 10 units of the chosen coin in its base units, adjust based on the coin’s decimals)
- `LIQUIDITY_TRANSFER_PERCENT = 5`
- `WIN_BONUS_PER_WIN = 10_000_000` (0.1 unit of the chosen coin)
- History depth: 10 records

## Deterministic battle math
- Attack Power = `aggression * 2 + confidence`
- Defense Power = `defense * 2 + adaptability`
- Strategy bonus: `> => +3`, `== => +1`, else `+0`
- Score = attack − defense + strategy; higher score wins (id tie-breaker on equal score).
- Liquidity: loser → winner `5%`.
- Evolution: winner `confidence += 1`, loser `adaptability += 1`, plus optional random `confidence += 2` (20% roll). Rare event emitted if roll < 3.

## Queries
- `storage::battle_history()` — latest 10 battles (attacker, defender, winner, tx hash).
- `leaderboard::top_by_wins()` / `leaderboard::top_by_liquidity()` — top 5 bot ids.
- `storage::bots_for_owner(address)` — ids owned by address.
- `storage::bot_value(bot)` — value helper expressed in units of the chosen coin (e.g. USDT).

## Testing locally
```
cd smart_contracts
aptos move test
```

## Notes for Aptos reviewers
- No UI/backend changes included; this package is self-contained Move code per the provided spec.
- Randomness is bounded and does not affect battle outcomes—only post-battle evolution and rare event emission.
