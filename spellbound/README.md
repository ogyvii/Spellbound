# Spellbound 🧙‍♂️✨

**Spellbound** is a fantasy-themed, commit-reveal based Wizard Duel Arena smart contract written in Clarity for the Stacks blockchain. Two wizards secretly cast powerful spells, then reveal them to determine the victor in a cryptographically fair and magical showdown.

## 🧪 Game Mechanics

### Duel Flow
1. **Challenge** – A wizard initiates a duel by challenging an opponent with a specified mana wager.
2. **Commit Phase** – Both wizards secretly cast their spells by submitting a hashed commitment.
3. **Reveal Phase** – Wizards reveal their spells and secret magic word to verify their commitment.
4. **Outcome** – The contract determines the winner based on a rock-paper-scissors-like rule.

### Spell Rules
- 🔥 **Fireball (1)** defeats ❄️ **Ice Shield**
- ❄️ **Ice Shield (2)** defeats ⚡ **Lightning Bolt**
- ⚡ **Lightning Bolt (3)** defeats 🔥 **Fireball**
- Same spells result in a **stalemate**

## 🔐 Commit-Reveal Scheme

The commitment is a `sha256` hash of:
```

concat(spell || magic-word || sender)

```
This prevents front-running and ensures fairness.

## 📦 Functions

### Public Functions
- `challenge-wizard(opponent, mana-wager)` – Initiate a duel.
- `cast-spell(duel-id, spell-commitment)` – Submit secret spell commitment.
- `reveal-incantation(duel-id, spell, magic-word)` – Reveal your spell and verify commitment.

### Read-only Functions
- `get-duel-info(duel-id)` – View full duel state.
- `get-duel-victor(duel-id)` – Fetch the winner (if resolved).
- `spell-name(spell-id)` – Returns the string name of a spell.

## ❗ Error Codes
- `u100` – Not authorized
- `u101` – Duel not found
- `u102` – Already cast spell
- `u103` – Spell not cast yet
- `u104` – Already revealed
- `u105` – Invalid spell
- `u106` – Duel already finished
- `u107` – Reveal phase not started
- `u108` – Caller not a participating wizard

## 🛠 Deployment

Deploy this smart contract using the Clarity CLI or via the Stacks Explorer contract deployer. Make sure you use 32-byte buffers for hashing and proper spell/magic-word encoding.

## 🌐 Keywords

`stacks`, `clarity`, `commit-reveal`, `game`, `wizard`, `duel`, `blockchain`, `smart-contract`, `spellbound`
```
