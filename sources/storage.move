module clashofbots::storage {
    use std::vector;
    use aptos_framework::event;
    use aptos_framework::signer;
    use aptos_std::table::{Self as Table, Table};

    friend clashofbots::mint;
    friend clashofbots::battle_engine;
    friend clashofbots::liquidity;
    friend clashofbots::leaderboard;
    friend clashofbots::randomness;

    /// Maximum number of battle records kept on-chain.
    const MAX_HISTORY: u64 = 10;

    /// Price to mint a bot: 10 APT (10 * 10^8 Octas).
    public const MINT_PRICE: u64 = 1_000_000_000;
    /// Bonus added to the displayed value per win (0.1 APT).
    public const WIN_BONUS_PER_WIN: u64 = 10_000_000;
    /// Percent of loser liquidity transferred to winner on victory.
    public const LIQUIDITY_TRANSFER_PERCENT: u64 = 5;

    const E_NOT_INITIALIZED: u64 = 0;
    const E_BOT_NOT_FOUND: u64 = 1;
    const E_NOT_OWNER: u64 = 2;

    /// Core bot data stored on-chain.
    public struct Bot has key, store, copy, drop {
        id: u64,
        owner: address,
        aggression: u64,
        defense: u64,
        adaptability: u64,
        confidence: u64,
        speed: u64,
        liquidity: u64,
        wins: u64,
        battles: u64,
    }

    /// Recent battle record used for UI history.
    public struct BattleRecord has drop, store, copy {
        attacker: address,
        defender: address,
        winner: address,
        tx: vector<u8>,
    }

    /// Registry of all bots and ownership index.
    struct Registry has key {
        bots: Table<u64, Bot>,
        owner_index: Table<address, vector<u64>>,
        all_bots: vector<u64>,
        next_id: u64,
    }

    /// Rolling buffer of the last MAX_HISTORY battles.
    struct History has key {
        records: vector<BattleRecord>,
    }

    /// Rare evolution events emitted for off-chain listeners.
    public struct RareEvolutionEvent has drop, store, copy {
        bot_id: u64,
        owner: address,
        tx: vector<u8>,
    }

    struct Events has key {
        rare_events: event::EventHandle<RareEvolutionEvent>,
    }

    /// Initialize on publish by the module owner.
    public entry fun init_module(account: &signer) {
        assert!(
            signer::address_of(account) == @clashofbots,
            E_NOT_INITIALIZED
        );
        if (!exists<Registry>(@clashofbots)) {
            move_to(
                account,
                Registry {
                    bots: Table::new<u64, Bot>(),
                    owner_index: Table::new<address, vector<u64>>(),
                    all_bots: vector::empty<u64>(),
                    next_id: 0,
                },
            );
        };
        if (!exists<History>(@clashofbots)) {
            move_to(account, History { records: vector::empty<BattleRecord>() });
        };
        if (!exists<Events>(@clashofbots)) {
            let handle = event::new_event_handle<RareEvolutionEvent>(account);
            move_to(account, Events { rare_events: handle });
        };
    }

    public fun is_initialized(): bool {
        exists<Registry>(@clashofbots) && exists<History>(@clashofbots) && exists<Events>(@clashofbots)
    }

    public fun assert_initialized() {
        assert!(is_initialized(), E_NOT_INITIALIZED);
    }

    public fun mint_price(): u64 {
        MINT_PRICE
    }

    public fun bot_value(bot: &Bot): u64 {
        bot.liquidity + bot.wins * WIN_BONUS_PER_WIN
    }

    public fun bot_exists(id: u64): bool acquires Registry {
        assert_initialized();
        let registry = borrow_global<Registry>(@clashofbots);
        Table::contains(&registry.bots, id)
    }

    public fun owner_of(id: u64): address acquires Registry {
        assert_initialized();
        let registry = borrow_global<Registry>(@clashofbots);
        let bot_ref = Table::borrow(&registry.bots, id);
        bot_ref.owner
    }

    public friend fun assert_owner(id: u64, owner: address) acquires Registry {
        assert!(bot_exists(id), E_BOT_NOT_FOUND);
        let current_owner = owner_of(id);
        assert!(current_owner == owner, E_NOT_OWNER);
    }

    /// Reserve a new bot id without exposing registry internals.
    public friend fun next_bot_id() : u64 acquires Registry {
        assert_initialized();
        let registry = borrow_global_mut<Registry>(@clashofbots);
        let id = registry.next_id;
        registry.next_id = id + 1;
        id
    }

    /// Expose the upcoming id without incrementing. Useful for deterministic trait generation.
    public fun preview_next_id(): u64 acquires Registry {
        assert_initialized();
        let registry = borrow_global<Registry>(@clashofbots);
        registry.next_id
    }

    public friend fun create_bot(
        owner: address,
        aggression: u64,
        defense: u64,
        adaptability: u64,
        confidence: u64,
        speed: u64,
        liquidity: u64,
    ): u64 acquires Registry {
        assert_initialized();
        let registry = borrow_global_mut<Registry>(@clashofbots);
        let id = registry.next_id;
        registry.next_id = id + 1;

        let bot = Bot {
            id,
            owner,
            aggression,
            defense,
            adaptability,
            confidence,
            speed,
            liquidity,
            wins: 0,
            battles: 0,
        };

        Table::add(&mut registry.bots, id, bot);
        add_to_owner_index(&mut registry.owner_index, owner, id);
        vector::push_back(&mut registry.all_bots, id);
        id
    }

    public fun get_bot(id: u64): Bot acquires Registry {
        assert_initialized();
        assert!(bot_exists(id), E_BOT_NOT_FOUND);
        let registry = borrow_global<Registry>(@clashofbots);
        *Table::borrow(&registry.bots, id)
    }

    public friend fun update_bot(bot: Bot) acquires Registry {
        assert_initialized();
        let registry = borrow_global_mut<Registry>(@clashofbots);
        let slot = Table::borrow_mut(&mut registry.bots, bot.id);
        *slot = bot;
    }

    public friend fun touch_battle(id: u64) acquires Registry {
        assert_initialized();
        let registry = borrow_global_mut<Registry>(@clashofbots);
        let bot_ref = Table::borrow_mut(&mut registry.bots, id);
        bot_ref.battles = bot_ref.battles + 1;
    }

    public friend fun add_win(id: u64) acquires Registry {
        assert_initialized();
        let registry = borrow_global_mut<Registry>(@clashofbots);
        let bot_ref = Table::borrow_mut(&mut registry.bots, id);
        bot_ref.wins = bot_ref.wins + 1;
    }

    public friend fun adjust_liquidity(id: u64, delta: i128) acquires Registry {
        assert_initialized();
        let registry = borrow_global_mut<Registry>(@clashofbots);
        let bot_ref = Table::borrow_mut(&mut registry.bots, id);
        if (delta >= 0) {
            bot_ref.liquidity = bot_ref.liquidity + (delta as u64);
        } else {
            let removal = (-delta) as u64;
            bot_ref.liquidity = bot_ref.liquidity - removal;
        };
    }

    public fun bots_for_owner(owner: address): vector<u64> acquires Registry {
        assert_initialized();
        let registry = borrow_global<Registry>(@clashofbots);
        if (Table::contains(&registry.owner_index, owner)) {
            *Table::borrow(&registry.owner_index, owner)
        } else {
            vector::empty<u64>()
        }
    }

    public fun all_bot_ids(): vector<u64> acquires Registry {
        assert_initialized();
        let registry = borrow_global<Registry>(@clashofbots);
        vector::copy(&registry.all_bots)
    }

    public friend fun push_battle_record(record: BattleRecord) acquires History {
        assert_initialized();
        let history = borrow_global_mut<History>(@clashofbots);
        let len = vector::length(&history.records);
        if (len >= MAX_HISTORY) {
            let _ = vector::remove(&mut history.records, 0);
        };
        vector::push_back(&mut history.records, record);
    }

    public friend fun emit_rare_event(bot_id: u64, owner: address, tx: vector<u8>) acquires Events {
        assert_initialized();
        let events = borrow_global_mut<Events>(@clashofbots);
        event::emit(
            &mut events.rare_events,
            RareEvolutionEvent { bot_id, owner, tx },
        );
    }

    public fun battle_history(): vector<BattleRecord> acquires History {
        assert_initialized();
        let history = borrow_global<History>(@clashofbots);
        vector::copy(&history.records)
    }

    fun add_to_owner_index(index: &mut Table<address, vector<u64>>, owner: address, id: u64) {
        if (!Table::contains(index, owner)) {
            Table::add(index, owner, vector::empty<u64>());
        };
        let owned = Table::borrow_mut(index, owner);
        vector::push_back(owned, id);
    }
}
