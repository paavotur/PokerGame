

function createDeck() {
    const deck = []
    const suits = ["♠", "♥", "♦", "♣"]

    for (const suit of suits) {
        for (let rank = 2; rank <= 14; rank++) {
            deck.push({ suit: suit, rank: rank })
        }
    }

    return deck
}

function shuffleDeck(deck) {
    for (let i = deck.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))
        const temp = deck[i]
        deck[i] = deck[j]
        deck[j] = temp
    }

    return deck
}

function startHand() {
    const deck = shuffleDeck(createDeck())

    return {
        playerHand: deck.splice(0, 5),
        computerHand: deck.splice(0, 5),
        remainingDeck: deck
    }
}

function exchangeCards(hand, selectedIndices, deck) {
    const newHand = hand.slice()
    const newDeck = deck.slice()

    if (selectedIndices.length > newDeck.length)
        throw new Error("Not enough cards in deck")

    for (const index of selectedIndices)
        newHand[index] = newDeck.pop()

    return {
        hand: newHand,
        remainingDeck: newDeck
    }
}

function randomExchangeIndices() {
    const indices = [0, 1, 2, 3, 4]

    for (let i = indices.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))
        const temp = indices[i]
        indices[i] = indices[j]
        indices[j] = temp
    }

    return indices.slice(0, Math.floor(Math.random() * 6))
}


/*
 * No-Limit Five Card Draw betting engine.
 *
 * Betting amounts represent the player's total
 * contribution in the current betting round.
 */

function createGame(startingChips = 1000, ante = 20, minBet = 50) {
    if (![startingChips, ante, minBet].every(Number.isInteger) ||
        startingChips <= 0 || ante <= 0 || minBet <= 0)
        throw new Error("Invalid game settings")

    return {
        phase: "ready",
        chips: {
            player: startingChips,
            computer: startingChips
        },
        ante: ante,
        minBet: minBet,
        pot: 0,
        lastPot: 0,
        handNumber: 0,
        firstActor: "player",
        acting: null,
        roundBets: { player: 0, computer: 0 },
        acted: { player: false, computer: false },
        currentBet: 0,
        lastRaise: minBet,
        winner: null,
        reason: ""
    }
}

function cloneGame(state) {
    return JSON.parse(JSON.stringify(state))
}

function otherPlayer(who) {
    return who === "player" ? "computer" : "player"
}

// Reset betting information for a new round.
function resetBettingRound(state) {
    state.roundBets = { player: 0, computer: 0 }
    state.acted = { player: false, computer: false }
    state.currentBet = 0
    state.lastRaise = state.minBet
    state.acting = state.firstActor

    return state
}

// Begin a new hand and collect antes.
// Cards are still dealt separately by startHand().
function startBettingHand(state) {
    if (state.phase !== "ready" && state.phase !== "finished")
        throw new Error("Previous hand is still active")

    const s = cloneGame(state)

    if (s.chips.player < s.ante ||
        s.chips.computer < s.ante)
        throw new Error("Not enough chips for ante")

    s.handNumber++
    s.firstActor = s.handNumber % 2
                   ? "player" : "computer"

    s.chips.player -= s.ante
    s.chips.computer -= s.ante

    s.pot = 2 * s.ante
    s.lastPot = 0
    s.winner = null
    s.reason = ""
    s.phase = "betting1"

    return resetBettingRound(s)
}

// Maximum matched total bet in this round.
// In heads-up poker, unmatched excess is not wagered.
function maxBetTo(state, who) {
    const other = otherPlayer(who)

    return Math.min(
        state.roundBets[who] + state.chips[who],
        state.roundBets[other] + state.chips[other]
    )
}

// Returns currently allowed actions.
function availableActions(state) {
    if (state.phase !== "betting1" &&
        state.phase !== "betting2")
        return []

    if (state.acting !== "player" &&
        state.acting !== "computer")
        return []

    const who = state.acting
    const owed = state.currentBet - state.roundBets[who]

    if (owed > 0) {
        const options = ["fold", "call"]

        if (canIncreaseBet(state, who))
            options.push("raise")

        return options
    }

    const options = ["check"]

    if (canIncreaseBet(state, who)) {
        options.push(
            state.currentBet === 0 ? "bet" : "raise"
        )
    }

    return options
}


// Award the pot when one player wins.
function awardPot(state, winner, reason) {
    state.lastPot = state.pot
    state.chips[winner] += state.pot

    state.pot = 0
    state.winner = winner
    state.reason = reason
    state.phase = "finished"
    state.acting = null

    return state
}

/*
 * Apply a betting action.
 *
 * action: "check", "bet", "call", "raise", "fold"
 * amount: TOTAL round contribution for bet/raise
 */
function applyBettingAction(state, action, amount) {
    const s = cloneGame(state)

    if (!availableActions(s).includes(action))
        throw new Error("Action not allowed: " + action)

    const who = s.acting
    const other = otherPlayer(who)
    const owed = s.currentBet - s.roundBets[who]

    if (action === "fold")
        return awardPot(s, other, "fold")

    if (action === "bet" || action === "raise") {
        const maxTo = maxBetTo(s, who)

        const minimum = action === "bet"
                      ? s.minBet
                      : s.currentBet + s.lastRaise


        const isEffectiveAllIn = amount === maxTo

        if (!Number.isInteger(amount) ||
            amount <= s.currentBet ||
            amount > maxTo ||
            (amount < minimum && !isEffectiveAllIn)) {

            throw new Error(
                "Invalid bet. Min: " + Math.min(minimum, maxTo) +
                ", max: " + maxTo
            )
        }

        const additional = amount - s.roundBets[who]
        const raiseSize = amount - s.currentBet

        s.chips[who] -= additional
        s.pot += additional
        s.roundBets[who] = amount
        s.currentBet = amount

        if (action === "bet" ||
            raiseSize >= s.lastRaise)
            s.lastRaise = raiseSize

        s.acted[who] = true
        s.acted[other] = false

    } else if (action === "call") {
        if (owed > s.chips[who])
            throw new Error("Not enough chips to call")

        s.chips[who] -= owed
        s.pot += owed
        s.roundBets[who] += owed
        s.acted[who] = true

    } else if (action === "check") {
        s.acted[who] = true
    }

    // The round ends when both players have acted
    // and their contributions are equal.
    if (s.acted.player &&
        s.acted.computer &&
        s.roundBets.player === s.roundBets.computer) {

        s.phase = s.phase === "betting1"
                ? "draw" : "showdown"

        s.acting = null

    } else {
        s.acting = other
    }

    return s
}

// Called after both players have exchanged cards.
function completeDraw(state) {
    if (state.phase !== "draw")
        throw new Error("Not in draw phase")

    const s = cloneGame(state)

    if (s.chips.player === 0 ||
        s.chips.computer === 0) {
        // Somebody is all-in: skip further betting.
        s.phase = "showdown"
        s.acting = null
    } else {
        s.phase = "betting2"
        resetBettingRound(s)
    }

    return s
}

/*
 * Resolve the showdown after evaluating both hands.
 *
 * winner: "player", "computer" or "tie"
 */
function settleShowdown(state, winner) {
    if (state.phase !== "showdown")
        throw new Error("Not ready for showdown")

    if (!["player", "computer", "tie"].includes(winner))
        throw new Error("Invalid winner")

    const s = cloneGame(state)

    if (winner !== "tie")
        return awardPot(s, winner, "showdown")

    s.lastPot = s.pot

    const half = Math.floor(s.pot / 2)
    s.chips.player += half + (s.pot % 2)
    s.chips.computer += half

    s.pot = 0
    s.winner = "tie"
    s.reason = "showdown"
    s.phase = "finished"
    s.acting = null

    return s
}

function canIncreaseBet(state, who) {
    const other = otherPlayer(who)

    if (state.chips[other] === 0)
        return false

    const maxTo = maxBetTo(state, who)

    const fullMinimum = state.currentBet === 0
        ? state.minBet
        : state.currentBet + state.lastRaise

    return maxTo > state.currentBet &&
        (maxTo >= fullMinimum ||
         maxTo === state.roundBets[who] + state.chips[who] ||
         maxTo === state.roundBets[other] + state.chips[other])
}
