module clashofbots::battle_engine {
    use std::vector;
    use aptos_framework::signer;
    use aptos_std::transaction_context;
    use clashofbots::{liquidity, randomness, storage};

    const E_SAME_BOT: u64 = 40;
    const E_TARGET_NOT_FOUND: u64 = 41;

    /// Execute a deterministic 1v1 battle between two bots.
    public entry fun battle(attacker: &signer, attacker_bot_id: u64, defender_bot_id: u64) acquires storage::Registry, storage::History, storage::Events {
        storage::assert_initialized();
        assert!(attacker_bot_id != defender_bot_id, E_SAME_BOT);

        let caller = signer::address_of(attacker);
        storage::assert_owner(attacker_bot_id, caller);
        assert!(storage::bot_exists(defender_bot_id), E_TARGET_NOT_FOUND);

        let mut attacker_bot = storage::get_bot(attacker_bot_id);
        let mut defender_bot = storage::get_bot(defender_bot_id);

        let attacker_score = battle_score(&attacker_bot, &defender_bot);
        let defender_score = battle_score(&defender_bot, &attacker_bot);

        let mut winner_id = attacker_bot_id;
        let mut loser_id = defender_bot_id;
        let mut winner = attacker_bot;
        let mut loser = defender_bot;

        if (defender_score > attacker_score || (defender_score == attacker_score && defender_bot_id < attacker_bot_id)) {
            winner_id = defender_bot_id;
            loser_id = attacker_bot_id;
            winner = defender_bot;
            loser = attacker_bot;
        };

        winner.wins = winner.wins + 1;
        winner.battles = winner.battles + 1;
        loser.battles = loser.battles + 1;

        let _ = liquidity::apply_transfer(&mut winner, &mut loser, storage::LIQUIDITY_TRANSFER_PERCENT);

        // Deterministic evolution.
        winner.confidence = winner.confidence + 1;
        loser.adaptability = loser.adaptability + 1;

        // Optional random post-battle evolution that does not affect battle outcome.
        let roll = randomness::percent_roll(winner_id, loser_id);
        if (roll < 20) {
            winner.confidence = winner.confidence + 2;
        };

        let tx_hash = transaction_context::get_script_hash();
        if (roll < 3) {
            storage::emit_rare_event(winner_id, winner.owner, vector::copy(&tx_hash));
        };

        // Persist updates.
        storage::update_bot(winner);
        storage::update_bot(loser);

        storage::push_battle_record(storage::BattleRecord {
            attacker: attacker_bot.owner,
            defender: defender_bot.owner,
            winner: storage::owner_of(winner_id),
            tx: tx_hash,
        });
    }

    fun battle_score(attacker: &storage::Bot, defender: &storage::Bot): i128 {
        let attack_power: u64 = attacker.aggression * 2 + attacker.confidence;
        let defense_power: u64 = defender.defense * 2 + defender.adaptability;
        let strategy: u64 = calculate_strategy_bonus(attacker.aggression, defender.defense);
        (attack_power as i128) - (defense_power as i128) + (strategy as i128)
    }

    fun calculate_strategy_bonus(a: u64, d: u64): u64 {
        if (a > d) {
            3
        } else if (a == d) {
            1
        } else {
            0
        }
    }
}
