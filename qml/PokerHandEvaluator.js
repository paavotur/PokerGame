
/**
 * Evaluates a five-card poker hand.
 *
 * Card format:
 * { rank: 14, suit: "♠" }
 *
 * Returns:
 * {
 *     rank: 1,
 *     name: "One Pair",
 *     kickers: [14, 13, 10, 8]
 * }
 */

// Returns the highest card of a straight.
// Returns 0 if the cards do not form a straight.
function getStraightHigh(ranks) {
    const unique = [...new Set(ranks)]

    if (unique.length !== 5)
        return 0

    // Normal straight
    if (unique[0] - unique[4] === 4)
        return unique[0]

    // Ace-low straight: A-2-3-4-5
    if (unique.join(",") === "14,5,4,3,2")
        return 5

    return 0
}

function evaluateHand(cards) {
    if (cards.length !== 5)
        throw new Error("Poker hand must contain 5 cards")

    const ranks = cards
        .map(card => card.rank)
        .sort((a, b) => b - a)

    const isFlush = cards.every(
        card => card.suit === cards[0].suit
    )

    const straightHigh = getStraightHigh(ranks)

    // Group cards by rank and count occurrences.
    // Sort by count first, then by card rank.
    const groups = [...new Set(ranks)]
        .map(rank => ({
            rank: rank,
            count: ranks.filter(r => r === rank).length
        }))
        .sort((a, b) =>
            b.count - a.count || b.rank - a.rank
        )

    // Royal Flush
    if (isFlush && straightHigh === 14) {
        return {
            rank: 9,
            name: "Royal Flush",
            kickers: [14]
        }
    }

    // Straight Flush
    if (isFlush && straightHigh) {
        return {
            rank: 8,
            name: "Straight Flush",
            kickers: [straightHigh]
        }
    }

    // Four of a Kind
    if (groups[0].count === 4) {
        return {
            rank: 7,
            name: "Four of a Kind",
            kickers: [groups[0].rank, groups[1].rank]
        }
    }

    // Full House
    if (groups[0].count === 3 &&
        groups[1].count === 2) {
        return {
            rank: 6,
            name: "Full House",
            kickers: [groups[0].rank, groups[1].rank]
        }
    }

    // Flush
    if (isFlush) {
        return {
            rank: 5,
            name: "Flush",
            kickers: ranks
        }
    }

    // Straight
    if (straightHigh) {
        return {
            rank: 4,
            name: "Straight",
            kickers: [straightHigh]
        }
    }

    // Three of a Kind
    if (groups[0].count === 3) {
        return {
            rank: 3,
            name: "Three of a Kind",
            kickers: groups.map(g => g.rank)
        }
    }

    // Two Pair
    if (groups[0].count === 2 &&
        groups[1].count === 2) {
        return {
            rank: 2,
            name: "Two Pair",
            kickers: groups.map(g => g.rank)
        }
    }

    // One Pair
    if (groups[0].count === 2) {
        return {
            rank: 1,
            name: "One Pair",
            kickers: groups.map(g => g.rank)
        }
    }

    // High Card
    return {
        rank: 0,
        name: "High Card",
        kickers: ranks
    }
}

/**
 * Compares two poker hands.
 *
 * Returns:
 *  1 = player wins
 * -1 = computer wins
 *  0 = tie
 */
function compareHands(playerHand, computerHand) {
    const player = evaluateHand(playerHand)
    const computer = evaluateHand(computerHand)

    if (player.rank !== computer.rank)
        return player.rank > computer.rank ? 1 : -1

    // Same hand category: compare kickers.
    for (let i = 0; i < player.kickers.length; i++) {
        if (player.kickers[i] > computer.kickers[i])
            return 1

        if (player.kickers[i] < computer.kickers[i])
            return -1
    }

    return 0
}
