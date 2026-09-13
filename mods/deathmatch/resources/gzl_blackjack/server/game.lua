Game = {}
Game.Tables = {}

local STATE_WAITING = "WAITING_FOR_PLAYERS"
local STATE_BETTING = "BETTING"
local STATE_DEALING = "DEALING"
local STATE_INSURANCE = "INSURANCE"
local STATE_PLAYER_TURNS = "PLAYER_TURNS"
local STATE_DEALER_TURN = "DEALER_TURN"
local STATE_PAYOUT = "PAYOUT"
local STATE_ROUND_OVER = "ROUND_OVER"

function Game.drawCard(t)
    if not t or not t.shoe then return nil end
    if #t.shoe == 0 then
        t.shoe = Cards.createShoe(Config.DefaultShoeDecks)
        Game.playTableSound(t.config.id, "shuffle", false)
    end
    return table.remove(t.shoe, 1)
end

function Game.initTable(tableConfig)
    local tId = tableConfig.id
    Game.Tables[tId] = {
        config = tableConfig,
        state = STATE_WAITING,
        shoe = Cards.createShoe(Config.DefaultShoeDecks),
        seats = {
            [1] = { player = nil, bet = 0, hands = {}, activeHandIndex = 1, isInsured = false, insuranceBet = 0, status = "empty" },
            [2] = { player = nil, bet = 0, hands = {}, activeHandIndex = 1, isInsured = false, insuranceBet = 0, status = "empty" },
            [3] = { player = nil, bet = 0, hands = {}, activeHandIndex = 1, isInsured = false, insuranceBet = 0, status = "empty" },
            [4] = { player = nil, bet = 0, hands = {}, activeHandIndex = 1, isInsured = false, insuranceBet = 0, status = "empty" },
        },
        dealer = {
            cards = {},
            holeCardHidden = true,
            score = 0,
            isSoft = false,
            isBlackjack = false,
            isBust = false
        },
        currentTurnSeat = 0,
        timer = nil,
        stepTimer = nil,
        timerSecondsRemaining = 0,
        lastRoundResults = {}
    }
end

function Game.syncTable(tableId, targetPlayer)
    local t = Game.Tables[tableId]
    if not t then return end

    local visibleDealerCards = {}
    for i, c in ipairs(t.dealer.cards) do
        if i == 2 and t.dealer.holeCardHidden and (t.state == STATE_DEALING or t.state == STATE_PLAYER_TURNS or t.state == STATE_BETTING or t.state == STATE_INSURANCE) then
            table.insert(visibleDealerCards, { isHidden = true })
        else
            table.insert(visibleDealerCards, c)
        end
    end

    local dScore, dSoft, dBJ, dBust = 0, false, false, false
    if not t.dealer.holeCardHidden or #visibleDealerCards == 1 then
        dScore, dSoft, dBJ, dBust = Cards.calculateScore(visibleDealerCards, false)
    end

    local seatsData = {}
    for seatIndex = 1, 4 do
        local seat = t.seats[seatIndex]
        local pName = nil
        if isElement(seat.player) then
            pName = getPlayerName(seat.player)
        end

        local handsData = {}
        for hIndex, h in ipairs(seat.hands) do
            local sc, sft, bj, bst = Cards.calculateScore(h.cards, h.isFromSplit)
            table.insert(handsData, {
                cards = h.cards,
                score = sc,
                isSoft = sft,
                isBlackjack = bj,
                isBust = bst,
                status = h.status or "playing",
                bet = h.bet or seat.bet,
                isFromSplit = h.isFromSplit or false
            })
        end

        seatsData[seatIndex] = {
            occupied = isElement(seat.player),
            playerName = pName,
            player = seat.player,
            bet = seat.bet,
            hands = handsData,
            activeHandIndex = seat.activeHandIndex,
            isInsured = seat.isInsured,
            insuranceBet = seat.insuranceBet or 0,
            status = seat.status
        }
    end

    local syncPacket = {
        tableId = tableId,
        tableName = t.config.name,
        minBet = t.config.minBet,
        maxBet = t.config.maxBet,
        state = t.state,
        dealer = {
            cards = visibleDealerCards,
            score = dScore,
            isSoft = dSoft,
            isBlackjack = dBJ,
            isBust = dBust,
            holeCardHidden = t.dealer.holeCardHidden,
            dealerName = t.config.dealerName
        },
        seats = seatsData,
        currentTurnSeat = t.currentTurnSeat,
        timerSeconds = t.timerSecondsRemaining,
        lastResults = t.lastRoundResults
    }

    if isElement(targetPlayer) then
        triggerClientEvent(targetPlayer, "blackjack:onTableSync", resourceRoot, syncPacket)
    else

        for seatIndex = 1, 4 do
            local p = t.seats[seatIndex].player
            if isElement(p) then
                triggerClientEvent(p, "blackjack:onTableSync", resourceRoot, syncPacket)
            end
        end
    end
end

function Game.getSeatedCount(tableId)
    local t = Game.Tables[tableId]
    if not t then return 0 end
    local count = 0
    for i = 1, 4 do
        if isElement(t.seats[i].player) then
            count = count + 1
        end
    end
    return count
end

function Game.getBettingCount(tableId)
    local t = Game.Tables[tableId]
    if not t then return 0 end
    local count = 0
    for i = 1, 4 do
        if isElement(t.seats[i].player) and t.seats[i].bet > 0 then
            count = count + 1
        end
    end
    return count
end

local function clearTableTimer(t)
    if isTimer(t.timer) then
        killTimer(t.timer)
    end
    t.timer = nil
    t.timerSecondsRemaining = 0
    if isTimer(t.stepTimer) then
        killTimer(t.stepTimer)
    end
    t.stepTimer = nil
end

function Game.playTableSound(tableId, soundName, isVoice)
    local t = Game.Tables[tableId]
    if not t then return end

    local tblPos = t.config.pos
    local int = t.config.interior or 0
    local dim = t.config.dimension or 0

    local notified = {}
    for i = 1, 4 do
        local p = t.seats[i].player
        if isElement(p) then
            notified[p] = true
            triggerClientEvent(p, "blackjack:onPlaySound", resourceRoot, soundName, isVoice, tblPos)
        end
    end

    for _, p in ipairs(getElementsByType("player")) do
        if not notified[p] and getElementInterior(p) == int and getElementDimension(p) == dim then
            local px, py, pz = getElementPosition(p)
            if getDistanceBetweenPoints3D(px, py, pz, tblPos.x, tblPos.y, tblPos.z) <= 20.0 then
                triggerClientEvent(p, "blackjack:onPlaySound", resourceRoot, soundName, isVoice, tblPos)
            end
        end
    end
end

function Game.startBetting(tableId)
    local t = Game.Tables[tableId]
    if not t then return end

    clearTableTimer(t)
    t.state = STATE_BETTING
    t.dealer.cards = {}
    t.dealer.holeCardHidden = true
    t.dealer.score = 0
    t.currentTurnSeat = 0
    t.lastRoundResults = {}

    for i = 1, 4 do
        t.seats[i].bet = 0
        t.seats[i].hands = {}
        t.seats[i].activeHandIndex = 1
        t.seats[i].isInsured = false
        t.seats[i].insuranceBet = 0
        t.seats[i].insuranceDeclined = false
        if isElement(t.seats[i].player) then
            t.seats[i].status = "betting"
        else
            t.seats[i].status = "empty"
        end
    end

    t.timerSecondsRemaining = Config.BettingDuration
    Game.playTableSound(tableId, "dealer_place_bets", true)
    Game.syncTable(tableId)

    t.timer = setTimer(function()
        if not Game.Tables[tableId] then return end
        local tbl = Game.Tables[tableId]
        tbl.timerSecondsRemaining = tbl.timerSecondsRemaining - 1

        if tbl.timerSecondsRemaining <= 0 then
            clearTableTimer(tbl)

            if Game.getBettingCount(tableId) > 0 then
                Game.startDealing(tableId)
            else

                if Game.getSeatedCount(tableId) > 0 then
                    Game.startBetting(tableId)
                else
                    tbl.state = STATE_WAITING
                    Game.syncTable(tableId)
                end
            end
        else
            Game.syncTable(tableId)
        end
    end, 1000, Config.BettingDuration)
end

function Game.startDealing(tableId)
    local t = Game.Tables[tableId]
    if not t then return end

    clearTableTimer(t)
    t.state = STATE_DEALING
    Game.playTableSound(tableId, "dealer_closed_bets", true)

    if #t.shoe < Config.ReshuffleThreshold then
        t.shoe = Cards.createShoe(Config.DefaultShoeDecks)
        Game.playTableSound(tableId, "shuffle", false)
    end

    local activeSeatIndices = {}
    for i = 1, 4 do
        if isElement(t.seats[i].player) and t.seats[i].bet > 0 then
            table.insert(activeSeatIndices, i)
            t.seats[i].hands = {
                { cards = {}, status = "playing", bet = t.seats[i].bet, isFromSplit = false }
            }
            t.seats[i].activeHandIndex = 1
        end
    end

    Game.syncTable(tableId)

    local dealSteps = {}

    for _, seatIdx in ipairs(activeSeatIndices) do
        table.insert(dealSteps, { target = "player", seat = seatIdx })
    end

    table.insert(dealSteps, { target = "dealer", hidden = false })

    for _, seatIdx in ipairs(activeSeatIndices) do
        table.insert(dealSteps, { target = "player", seat = seatIdx })
    end

    table.insert(dealSteps, { target = "dealer", hidden = true })

    local stepIdx = 1
    local function executeNextDealStep()
        if not Game.Tables[tableId] or Game.Tables[tableId].state ~= STATE_DEALING then return end
        local tbl = Game.Tables[tableId]

        if stepIdx <= #dealSteps then
            local step = dealSteps[stepIdx]
            local card = Game.drawCard(tbl)

            if step.target == "player" then
                table.insert(tbl.seats[step.seat].hands[1].cards, card)
            else
                table.insert(tbl.dealer.cards, card)
                if step.hidden then
                    tbl.dealer.holeCardHidden = true
                end
            end

            Game.playTableSound(tableId, "card_deal", false)
            Game.syncTable(tableId)
            stepIdx = stepIdx + 1

            tbl.stepTimer = setTimer(executeNextDealStep, Config.DealingCardDelay, 1)
        else

            Game.checkInitialDealingFinished(tableId, activeSeatIndices)
        end
    end

    t.stepTimer = setTimer(executeNextDealStep, 500, 1)
end

function Game.checkInitialDealingFinished(tableId, activeSeatIndices)
    local t = Game.Tables[tableId]
    if not t then return end

    for _, seatIdx in ipairs(activeSeatIndices) do
        local seat = t.seats[seatIdx]
        local sc, _, isBJ = Cards.calculateScore(seat.hands[1].cards, false)
        if isBJ then
            seat.hands[1].status = "blackjack"
        end
    end

    local dealerUpCard = t.dealer.cards[1]
    local _, _, dealerHasBJ = Cards.calculateScore(t.dealer.cards, false)

    if dealerUpCard and (dealerUpCard.isAce or dealerUpCard.rank == "A") and Config.Rules.allowInsurance then
        t.state = STATE_INSURANCE
        t.timerSecondsRemaining = Config.InsuranceDuration or 7
        Game.playTableSound(tableId, "dealer_another_card", true)
        Game.syncTable(tableId)

        t.timer = setTimer(function()
            if not Game.Tables[tableId] or Game.Tables[tableId].state ~= STATE_INSURANCE then return end
            local tbl = Game.Tables[tableId]
            tbl.timerSecondsRemaining = tbl.timerSecondsRemaining - 1
            if tbl.timerSecondsRemaining <= 0 then
                clearTableTimer(tbl)
                Game.finishInsurancePhase(tableId)
            else
                Game.syncTable(tableId)
            end
        end, 1000, Config.InsuranceDuration or 7)
        return
    end

    if dealerUpCard and (dealerUpCard.value == 10 or dealerUpCard.isAce) and dealerHasBJ then
        t.dealer.holeCardHidden = false
        t.dealer.score = 21
        t.dealer.isBlackjack = true
        Game.playTableSound(tableId, "dealer_blackjack", true)
        Game.syncTable(tableId)

        t.stepTimer = setTimer(function()
            Game.processPayouts(tableId)
        end, 1500, 1)
        return
    end

    t.state = STATE_PLAYER_TURNS
    Game.advanceToNextTurn(tableId, 0)
end

function Game.finishInsurancePhase(tableId)
    local t = Game.Tables[tableId]
    if not t then return end

    clearTableTimer(t)
    local _, _, dealerHasBJ = Cards.calculateScore(t.dealer.cards, false)
    if dealerHasBJ then

        t.dealer.holeCardHidden = false
        t.dealer.score = 21
        t.dealer.isBlackjack = true
        Game.playTableSound(tableId, "dealer_blackjack", true)
        Game.syncTable(tableId)

        t.stepTimer = setTimer(function()
            Game.processPayouts(tableId)
        end, 1500, 1)
    else

        t.state = STATE_PLAYER_TURNS
        Game.advanceToNextTurn(tableId, 0)
    end
end

function Game.advanceToNextTurn(tableId, fromSeatIndex)
    local t = Game.Tables[tableId]
    if not t then return end

    clearTableTimer(t)

    local targetSeat = nil
    local targetHandIdx = nil

    if fromSeatIndex and fromSeatIndex > 0 then
        local curSeat = t.seats[fromSeatIndex]
        if isElement(curSeat.player) and curSeat.bet > 0 then
            for hIdx = (curSeat.activeHandIndex or 1), #curSeat.hands do
                local h = curSeat.hands[hIdx]
                local sc, _, isBJ, isBust = Cards.calculateScore(h.cards, h.isFromSplit)
                if h.status == "playing" and not isBJ and not isBust and sc < 21 then
                    targetSeat = fromSeatIndex
                    targetHandIdx = hIdx
                    break
                end
            end
        end
    end

    if not targetSeat then
        local startSeat = (fromSeatIndex and fromSeatIndex > 0) and (fromSeatIndex + 1) or 1
        for s = startSeat, 4 do
            local seat = t.seats[s]
            if isElement(seat.player) and seat.bet > 0 then
                for hIdx, h in ipairs(seat.hands) do
                    local sc, _, isBJ, isBust = Cards.calculateScore(h.cards, h.isFromSplit)
                    if h.status == "playing" and not isBJ and not isBust and sc < 21 then
                        targetSeat = s
                        targetHandIdx = hIdx
                        break
                    end
                end
                if targetSeat then break end
            end
        end
    end

    if targetSeat and targetHandIdx then
        t.currentTurnSeat = targetSeat
        t.seats[targetSeat].activeHandIndex = targetHandIdx
        t.timerSecondsRemaining = Config.TurnDuration
        Game.syncTable(tableId)

        t.timer = setTimer(function()
            if not Game.Tables[tableId] then return end
            local tbl = Game.Tables[tableId]
            tbl.timerSecondsRemaining = tbl.timerSecondsRemaining - 1

            if tbl.timerSecondsRemaining <= 0 then
                clearTableTimer(tbl)

                Game.playerAction(tableId, tbl.currentTurnSeat, "stand")
            else
                Game.syncTable(tableId)
            end
        end, 1000, Config.TurnDuration)
    else

        t.currentTurnSeat = 0
        Game.startDealerTurn(tableId)
    end
end

function Game.startDealerTurn(tableId)
    local t = Game.Tables[tableId]
    if not t then return end

    clearTableTimer(t)
    t.state = STATE_DEALER_TURN

    t.dealer.holeCardHidden = false
    local score, isSoft, isBJ, isBust = Cards.calculateScore(t.dealer.cards, false)
    t.dealer.score = score
    t.dealer.isSoft = isSoft
    t.dealer.isBlackjack = isBJ
    t.dealer.isBust = isBust

    Game.playTableSound(tableId, "card_slide", false)
    Game.syncTable(tableId)

    local needsDealerPlay = false
    for i = 1, 4 do
        local seat = t.seats[i]
        if isElement(seat.player) and seat.bet > 0 then
            for _, h in ipairs(seat.hands) do
                local sc, _, bj, bst = Cards.calculateScore(h.cards, h.isFromSplit)
                if h.status ~= "surrendered" and not bst and not bj then
                    needsDealerPlay = true
                    break
                end
            end
            if needsDealerPlay then break end
        end
    end

    if not needsDealerPlay then
        t.stepTimer = setTimer(function()
            Game.processPayouts(tableId)
        end, 1200, 1)
        return
    end

    local function dealerDrawStep()
        if not Game.Tables[tableId] or Game.Tables[tableId].state ~= STATE_DEALER_TURN then return end
        local tbl = Game.Tables[tableId]

        local curScore, curSoft, curBJ, curBust = Cards.calculateScore(tbl.dealer.cards, false)
        tbl.dealer.score = curScore
        tbl.dealer.isSoft = curSoft
        tbl.dealer.isBlackjack = curBJ
        tbl.dealer.isBust = curBust

        local mustHit = (curScore < 17) or (curScore == 17 and curSoft and not Config.Rules.dealerStandOnSoft17)

        if mustHit then
            local card = Game.drawCard(tbl)
            table.insert(tbl.dealer.cards, card)
            Game.playTableSound(tableId, "card_deal", false)
            Game.syncTable(tableId)

            tbl.stepTimer = setTimer(dealerDrawStep, 1000, 1)
        else

            if curBust then
                Game.playTableSound(tableId, "dealer_busts", true)
            elseif curScore >= 17 and curScore <= 21 then
                local voice = "dealer_" .. tostring(curScore)
                Game.playTableSound(tableId, voice, true)
            end

            tbl.stepTimer = setTimer(function()
                Game.processPayouts(tableId)
            end, 1200, 1)
        end
    end

    t.stepTimer = setTimer(dealerDrawStep, 1000, 1)
end

function Game.processPayouts(tableId)
    local t = Game.Tables[tableId]
    if not t then return end

    t.state = STATE_PAYOUT
    local dScore, _, dBJ, dBust = Cards.calculateScore(t.dealer.cards, false)
    local results = {}
    local anyWin = false

    for seatIdx = 1, 4 do
        local seat = t.seats[seatIdx]
        if isElement(seat.player) and seat.bet > 0 then
            results[seatIdx] = {
                playerName = getPlayerName(seat.player),
                hands = {},
                insurancePayout = 0
            }

            if seat.isInsured and seat.insuranceBet and seat.insuranceBet > 0 then
                if dBJ then

                    local insPayout = math.floor(seat.insuranceBet * (Config.Rules.insurancePayout + 1))
                    Transactions.giveMoney(seat.player, insPayout, "Blackjack Sigorta Kazancı")
                    results[seatIdx].insurancePayout = insPayout
                    anyWin = true
                else
                    results[seatIdx].insurancePayout = -seat.insuranceBet
                end
            end

            for hIdx, h in ipairs(seat.hands) do
                local handBet = h.bet or seat.bet
                local payout = 0
                local outcome = "lose"
                local pScore, _, pBJ, pBust = Cards.calculateScore(h.cards, h.isFromSplit)

                if h.status == "surrendered" then
                    outcome = "surrendered"
                    payout = 0
                else
                    outcome = Cards.compareResults(pScore, pBJ, pBust, dScore, dBJ, dBust)
                    if outcome == "blackjack" then
                        payout = math.floor(handBet + (handBet * Config.Rules.blackjackPayout))
                        Transactions.giveMoney(seat.player, payout, "Blackjack Doğal Kazancı")
                        anyWin = true
                    elseif outcome == "win" or outcome == "dealer_bust" then
                        payout = handBet * 2
                        Transactions.giveMoney(seat.player, payout, "Blackjack Galibiyeti")
                        anyWin = true
                    elseif outcome == "push" then
                        payout = handBet
                        Transactions.giveMoney(seat.player, payout, "Blackjack Berabere İade")
                    else
                        payout = 0
                    end
                end

                table.insert(results[seatIdx].hands, {
                    outcome = outcome,
                    payout = payout,
                    score = pScore,
                    bet = handBet
                })
            end
        end
    end

    t.lastRoundResults = results
    Game.syncTable(tableId)

    if anyWin then
        Game.playTableSound(tableId, "win", false)
    else
        Game.playTableSound(tableId, "dealer_wins", true)
    end

    t.stepTimer = setTimer(function()
        Game.endRound(tableId)
    end, Config.ResultDuration * 1000, 1)
end

function Game.endRound(tableId)
    local t = Game.Tables[tableId]
    if not t then return end

    t.state = STATE_ROUND_OVER
    Game.syncTable(tableId)

    if Game.getSeatedCount(tableId) > 0 then
        t.stepTimer = setTimer(function()
            Game.startBetting(tableId)
        end, 1500, 1)
    else
        t.state = STATE_WAITING
        Game.syncTable(tableId)
    end
end

function Game.placeBet(player, tableId, seatIndex, amount)
    local t = Game.Tables[tableId]
    if not t then return false, "Masa bulunamadı." end
    if t.state ~= STATE_BETTING then return false, "Şu anda bahisler kapalı." end

    local seat = t.seats[seatIndex]
    if not seat or seat.player ~= player then
        return false, "Bu koltukta oturmuyorsunuz."
    end

    amount = tonumber(amount)
    if not amount or amount < t.config.minBet or amount > t.config.maxBet then
        return false, string.format("Geçersiz bahis tutarı ($%d - $%d arası olmalı).", t.config.minBet, t.config.maxBet)
    end
    amount = math.floor(amount)

    local diff = amount - seat.bet
    if diff > 0 then
        if not Transactions.takeMoney(player, diff, "Blackjack Bahsi") then
            return false, "Yetersiz bakiye."
        end
    elseif diff < 0 then
        Transactions.giveMoney(player, math.abs(diff), "Blackjack Bahis İndirimi")
    end

    seat.bet = amount
    seat.status = "bet_placed"
    Game.playTableSound(tableId, "chip_place", false)
    Game.syncTable(tableId)

    local seated = Game.getSeatedCount(tableId)
    local placed = Game.getBettingCount(tableId)
    if seated > 0 and seated == placed then
        clearTableTimer(t)
        Game.startDealing(tableId)
    end

    return true
end

function Game.playerAction(tableId, seatIndex, action)
    local t = Game.Tables[tableId]
    if not t then return false end

    local seat = t.seats[seatIndex]
    if not seat or not isElement(seat.player) then return false end

    if action == "insurance" then
        if t.state ~= STATE_INSURANCE then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Sigorta süresi doldu veya şu an sigorta teklif edilmiyor.", "error")
            return false
        end
        if not Config.Rules.allowInsurance then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Sigorta bu masada kapalı.", "error")
            return false
        end
        local dealerUpCard = t.dealer.cards[1]
        if not dealerUpCard or (not dealerUpCard.isAce and dealerUpCard.rank ~= "A") then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Kurpiyer As açmadığı için sigorta yapılamaz.", "error")
            return false
        end
        if seat.isInsured then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Zaten sigorta yaptırdınız.", "error")
            return false
        end

        local insAmount = math.floor(seat.bet / 2)
        if insAmount <= 0 then return false end

        if not Transactions.takeMoney(seat.player, insAmount, "Blackjack Sigorta Bahsi") then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Sigorta için yetersiz bakiye!", "error")
            return false
        end

        seat.isInsured = true
        seat.insuranceBet = insAmount
        Game.playTableSound(tableId, "chip_place", false)
        Game.syncTable(tableId)
        triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, string.format("Sigorta alındı ($%d).", insAmount), "success")

        local allDecided = true
        for i = 1, 4 do
            local s = t.seats[i]
            if isElement(s.player) and s.bet > 0 and not s.isInsured and not s.insuranceDeclined then
                allDecided = false
                break
            end
        end
        if allDecided then
            Game.finishInsurancePhase(tableId)
        end
        return true

    elseif action == "pass_insurance" then
        if t.state ~= STATE_INSURANCE then return false end
        seat.insuranceDeclined = true
        Game.syncTable(tableId)

        local allDecided = true
        for i = 1, 4 do
            local s = t.seats[i]
            if isElement(s.player) and s.bet > 0 and not s.isInsured and not s.insuranceDeclined then
                allDecided = false
                break
            end
        end
        if allDecided then
            Game.finishInsurancePhase(tableId)
        end
        return true
    end

    if t.state ~= STATE_PLAYER_TURNS then return false end
    if t.currentTurnSeat ~= seatIndex then return false end

    local activeHand = seat.hands[seat.activeHandIndex]
    if not activeHand or activeHand.status ~= "playing" then return false end

    if action == "hit" then
        local card = Game.drawCard(t)
        table.insert(activeHand.cards, card)
        Game.playTableSound(tableId, "card_deal", false)

        local newScore, _, _, newBust = Cards.calculateScore(activeHand.cards, activeHand.isFromSplit)
        if newBust then
            activeHand.status = "bust"
            Game.playTableSound(tableId, "dealer_player_bust", true)
            Game.syncTable(tableId)
            Game.advanceToNextTurn(tableId, seatIndex)
        elseif newScore == 21 then
            activeHand.status = "standing"
            Game.syncTable(tableId)
            Game.advanceToNextTurn(tableId, seatIndex)
        else

            Game.syncTable(tableId)
        end

    elseif action == "stand" then
        activeHand.status = "standing"
        Game.syncTable(tableId)
        Game.advanceToNextTurn(tableId, seatIndex)

    elseif action == "double" then
        if not Config.Rules.allowDoubleDown then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "İkiye katlama kuralı kapalı.", "error")
            return false
        end
        if #activeHand.cards ~= 2 then return false end
        local handBet = activeHand.bet or seat.bet
        if not Transactions.takeMoney(seat.player, handBet, "Blackjack İkiye Katlama") then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "İkiye katlamak için yetersiz bakiye!", "error")
            return false
        end

        activeHand.bet = handBet * 2
        seat.bet = seat.bet + handBet

        local card = Game.drawCard(t)
        table.insert(activeHand.cards, card)
        Game.playTableSound(tableId, "chip_place", false)
        Game.playTableSound(tableId, "card_deal", false)

        local newScore, _, _, newBust = Cards.calculateScore(activeHand.cards, activeHand.isFromSplit)
        if newBust then
            activeHand.status = "bust"
            Game.playTableSound(tableId, "dealer_player_bust", true)
        else
            activeHand.status = "standing"
        end

        Game.syncTable(tableId)
        Game.advanceToNextTurn(tableId, seatIndex)

    elseif action == "split" then
        if not Config.Rules.allowSplit then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Kart bölme kuralı kapalı.", "error")
            return false
        end
        if #activeHand.cards ~= 2 then return false end
        if #seat.hands >= Config.Rules.maxSplitHands then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Maksimum bölme sınırına ulaşıldı.", "error")
            return false
        end

        local c1 = activeHand.cards[1]
        local c2 = activeHand.cards[2]
        if c1.value ~= c2.value and c1.rank ~= c2.rank then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Yalnızca aynı değere sahip kartlar bölünebilir.", "error")
            return false
        end

        local handBet = activeHand.bet or seat.bet
        if not Transactions.takeMoney(seat.player, handBet, "Blackjack El Bölme") then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Bölmek için yetersiz bakiye!", "error")
            return false
        end

        local hand2 = {
            cards = { c2 },
            status = "playing",
            bet = handBet,
            isFromSplit = true
        }
        activeHand.cards = { c1 }
        activeHand.isFromSplit = true

        table.insert(activeHand.cards, Game.drawCard(t))
        table.insert(hand2.cards, Game.drawCard(t))
        table.insert(seat.hands, hand2)

        seat.bet = seat.bet + handBet
        Game.playTableSound(tableId, "chip_place", false)
        Game.playTableSound(tableId, "card_deal", false)

        local sc2 = Cards.calculateScore(hand2.cards, true)
        if sc2 == 21 then
            hand2.status = "standing"
        end

        local sc1 = Cards.calculateScore(activeHand.cards, true)
        if sc1 == 21 then
            activeHand.status = "standing"
            Game.syncTable(tableId)
            Game.advanceToNextTurn(tableId, seatIndex)
        else
            Game.syncTable(tableId)
        end

    elseif action == "surrender" then
        if not Config.Rules.allowSurrender then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Teslim olma kuralı kapalı.", "error")
            return false
        end
        if #activeHand.cards ~= 2 then return false end
        if activeHand.isFromSplit then
            triggerClientEvent(seat.player, "blackjack:notify", resourceRoot, "Bölünmüş ellerde teslim olunamaz.", "error")
            return false
        end

        local handBet = activeHand.bet or seat.bet
        local refund = math.floor(handBet / 2)
        Transactions.giveMoney(seat.player, refund, "Blackjack Teslim İadesi")

        activeHand.status = "surrendered"
        Game.syncTable(tableId)
        Game.advanceToNextTurn(tableId, seatIndex)
    end

    return true
end

function Game.playerJoinTable(player, tableId, seatIndex)
    local t = Game.Tables[tableId]
    if not t then return false, "Masa bulunamadı." end

    seatIndex = tonumber(seatIndex)
    if not seatIndex or seatIndex < 1 or seatIndex > 4 then
        return false, "Geçersiz koltuk."
    end

    local seat = t.seats[seatIndex]
    if isElement(seat.player) then
        return false, "Bu koltuk dolu."
    end

    for otherTId, otherT in pairs(Game.Tables) do
        for otherS = 1, 4 do
            if otherT.seats[otherS].player == player then
                return false, "Zaten bir masada oturuyorsunuz."
            end
        end
    end

    seat.player = player
    seat.bet = 0
    seat.hands = {}
    seat.isInsured = false
    seat.insuranceBet = 0
    seat.status = (t.state == STATE_BETTING) and "betting" or "waiting"

    setElementData(player, "blackjack:tableId", tableId)
    setElementData(player, "blackjack:seatIndex", seatIndex)

    local rotZ = t.config.rot or 0
    local rad = math.rad(rotZ)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local sOff = Config.SeatOffsets[seatIndex]
    local wx = t.config.pos.x + (sOff.x * cosA - sOff.y * sinA)
    local wy = t.config.pos.y + (sOff.x * sinA + sOff.y * cosA)
    local wz = t.config.pos.z + sOff.z
    local seatRot = (rotZ + sOff.rot) % 360

    setElementPosition(player, wx, wy, wz)
    setElementRotation(player, 0, 0, seatRot)
    setElementInterior(player, t.config.interior or 0)
    setElementDimension(player, t.config.dimension or 0)
    setElementFrozen(player, true)
    setElementCollisionsEnabled(player, false)

    setPedAnimation(player, "PED", "SEAT_idle", -1, true, false, false, false)
    setTimer(function()
        if isElement(player) and getElementData(player, "blackjack:tableId") == tableId then
            setPedAnimation(player, "PED", "SEAT_idle", -1, true, false, false, false)
        end
    end, 100, 1)

    Game.playTableSound(tableId, "dealer_greet", true)
    Game.syncTable(tableId)

    if t.state == STATE_WAITING then
        Game.startBetting(tableId)
    end

    return true
end

function Game.playerLeaveTable(player)
    local tableId = getElementData(player, "blackjack:tableId")
    local seatIndex = getElementData(player, "blackjack:seatIndex")
    if not tableId or not seatIndex then return false end

    local t = Game.Tables[tableId]
    if not t then return false end

    local seat = t.seats[seatIndex]
    if seat and seat.player == player then

        if (t.state == STATE_BETTING or t.state == STATE_INSURANCE) and seat.bet > 0 then
            Transactions.giveMoney(player, seat.bet, "Blackjack Masadan Ayrılma İadesi")
        end
        if (t.state == STATE_BETTING or t.state == STATE_INSURANCE) and seat.isInsured and seat.insuranceBet > 0 then
            Transactions.giveMoney(player, seat.insuranceBet, "Blackjack Sigorta Ayrılma İadesi")
        end

        seat.player = nil
        seat.bet = 0
        seat.hands = {}
        seat.isInsured = false
        seat.insuranceBet = 0
        seat.insuranceDeclined = false
        seat.status = "empty"

        removeElementData(player, "blackjack:tableId")
        removeElementData(player, "blackjack:seatIndex")

        if isElement(player) then
            detachElements(player)
            setElementCollisionsEnabled(player, true)
            setElementFrozen(player, false)
            setPedAnimation(player, false)
            local px, py, pz = getElementPosition(player)
            local _, _, pRot = getElementRotation(player)
            local pRad = math.rad(pRot)
            local exitX = px + math.sin(pRad) * 0.8
            local exitY = py - math.cos(pRad) * 0.8
            local exitZ = (t and t.config and t.config.pos and t.config.pos.z) and (t.config.pos.z + 0.05) or pz
            setElementPosition(player, exitX, exitY, exitZ)
        end

        if Game.getSeatedCount(tableId) == 0 then
            clearTableTimer(t)
            t.state = STATE_WAITING
            t.dealer.cards = {}
            t.currentTurnSeat = 0
            Game.syncTable(tableId)
        elseif t.currentTurnSeat == seatIndex then
            Game.advanceToNextTurn(tableId, seatIndex)
        else
            Game.syncTable(tableId)
        end
        return true
    end

    return false
end

function Game.cleanup()
    for tableId, t in pairs(Game.Tables) do
        clearTableTimer(t)
        for sIdx = 1, 4 do
            local seat = t.seats[sIdx]
            if isElement(seat.player) then
                if (t.state == STATE_BETTING or t.state == STATE_INSURANCE) and seat.bet > 0 then
                    Transactions.giveMoney(seat.player, seat.bet, "Blackjack Kapanış İadesi")
                end
                if (t.state == STATE_BETTING or t.state == STATE_INSURANCE) and seat.isInsured and seat.insuranceBet > 0 then
                    Transactions.giveMoney(seat.player, seat.insuranceBet, "Blackjack Sigorta Kapanış İadesi")
                end
                detachElements(seat.player)
                setElementCollisionsEnabled(seat.player, true)
                setElementFrozen(seat.player, false)
                setPedAnimation(seat.player, false)
                removeElementData(seat.player, "blackjack:tableId")
                removeElementData(seat.player, "blackjack:seatIndex")
            end
        end
    end
    Game.Tables = {}
end