;; Wizard Duel Arena - Fantasy Themed Commit-Reveal Battle
;; Two wizards cast spells in secret, then reveal to determine the victor

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-DUEL-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-CAST (err u102))
(define-constant ERR-NOT-CAST (err u103))
(define-constant ERR-ALREADY-REVEALED (err u104))
(define-constant ERR-INVALID-SPELL (err u105))
(define-constant ERR-DUEL-FINISHED (err u106))
(define-constant ERR-REVEAL-TOO-EARLY (err u107))
(define-constant ERR-WRONG-WIZARD (err u108))

;; Spell constants
(define-constant FIREBALL u1)    ;; Beats Ice Shield
(define-constant ICE-SHIELD u2)  ;; Beats Lightning Bolt
(define-constant LIGHTNING-BOLT u3) ;; Beats Fireball

;; Duel states
(define-constant STATE-PREPARING-SPELLS u0)
(define-constant STATE-REVEALING-MAGIC u1)
(define-constant STATE-DUEL-COMPLETE u2)

;; Data structures
(define-map wizard-duels
  { duel-id: uint }
  {
    wizard1: principal,
    wizard2: principal,
    wizard1-spell-commit: (buff 32),
    wizard2-spell-commit: (buff 32),
    wizard1-spell: (optional uint),
    wizard2-spell: (optional uint),
    victor: (optional principal),
    state: uint,
    arena-opened: uint,
    mana-cost: uint
  }
)

(define-data-var next-duel-id uint u1)

;; Challenge another wizard to a duel
(define-public (challenge-wizard (opponent principal) (mana-wager uint))
  (let ((duel-id (var-get next-duel-id)))
    (asserts! (not (is-eq tx-sender opponent)) ERR-NOT-AUTHORIZED)
    (map-set wizard-duels
      { duel-id: duel-id }
      {
        wizard1: tx-sender,
        wizard2: opponent,
        wizard1-spell-commit: 0x,
        wizard2-spell-commit: 0x,
        wizard1-spell: none,
        wizard2-spell: none,
        victor: none,
        state: STATE-PREPARING-SPELLS,
        arena-opened: block-height,
        mana-cost: mana-wager
      }
    )
    (var-set next-duel-id (+ duel-id u1))
    (ok duel-id)
  )
)

;; Cast spell in secret (commit phase)
(define-public (cast-spell (duel-id uint) (spell-commitment (buff 32)))
  (let ((duel (unwrap! (map-get? wizard-duels { duel-id: duel-id }) ERR-DUEL-NOT-FOUND)))
    (asserts! (is-eq (get state duel) STATE-PREPARING-SPELLS) ERR-DUEL-FINISHED)
    (asserts! (> (len spell-commitment) u0) ERR-INVALID-SPELL)
    
    (if (is-eq tx-sender (get wizard1 duel))
      (begin
        (asserts! (is-eq (len (get wizard1-spell-commit duel)) u0) ERR-ALREADY-CAST)
        (map-set wizard-duels
          { duel-id: duel-id }
          (merge duel { wizard1-spell-commit: spell-commitment })
        )
        (check-both-spells-cast duel-id)
      )
      (if (is-eq tx-sender (get wizard2 duel))
        (begin
          (asserts! (is-eq (len (get wizard2-spell-commit duel)) u0) ERR-ALREADY-CAST)
          (map-set wizard-duels
            { duel-id: duel-id }
            (merge duel { wizard2-spell-commit: spell-commitment })
          )
          (check-both-spells-cast duel-id)
        )
        ERR-WRONG-WIZARD
      )
    )
  )
)

;; Check if both wizards have cast spells
(define-private (check-both-spells-cast (duel-id uint))
  (let ((duel (unwrap! (map-get? wizard-duels { duel-id: duel-id }) ERR-DUEL-NOT-FOUND)))
    (if (and 
          (> (len (get wizard1-spell-commit duel)) u0)
          (> (len (get wizard2-spell-commit duel)) u0))
      (begin
        (map-set wizard-duels
          { duel-id: duel-id }
          (merge duel { state: STATE-REVEALING-MAGIC })
        )
        (ok true)
      )
      (ok false)
    )
  )
)

;; Reveal the magical incantation
(define-public (reveal-incantation (duel-id uint) (spell uint) (magic-word uint))
  (let ((duel (unwrap! (map-get? wizard-duels { duel-id: duel-id }) ERR-DUEL-NOT-FOUND)))
    (asserts! (is-eq (get state duel) STATE-REVEALING-MAGIC) ERR-REVEAL-TOO-EARLY)
    (asserts! (or (is-eq spell FIREBALL) (is-eq spell ICE-SHIELD) (is-eq spell LIGHTNING-BOLT)) ERR-INVALID-SPELL)
    
    (let ((spell-hash (sha256 (concat (concat (unwrap-panic (to-consensus-buff? spell)) 
                                             (unwrap-panic (to-consensus-buff? magic-word))) 
                                     (unwrap-panic (to-consensus-buff? tx-sender))))))
      (if (is-eq tx-sender (get wizard1 duel))
        (begin
          (asserts! (is-eq spell-hash (get wizard1-spell-commit duel)) ERR-INVALID-SPELL)
          (asserts! (is-none (get wizard1-spell duel)) ERR-ALREADY-REVEALED)
          (map-set wizard-duels
            { duel-id: duel-id }
            (merge duel { wizard1-spell: (some spell) })
          )
          (determine-duel-victor duel-id)
        )
        (if (is-eq tx-sender (get wizard2 duel))
          (begin
            (asserts! (is-eq spell-hash (get wizard2-spell-commit duel)) ERR-INVALID-SPELL)
            (asserts! (is-none (get wizard2-spell duel)) ERR-ALREADY-REVEALED)
            (map-set wizard-duels
              { duel-id: duel-id }
              (merge duel { wizard2-spell: (some spell) })
            )
            (determine-duel-victor duel-id)
          )
          ERR-WRONG-WIZARD
        )
      )
    )
  )
)

;; Determine the victor of the magical duel
(define-private (determine-duel-victor (duel-id uint))
  (let ((duel (unwrap! (map-get? wizard-duels { duel-id: duel-id }) ERR-DUEL-NOT-FOUND)))
    (match (get wizard1-spell duel)
      spell1
      (match (get wizard2-spell duel)
        spell2
        (let ((victor (resolve-spell-battle spell1 spell2 (get wizard1 duel) (get wizard2 duel))))
          (map-set wizard-duels
            { duel-id: duel-id }
            (merge duel { victor: victor, state: STATE-DUEL-COMPLETE })
          )
          (ok victor)
        )
        (ok none)
      )
      (ok none)
    )
  )
)

;; Resolve spell battle: Fireball > Ice Shield > Lightning Bolt > Fireball
(define-private (resolve-spell-battle (spell1 uint) (spell2 uint) (wizard1 principal) (wizard2 principal))
  (if (is-eq spell1 spell2)
    none ;; Magical stalemate
    (if (or 
          (and (is-eq spell1 FIREBALL) (is-eq spell2 ICE-SHIELD))
          (and (is-eq spell1 ICE-SHIELD) (is-eq spell2 LIGHTNING-BOLT))
          (and (is-eq spell1 LIGHTNING-BOLT) (is-eq spell2 FIREBALL)))
      (some wizard1)
      (some wizard2)
    )
  )
)

;; Read-only functions
(define-read-only (get-duel-info (duel-id uint))
  (map-get? wizard-duels { duel-id: duel-id })
)

(define-read-only (get-duel-victor (duel-id uint))
  (match (map-get? wizard-duels { duel-id: duel-id })
    duel (ok (get victor duel))
    ERR-DUEL-NOT-FOUND
  )
)

(define-read-only (spell-name (spell-id uint))
  (if (is-eq spell-id FIREBALL)
    "Fireball"
    (if (is-eq spell-id ICE-SHIELD)
      "Ice Shield"
      (if (is-eq spell-id LIGHTNING-BOLT)
        "Lightning Bolt"
        "Unknown Spell"
      )
    )
  )
)