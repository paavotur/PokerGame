
.import "PokerHandEvaluator.js" as PokerHands
.import "GameEngine.js" as GameEngine

// Return indices (0-4) of cards the computer wants to replace.
function chooseDiscardIndices(cards) {
    const result = PokerHands.evaluateHand(cards)
    const counts = {}

    for (const card of cards)
        counts[card.rank] = (counts[card.rank] || 0) + 1

    // Keep completed straights, flushes, full houses, etc.
    if (result.rank === 9 || result.rank === 8 ||
        result.rank === 6 || result.rank === 5 ||
        result.rank === 4)
        return []

    // Keep pairs, trips and quads. Replace kickers.
    if (result.rank >= 1) {
        const minimumCount = result.rank === 7 ? 4 :
                             result.rank === 3 ? 3 : 2

        return cards.map((card, index) => ({ card, index }))
            .filter(item => counts[item.card.rank] < minimumCount)
            .map(item => item.index)
    }

    // High card: try completing a flush.
    const suits = ["♠", "♥", "♦", "♣"]

    for (const suit of suits) {
        const keep = cards
            .map((card, index) =>
                card.suit === suit ? index : -1)
            .filter(index => index !== -1)

        if (keep.length === 4)
            return [0, 1, 2, 3, 4]
                .filter(index => !keep.includes(index))
    }

    // High card: try completing a straight.
    const runs = [[14, 2, 3, 4, 5]]

    for (let high = 6; high <= 14; high++)
        runs.push([
            high, high - 1, high - 2,
            high - 3, high - 4
        ])

    for (const run of runs) {
        const keep = cards
            .map((card, index) =>
                run.includes(card.rank) ? index : -1)
            .filter(index => index !== -1)

        if (keep.length === 4)
            return [0, 1, 2, 3, 4]
                .filter(index => !keep.includes(index))
    }

    // Otherwise keep up to two high cards (J, Q, K, A).
    const highIndices = cards
        .map((card, index) => ({ rank: card.rank, index }))
        .filter(item => item.rank >= 11)
        .sort((a, b) => b.rank - a.rank)
        .slice(0, 2)
        .map(item => item.index)

    return [0, 1, 2, 3, 4]
        .filter(index => !highIndices.includes(index))
}

// Heuristic hand strength, NOT an exact win probability.
function estimateStrength(cards, state, playerDrawCount) {
    const hand = PokerHands.evaluateHand(cards)
    let strength

    switch (hand.rank) {
    case 9: strength = 1.00; break
    case 8: strength = 0.98; break
    case 7: strength = 0.96; break
    case 6: strength = 0.94; break
    case 5: strength = 0.92; break
    case 4: strength = 0.89; break

    case 3:
        strength = 0.83 +
            (hand.kickers[0] - 2) * 0.005
        break

    case 2:
        strength = 0.72 +
            (hand.kickers[0] - 2) * 0.005
        break

    case 1:
        strength = 0.42 +
            (hand.kickers[0] - 2) * 0.020
        break

    default:
        strength = 0.18 +
            (hand.kickers[0] - 2) * 0.012

        if (state.phase === "betting1" &&
            chooseDiscardIndices(cards).length === 1)
            strength += 0.10
    }

    // Opponent's draw count provides a clue.
    if (state.phase === "betting2") {
        if (playerDrawCount === 0)
            strength -= 0.06
        else if (playerDrawCount >= 4)
            strength += 0.04
    }

    return Math.max(0.05, Math.min(1, strength))
}

// Return TOTAL round bet, not an additional raise amount.
function chooseBetAmount(state, strength) {
    const maxTotal = GameEngine.maxBetTo(
        state, "computer"
    )

    const minTotal = Math.min(
        maxTotal,
        state.currentBet === 0
            ? state.minBet
            : state.currentBet + state.lastRaise
    )

    const potFraction = strength >= 0.85 ? 0.70 : 0.40

    const increase = Math.max(
        state.minBet,
        Math.round(state.pot * potFraction)
    )

    const preferredTotal = state.currentBet + increase

    return Math.max(
        minTotal,
        Math.min(maxTotal, preferredTotal)
    )
}

// Choose an action allowed by GameEngine.
function chooseBettingAction(
    state, computerHand, playerDrawCount
) {
    if (state.acting !== "computer")
        throw new Error("Not computer's turn")

    const actions = GameEngine.availableActions(state)
    const strength = estimateStrength(
        computerHand, state, playerDrawCount
    )

    const owed = Math.max(
        0,
        state.currentBet - state.roundBets.computer
    )

    const random = Math.random()

    // No outstanding bet: check, bet or raise.
    if (actions.includes("check")) {
        const wantsBet =
            strength >= 0.80 ? random < 0.85 :
            strength >= 0.56 ? random < 0.45 :
            random < 0.07 // Occasional bluff

        const action = actions.includes("bet")
            ? "bet" : "raise"

        if (wantsBet && actions.includes(action)) {
            return {
                action: action,
                amount: chooseBetAmount(state, strength)
            }
        }

        return { action: "check", amount: 0 }
    }

    // Facing an opponent's bet.
    if (actions.includes("call")) {
        const chipsBeforeCall = state.chips.computer + owed
        const stackRisk = owed / Math.max(1, chipsBeforeCall)
        const potOdds = owed / Math.max(1, state.pot + owed)

        const required =
            0.24 + 0.38 * stackRisk + 0.18 * potOdds

        if (strength < required && random >= 0.05)
            return { action: "fold", amount: 0 }

        if (strength >= 0.80 &&
            actions.includes("raise") &&
            random < 0.45) {

            return {
                action: "raise",
                amount: chooseBetAmount(state, strength)
            }
        }

        return { action: "call", amount: 0 }
    }

    throw new Error("No valid computer betting action")
}
