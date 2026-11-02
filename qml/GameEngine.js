
function createDeck() {
    const deck = []
    const suits = ["♠", "♥", "♦", "♣"]

    for (const suit of suits) {
        for (let rank = 2; rank <= 14; rank++) {
            deck.push({
                suit: suit,
                rank: rank })
        }
    }

    return deck
}

// Fisher-Yates shuffle
function shuffle(items) {
    const result = items.slice()

    for (let i = result.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))
        const temp = result[i]
        result[i] = result[j]
        result[j] = temp
    }

    return result
}

function startHand() {
    const deck = shuffle(createDeck())

    return {
        playerHand: deck.splice(0, 5),
        computerHand: deck.splice(0, 5),
        remainingDeck: deck
    }
}

function exchangeCards(hand, selectedIndices, deck) {
    if (selectedIndices.length > deck.length)
        throw new Error("Not enough cards left in the deck")

    const newHand = hand.slice()
    const newDeck = deck.slice()
    const visited = []

    for (const index of selectedIndices) {
        if (!Number.isInteger(index) || index < 0 || index >= hand.length ||
                visited.indexOf(index) !== -1) {
            throw new Error("Invalid card index: " + index)
        }

        visited.push(index)
        newHand[index] = newDeck.pop()
    }

    return { hand: newHand, remainingDeck: newDeck }
}

function randomExchangeIndices() {
    const count = Math.floor(Math.random() * 6)
    return shuffle([0, 1, 2, 3, 4]).slice(0, count)
}
