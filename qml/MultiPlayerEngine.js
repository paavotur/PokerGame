
/*
 * Multiplayer poker engine
 * Stage 1: player state and card dealing
 */

function createDeck() {
    const suits = ["♠", "♥", "♦", "♣"]
    const deck = []

    for (const suit of suits) {
        for (let rank = 2; rank <= 14; rank++)
            deck.push({ rank: rank, suit: suit })
    }

    return deck
}

function shuffleDeck(deck) {
    const result = deck.slice()

    for (let i = result.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1))

        const temp = result[i]
        result[i] = result[j]
        result[j] = temp
    }

    return result
}

function createGame(playerCount = 4, startingChips = 1000,
                    ante = 20, minBet = 50) {

    if (!Number.isInteger(playerCount) ||
        playerCount < 2 || playerCount > 4 ||
        ![startingChips, ante, minBet].every(Number.isInteger) ||
        startingChips <= 0 || ante <= 0 || minBet <= 0 ||
        ante > startingChips) {
        throw new Error("Invalid game settings")
    }

    const players = []

    for (let id = 0; id < playerCount; id++) {
        players.push({
            id: id,
            human: id === 0,
            chips: startingChips,
            hand: [],
            inHand: false,
            folded: false,
            allIn: false,
            roundBet: 0,
            totalCommitted: 0,
            acted: false,
            drawn: false
        })
    }

    return {
        phase: "ready",
        players: players,
        ante: ante,
        minBet: minBet,
        pot: 0,
        deck: [],
        handNumber: 0,
        dealerIndex: -1,
        turnIndex: -1,
        currentBet: 0,
        lastRaise: minBet,
        winnerIds: []
    }
}

function nextActivePlayer(players, previousIndex) {
    for (let step = 1; step <= players.length; step++) {
        const index = (previousIndex + step) % players.length

        if (players[index].inHand)
            return index
    }

    return -1
}

function startHand(game) {
    if (game.phase !== "ready" && game.phase !== "finished")
        throw new Error("Previous hand is not finished")

    const next = JSON.parse(JSON.stringify(game))

    const eligible = next.players.filter(
        player => player.chips >= next.ante
    )

    if (eligible.length < 2) {
        next.phase = "finished"
        next.turnIndex = -1
        return next
    }

    next.handNumber++
    next.pot = 0
    next.currentBet = 0
    next.lastRaise = next.minBet
    next.winnerIds = []
    next.deck = shuffleDeck(createDeck())

    for (const player of next.players) {
        player.hand = []
        player.inHand = player.chips >= next.ante
        player.folded = false
        player.roundBet = 0
        player.totalCommitted = 0
        player.acted = false
        player.drawn = false
        player.allIn = false

        if (!player.inHand)
            continue

        player.chips -= next.ante
        player.totalCommitted = next.ante
        player.allIn = player.chips === 0
        next.pot += next.ante
    }

    // Rotate dealer position
    next.dealerIndex = nextActivePlayer(
        next.players, next.dealerIndex
    )

    // Deal five cards to each active player
    for (let cardNumber = 0; cardNumber < 5; cardNumber++) {
        for (let offset = 1;
             offset <= next.players.length;
             offset++) {

            const index =
                (next.dealerIndex + offset) % next.players.length

            if (next.players[index].inHand)
                next.players[index].hand.push(next.deck.pop())
        }
    }

    next.turnIndex = nextActivePlayer(
        next.players, next.dealerIndex
    )

    next.phase = "betting1"
    return next
}
