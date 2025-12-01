module clashofbots::liquidity {
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self as CoinMod, Coin};
    use aptos_framework::signer;
    use clashofbots::storage;

    friend clashofbots::mint;
    friend clashofbots::battle_engine;

    const E_NOT_INITIALIZED: u64 = 20;

    /// Aggregated liquidity locked for all bots.
    struct LiquidityPool has key {
        vault: Coin<AptosCoin>,
    }

    /// Create the liquidity pool under the module address.
    public entry fun init_module(account: &signer) {
        assert!(signer::address_of(account) == @clashofbots, E_NOT_INITIALIZED);
        if (!exists<LiquidityPool>(@clashofbots)) {
            move_to(account, LiquidityPool { vault: CoinMod::zero<AptosCoin>() });
        };
    }

    public fun assert_initialized() {
        assert!(exists<LiquidityPool>(@clashofbots), E_NOT_INITIALIZED);
    }

    public friend fun lock(payment: Coin<AptosCoin>) acquires LiquidityPool {
        assert_initialized();
        let pool = borrow_global_mut<LiquidityPool>(@clashofbots);
        CoinMod::merge(&mut pool.vault, payment);
    }

    /// Returns total APT locked in the pool.
    public fun total_locked(): u64 acquires LiquidityPool {
        assert_initialized();
        let pool = borrow_global<LiquidityPool>(@clashofbots);
        CoinMod::value(&pool.vault)
    }

    /// Deterministic liquidity redistribution helper.
    public friend fun apply_transfer(winner: &mut storage::Bot, loser: &mut storage::Bot, percent: u64): u64 {
        let transfer = loser.liquidity * percent / 100;
        winner.liquidity = winner.liquidity + transfer;
        loser.liquidity = loser.liquidity - transfer;
        transfer
    }
}
