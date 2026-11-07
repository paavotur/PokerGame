// Four-player engine (stage 1): state and dealing only.
// This file is independent from the existing two-player GameEngine.js.

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
    if (!Number.isInteger(playerCount) || playerCount < 2 || playerCount > 4 ||
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
        winnerIds: [],
        lastPot: 0
    }
}

function clockwiseOrder(players) {
    return [0, 2, 1, 3].filter(
        id => id < players.length
    )
}

function nextActivePlayer(players, previousIndex) {
    return nextSeat(
        players,
        previousIndex,
        p => p.inHand
    )
}


function startHand(game) {
    if (game.phase !== "ready" && game.phase !== "finished")
        throw new Error("Previous hand is not finished")

    const next = JSON.parse(JSON.stringify(game))
    const eligible = next.players.filter(p => p.chips >= next.ante)

    if (eligible.length < 2) {
        next.phase = "finished"
        next.turnIndex = -1
        return next
    }

    next.handNumber += 1
    next.pot = 0
    next.currentBet = 0
    next.lastRaise = next.minBet
    next.winnerIds = []
    next.lastPot = 0
    next.deck = shuffleDeck(createDeck())

    // Initialize players and collect antes.
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

    // Rotate dealer clockwise.
    next.dealerIndex = nextActivePlayer(
        next.players, next.dealerIndex
    )

    // Deal five cards to each player clockwise.
    const order = clockwiseOrder(next.players)
    const dealerPosition = order.indexOf(next.dealerIndex)

    for (let cardNumber = 0; cardNumber < 5; cardNumber++) {
        for (let offset = 1; offset <= order.length; offset++) {
            const index =
                order[(dealerPosition + offset) % order.length]

            if (next.players[index].inHand)
                next.players[index].hand.push(next.deck.pop())
        }
    }

    beginBettingRound(next, "betting1")
    return next
}


// Stage 2: turn-based no-limit betting, draws and side-pot settlement.
// Amounts for bet/raise mean total chips committed on the CURRENT betting round.
function cloneGame(game) {
    return JSON.parse(JSON.stringify(game))
}

function isContender(p) {
    return p.inHand && !p.folded
}

function canAct(p) {
    return isContender(p) && !p.allIn && p.chips > 0
}

function nextSeat(players, after, predicate) {
    const order = clockwiseOrder(players)
    const position = order.indexOf(after)

    for (let step = 1; step <= order.length; step++) {
        const index =
            order[(position + step) % order.length]

        if (predicate(players[index]))
            return index
    }

    return -1
}


function contenders(game) {
    return game.players.filter(isContender)
}

// Caps a bet at the largest amount that at least one opponent can match.
function maxBetTo(game, playerId) {
    const p = game.players[playerId]
    const opponents = game.players.filter(other =>
        other.id !== playerId && canAct(other))

    if (opponents.length === 0)
        return p.roundBet

    const largestOpponentTotal = Math.max(...opponents.map(other =>
        other.roundBet + other.chips))

    return Math.min(p.roundBet + p.chips, largestOpponentTotal)
}

function minBetTo(game) {
    if (game.currentBet === 0)
        return game.minBet

    if (game.currentBet < game.minBet)
        return game.minBet // Complete a short all-in opening bet.

    return game.currentBet + game.lastRaise
}

function needsAction(game, p) {
    return canAct(p) &&
           (!p.acted || p.roundBet < game.currentBet)
}

function canIncreaseBet(game, p) {
    return !p.acted && maxBetTo(game, p.id) > game.currentBet
}

function availableActions(game) {
    if ((game.phase !== "betting1" && game.phase !== "betting2") ||
        game.turnIndex < 0)
        return []

    const p = game.players[game.turnIndex]
    if (!needsAction(game, p))
        return []

    const owed = game.currentBet - p.roundBet
    if (owed > 0) {
        const actions = ["fold", "call"]
        if (canIncreaseBet(game, p))
            actions.push("raise")
        return actions
    }

    const actions = ["check"]
    if (canIncreaseBet(game, p))
        actions.push(game.currentBet === 0 ? "bet" : "raise")
    return actions
}

function refundUncalled(game) {
    const sorted = game.players.slice().sort(
        (a, b) => b.totalCommitted - a.totalCommitted)

    if (sorted.length < 2 ||
        sorted[0].totalCommitted <= sorted[1].totalCommitted)
        return

    const excess = sorted[0].totalCommitted - sorted[1].totalCommitted
    const p = game.players[sorted[0].id]

    // Only unmatched chips from the current round may be refunded.
    if (excess > p.roundBet)
        throw new Error("Unmatched contribution outside current round")

    p.chips += excess
    p.totalCommitted -= excess
    p.roundBet -= excess
    p.allIn = p.chips === 0
    game.pot -= excess
}

function finishBettingRound(game) {
    refundUncalled(game)
    game.turnIndex = -1

    if (game.phase === "betting1") {
        game.phase = "draw"

        // First player clockwise from the dealer.
        game.turnIndex = nextSeat(
            game.players,
            game.dealerIndex,
            p => isContender(p) && !p.drawn
        )
    } else {
        game.phase = "showdown"
    }
}

function beginBettingRound(game, phase) {
    game.phase = phase
    game.currentBet = 0
    game.lastRaise = game.minBet

    for (const p of game.players) {
        p.roundBet = 0
        p.acted = false
    }

    // When at most one player can still bet, no further bets are possible.
    const actors = game.players.filter(canAct)
    if (actors.length < 2) {
        finishBettingRound(game)
        return
    }

    game.turnIndex = nextSeat(game.players, game.dealerIndex, canAct)
}

function awardUncontested(game) {
    const winner = contenders(game)[0]
    if (!winner)
        throw new Error("No active player to award pot")

    game.lastPot = game.pot
    winner.chips += game.pot
    game.winnerIds = [winner.id]
    game.pot = 0
    game.turnIndex = -1
    game.phase = "finished"
}

function advanceBetting(game, previousIndex) {
    if (contenders(game).length === 1) {
        awardUncontested(game)
        return
    }

    // If only one non-all-in player remains, they may owe a call but
    // cannot make additional bets without somebody able to match them.
    const actors = game.players.filter(canAct)
    if (actors.length === 0 ||
        (actors.length === 1 &&
         actors[0].roundBet >= game.currentBet)) {
        finishBettingRound(game)
        return
    }

    const nextIndex = nextSeat(game.players, previousIndex,
        p => needsAction(game, p))

    if (nextIndex < 0)
        finishBettingRound(game)
    else
        game.turnIndex = nextIndex
}

function applyBettingAction(game, action, amount = 0) {
    const s = cloneGame(game)
    const actions = availableActions(s)
    if (!actions.includes(action))
        throw new Error("Action not allowed: " + action)

    const index = s.turnIndex
    const p = s.players[index]
    const owed = Math.max(0, s.currentBet - p.roundBet)

    if (action === "fold") {
        p.folded = true
        p.acted = true
    } else if (action === "check") {
        p.acted = true
    } else if (action === "call") {
        const paid = Math.min(owed, p.chips)
        p.chips -= paid
        p.roundBet += paid
        p.totalCommitted += paid
        s.pot += paid
        p.allIn = p.chips === 0
        p.acted = true
    } else {
        const maximum = maxBetTo(s, index)
        const minimum = minBetTo(s)
        const valid = Number.isSafeInteger(amount) &&
            amount > s.currentBet && amount > p.roundBet &&
            amount <= maximum &&
            (amount >= minimum || amount === maximum)

        if (!valid)
            throw new Error("Invalid bet/raise: total must be " +
                Math.min(minimum, maximum) + "–" + maximum)

        const previousBet = s.currentBet
        const extra = amount - p.roundBet
        const increase = amount - previousBet

        p.chips -= extra
        p.roundBet = amount
        p.totalCommitted += extra
        p.allIn = p.chips === 0
        p.acted = true
        s.pot += extra
        s.currentBet = amount

        // Only a full bet or raise reopens betting to players already acted.
        const fullRaise = previousBet < s.minBet
            ? amount >= s.minBet
            : increase >= s.lastRaise

        if (fullRaise) {
            s.lastRaise = previousBet === 0
                ? amount
                : previousBet < s.minBet ? s.minBet : increase
            for (const other of s.players) {
                if (other.id !== index && canAct(other))
                    other.acted = false
            }
        }
    }

    advanceBetting(s, index)
    return s
}

function drawCards(game, playerId, discardIndices) {
    const s = cloneGame(game)
    if (s.phase !== "draw")
        throw new Error("Not in draw phase")

    const p = s.players[playerId]
    if (s.turnIndex !== playerId ||
        !p || !isContender(p) || p.drawn)
        throw new Error("Not this player's draw turn")

    if (!Array.isArray(discardIndices) ||
        discardIndices.length > 5 ||
        !discardIndices.every(i => Number.isInteger(i) && i >= 0 && i < 5) ||
        new Set(discardIndices).size !== discardIndices.length ||
        s.deck.length < discardIndices.length)
        throw new Error("Invalid discard selection")

    for (const index of discardIndices)
        p.hand[index] = s.deck.pop()

    p.drawn = true

    s.turnIndex = nextSeat(
        s.players,
        playerId,
        other => isContender(other) && !other.drawn
    )

    return s
}

function completeDraw(game) {
    const s = cloneGame(game)

    if (s.phase !== "draw" ||
        s.turnIndex !== -1 ||
        s.players.some(p => isContender(p) && !p.drawn)) {
        throw new Error("Not every active player has drawn")
    }

    beginBettingRound(s, "betting2")
    return s
}

// Returns side pots from all committed chips, including folded players' chips.
function buildSidePots(game) {
    const thresholds = [...new Set(game.players
        .map(p => p.totalCommitted)
        .filter(amount => amount > 0))].sort((a, b) => a - b)

    const pots = []
    let lower = 0
    for (const upper of thresholds) {
        const contributors = game.players.filter(
            p => p.totalCommitted >= upper)
        const amount = (upper - lower) * contributors.length
        const eligibleIds = contributors
            .filter(isContender)
            .map(p => p.id)

        if (amount > 0) {
            if (eligibleIds.length === 0)
                throw new Error("Side pot without eligible players")
            pots.push({ amount, eligibleIds })
        }
        lower = upper
    }

    if (pots.reduce((total, p) => total + p.amount, 0) !== game.pot)
        throw new Error("Side-pot totals do not equal main pot")

    return pots
}

// compareHands(leftHand, rightHand) must return >0, <0 or 0.
function settleShowdown(game, compareHands) {
    const s = cloneGame(game)
    if (s.phase !== "showdown" || typeof compareHands !== "function")
        throw new Error("Not ready for showdown")

    const pots = buildSidePots(s)
    const winners = new Set()
    s.lastPot = s.pot

    for (const pot of pots) {
        let winningIds = []
        for (let i = 0; i < pot.eligibleIds.length; i++) {
            const playerId = pot.eligibleIds[i]
            if (winningIds.length === 0) {
                winningIds = [playerId]
                continue
            }
            const comparison = compareHands(
                s.players[playerId].hand,
                s.players[winningIds[0]].hand)
            if (comparison > 0)
                winningIds = [playerId]
            else if (comparison === 0)
                winningIds.push(playerId)
        }

        // Odd chips go to the first winning seat left of the dealer.
        const order = clockwiseOrder(s.players)
        const dealerPosition = order.indexOf(s.dealerIndex)

        const distance = id =>
            (order.indexOf(id) - dealerPosition +
             order.length - 1) % order.length

        winningIds.sort((a, b) =>
            distance(a) - distance(b)
        )

        if (winningIds.length === 0)
            throw new Error("Side pot has no eligible winners")

        const share = Math.floor(pot.amount / winningIds.length)
        let remainder = pot.amount % winningIds.length
        for (const id of winningIds) {
            s.players[id].chips += share + (remainder > 0 ? 1 : 0)
            if (remainder > 0)
                remainder--
            winners.add(id)
        }
    }

    s.pot = 0
    s.turnIndex = -1
    s.phase = "finished"
    s.winnerIds = [...winners].sort((a, b) => a - b)
    return s
}
