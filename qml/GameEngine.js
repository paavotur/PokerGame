
/*
 * No-Limit Five Card Draw betting engine.
 *
 * Betting amounts represent the player's total
 * contribution in the current betting round.
 */

function createGame(startingChips = 1000, ante = 10, minBet = 10) {
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

    const who = state.acting
    const other = otherPlayer(who)

    const owed = state.currentBet - state.roundBets[who]
    const maxTo = maxBetTo(state, who)

    if (owed > 0) {
        const options = ["fold", "call"]

        if (state.chips[other] > 0 &&
            maxTo > state.currentBet)
            options.push("raise")

        return options
    }

    const options = ["check"]

    if (state.currentBet === 0 &&
        state.chips[other] > 0 && maxTo > 0) {
        options.push("bet")
    } else if (state.currentBet > 0 &&
               state.chips[other] > 0 &&
               maxTo > state.currentBet) {
        options.push("raise")
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

        const isAllIn =
            amount === s.roundBets[who] + s.chips[who]

        if (!Number.isInteger(amount) ||
            amount <= s.currentBet ||
            amount > maxTo ||
            (amount < minimum && !isAllIn)) {
            throw new Error(
                "Invalid bet. Min: " + minimum +
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
