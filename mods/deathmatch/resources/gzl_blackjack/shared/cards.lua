Cards = {}

Cards.Suits = {
    { code = "H", name = "Kupa", symbol = "♥", isRed = true },
    { code = "D", name = "Karo", symbol = "♦", isRed = true },
    { code = "C", name = "Sinek", symbol = "♣", isRed = false },
    { code = "S", name = "Maça", symbol = "♠", isRed = false }
}

Cards.Ranks = {
    { code = "A",  value = 11, isAce = true,  name = "As" },
    { code = "2",  value = 2,  isAce = false, name = "2" },
    { code = "3",  value = 3,  isAce = false, name = "3" },
    { code = "4",  value = 4,  isAce = false, name = "4" },
    { code = "5",  value = 5,  isAce = false, name = "5" },
    { code = "6",  value = 6,  isAce = false, name = "6" },
    { code = "7",  value = 7,  isAce = false, name = "7" },
    { code = "8",  value = 8,  isAce = false, name = "8" },
    { code = "9",  value = 9,  isAce = false, name = "9" },
    { code = "10", value = 10, isAce = false, name = "10" },
    { code = "J",  value = 10, isAce = false, name = "Vale" },
    { code = "Q",  value = 10, isAce = false, name = "Kız" },
    { code = "K",  value = 10, isAce = false, name = "Papaz" }
}

function Cards.createSingleDeck()
    local deck = {}
    for _, suit in ipairs(Cards.Suits) do
        for _, rank in ipairs(Cards.Ranks) do
            table.insert(deck, {
                suit = suit.code,
                rank = rank.code,
                value = rank.value,
                isAce = rank.isAce,
                name = rank.name .. " of " .. suit.name,
                fileName = "card_" .. suit.code .. "_" .. rank.code .. ".png"
            })
        end
    end
    return deck
end

function Cards.createShoe(decksCount)
    decksCount = decksCount or Config.DefaultShoeDecks or 6
    local shoe = {}
    for i = 1, decksCount do
        local single = Cards.createSingleDeck()
        for _, card in ipairs(single) do
            table.insert(shoe, {
                suit = card.suit,
                rank = card.rank,
                value = card.value,
                isAce = card.isAce,
                name = card.name,
                fileName = card.fileName
            })
        end
    end
    Cards.shuffle(shoe)
    return shoe
end

function Cards.shuffle(deck)
    local n = #deck
    for i = n, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

function Cards.calculateScore(hand, isFromSplit)
    if not hand or #hand == 0 then
        return 0, false, false, false
    end

    local total = 0
    local aces = 0

    for _, card in ipairs(hand) do
        if card.isAce then
            aces = aces + 1
            total = total + 11
        else
            total = total + card.value
        end
    end

    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end

    local isSoft = (aces > 0)
    local isBust = (total > 21)

    local isBlackjack = (#hand == 2 and total == 21 and not isFromSplit)

    return total, isSoft, isBlackjack, isBust
end

function Cards.compareResults(playerScore, playerBJ, playerBust, dealerScore, dealerBJ, dealerBust)
    if playerBust then
        return "bust"
    end

    if playerBJ and dealerBJ then
        return "push"
    elseif playerBJ then
        return "blackjack"
    elseif dealerBJ then
        return "lose"
    end

    if dealerBust then
        return "dealer_bust"
    end

    if playerScore > dealerScore then
        return "win"
    elseif playerScore < dealerScore then
        return "lose"
    else
        return "push"
    end
end

function Cards.getCardString(card)
    if not card then return "?" end
    local symbol = "?"
    for _, s in ipairs(Cards.Suits) do
        if s.code == card.suit then
            symbol = s.symbol
            break
        end
    end
    return card.rank .. symbol
end