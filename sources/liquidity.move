module clashofbots::liquidity {
    use aptos_framework::coin::{Self as CoinMod, Coin};
    use aptos_framework::signer;
    use clashofbots::storage;

    friend clashofbots::mint;
    friend clashofbots::battle_engine;

    const E_NOT_INITIALIZED: u64 = 20;

    /// Aggregated liquidity locked for all bots, for a given coin type (e.g. USDT).
    struct LiquidityPool<CoinType> has key {
        vault: Coin<CoinType>,
    }

    /// Create the liquidity pool under the module address for a specific coin type.
    public entry fun init_module<CoinType>(account: &signer) {
        assert!(signer::address_of(account) == @clashofbots, E_NOT_INITIALIZED);
        if (!exists<LiquidityPool<CoinType>>(@clashofbots)) {
            move_to(account, LiquidityPool<CoinType> { vault: CoinMod::zero<CoinType>() });
        };
    }

    public fun assert_initialized<CoinType>() {
        assert!(exists<LiquidityPool<CoinType>>(@clashofbots), E_NOT_INITIALIZED);
    }

    public friend fun lock<CoinType>(payment: Coin<CoinType>) acquires LiquidityPool<CoinType> {
        assert_initialized<CoinType>();
        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@clashofbots);
        CoinMod::merge(&mut pool.vault, payment);
    }

    /// Returns total tokens (e.g. USDT) locked in the pool.
    public fun total_locked<CoinType>(): u64 acquires LiquidityPool<CoinType> {
        assert_initialized<CoinType>();
        let pool = borrow_global<LiquidityPool<CoinType>>(@clashofbots);
        CoinMod::value(&pool.vault)
    }

    /// Deterministic liquidity redistribution helper (purely trait-based, independent of coin type).
    public friend fun apply_transfer(winner: &mut storage::Bot, loser: &mut storage::Bot, percent: u64): u64 {
        let transfer = loser.liquidity * percent / 100;
        winner.liquidity = winner.liquidity + transfer;
        loser.liquidity = loser.liquidity - transfer;
        transfer
    }
}
