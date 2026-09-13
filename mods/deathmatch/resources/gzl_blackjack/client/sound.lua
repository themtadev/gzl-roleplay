SoundManager = {}

local activeVoiceSound = nil
local activeSubtitle = nil
local activeSubtitleTimer = nil

local voiceSubtitles = {
    dealer_greet = "Hoş geldiniz, bol şanslar!",
    dealer_place_bets = "Lütfen bahislerinizi belirleyin.",
    dealer_closed_bets = "Bahisler kapandı, kartlar dağıtılıyor.",
    dealer_blackjack = "Blackjack! Mükemmel el.",
    dealer_player_bust = "Oyuncu yandı!",
    dealer_busts = "Kurpiyer 21'i aştı, oyuncular kazanıyor!",
    dealer_wins = "Kasa kazandı.",
    dealer_another_card = "Başka bir kart çeker misiniz?",
    dealer_16 = "Kurpiyer on altıda.",
    dealer_17 = "On yedi, kurpiyer durur.",
    dealer_18 = "Kurpiyer on sekizde.",
    dealer_19 = "Kurpiyer on dokuzda.",
    dealer_20 = "Kurpiyer yirmide.",
    dealer_21 = "Yirmi bir!"
}

addEvent("blackjack:onPlaySound", true)
addEventHandler("blackjack:onPlaySound", resourceRoot, function(soundName, isVoice, pos3D)
    SoundManager.play(soundName, isVoice, pos3D)
end)

function SoundManager.play(soundName, isVoice, pos3D)
    local path = "assets/sounds/" .. soundName .. ".wav"
    if not fileExists(path) then
        path = "assets/sounds/" .. soundName .. ".mp3"
        if not fileExists(path) then return end
    end

    if isVoice then
        if isElement(activeVoiceSound) then
            stopSound(activeVoiceSound)
            activeVoiceSound = nil
        end

        if voiceSubtitles[soundName] then
            activeSubtitle = voiceSubtitles[soundName]
            if isTimer(activeSubtitleTimer) then killTimer(activeSubtitleTimer) end
            activeSubtitleTimer = setTimer(function()
                activeSubtitle = nil
            end, 3800, 1)
        end
    end

    local snd = nil
    if pos3D and type(pos3D) == "table" and pos3D.x then
        snd = playSound3D(path, pos3D.x, pos3D.y, pos3D.z, false)
        if snd then
            setSoundMaxDistance(snd, isVoice and 18.0 or 12.0)
            setSoundVolume(snd, isVoice and 1.0 or 0.8)
        end
    else
        snd = playSound(path, false)
        if snd then
            setSoundVolume(snd, isVoice and 1.0 or 0.8)
        end
    end

    if isVoice then
        activeVoiceSound = snd
    end
end

function SoundManager.getActiveSubtitle()
    return activeSubtitle
end