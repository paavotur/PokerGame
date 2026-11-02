
function createDeck() {
    const deck = []
    const suits = ["♠", "♥", "♦", "♣"]

    for (const suit of suits) {
        for (let rank = 2; rank <= 14; rank++) {
            deck.push({
                suit: suit,
                rank: rank
            })
        }
    }

    return deck
}

function shuffleDeck(deck) {
    // Fisher-Yates shuffle
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
