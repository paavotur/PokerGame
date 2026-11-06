.import "MultiplayerEngine.js" as Engine
.import "PokerHandEvaluator.js" as Hands

// Simple rule-based AI for three computer opponents.
// It sees only its own cards and public betting information.
function chooseDiscardIndices(cards) {
    const evaluated = Hands.evaluateHand(cards)
    const counts = {}
    for (const card of cards)
        counts[card.rank] = (counts[card.rank] || 0) + 1

    if (evaluated.rank >= 4 && evaluated.rank !== 7)
        return [] // Completed straight, flush, full house, or straight flush

    if (evaluated.rank >= 1) {
        const keepCount = evaluated.rank === 7 ? 4 :
                          evaluated.rank === 3 ? 3 : 2
        return cards.map((c, i) => i)
            .filter(i => counts[cards[i].rank] < keepCount)
    }

    // With high card, draw one to four cards of a flush.
    for (const suit of ["♠", "♥", "♦", "♣"]) {
        const sameSuit = cards.filter(c => c.suit === suit)
        if (sameSuit.length === 4)
            return cards.map((c, i) => i).filter(i => cards[i].suit !== suit)
    }

    // Draw one to a four-card straight (including A-2-3-4-5).
    const runs = [[14, 2, 3, 4, 5]]
    for (let high = 6; high <= 14; high++)
        runs.push([high, high - 1, high - 2, high - 3, high - 4])

    for (const run of runs) {
        if (cards.filter(c => run.includes(c.rank)).length === 4)
            return cards.map((c, i) => i).filter(i => !run.includes(cards[i].rank))
    }

    // Otherwise keep up to two high cards.
    const keep = cards.map((c, i) => ({ rank: c.rank, index: i }))
        .filter(c => c.rank >= 11)
        .sort((a, b) => b.rank - a.rank)
        .slice(0, 2)
        .map(c => c.index)

    return cards.map((c, i) => i).filter(i => !keep.includes(i))
}

function chooseBettingAction(game) {
    const p = game.players[game.turnIndex]
    if (!p || p.human)
        throw new Error("It is not a computer turn")

    const available = Engine.availableActions(game)
    if (!available.length)
        throw new Error("No legal computer action")

    const hand = Hands.evaluateHand(p.hand)
    const strength = [0.22, 0.48, 0.71, 0.83, 0.88,
                      0.92, 0.94, 0.97, 0.99, 1.0][hand.rank]
    const owed = Math.max(0, game.currentBet - p.roundBet)

    function wager(action) {
        const maximum = Engine.maxBetTo(game, p.id)
        const minimum = Math.min(maximum, Engine.minBetTo(game))
        const preferred = game.currentBet + Math.max(
            game.minBet, Math.round(game.pot * (strength >= 0.8 ? 0.7 : 0.35)))
        return {
            action: action,
            amount: Math.max(minimum, Math.min(maximum, preferred))
        }
    }

    if (available.includes("check")) {
        const betAction = available.includes("bet") ? "bet" : "raise"
        const chance = strength >= 0.78 ? 0.7 :
                       strength >= 0.48 ? 0.25 : 0.05
        if (available.includes(betAction) && Math.random() < chance)
            return wager(betAction)
        return { action: "check", amount: 0 }
    }

    if (available.includes("call")) {
        const potOdds = owed / Math.max(1, game.pot + owed)
        const risk = owed / Math.max(1, p.chips)
        if (available.includes("fold") &&
            strength < 0.24 + 0.25 * potOdds + 0.25 * risk &&
            Math.random() >= 0.06)
            return { action: "fold", amount: 0 }

        if (available.includes("raise") && strength > 0.83 &&
            Math.random() < 0.4)
            return wager("raise")

        return { action: "call", amount: 0 }
    }

    throw new Error("Unexpected computer betting state")
}
