(() => {
    const nativeFetch = window.fetch.bind(window)
    const pending = new Map()
    const callId = "mta-phone-call"
    let sequence = 0
    let active = false
    let bootstrap = {}
    let lastCameraImage = ""
    const localPhotoKey = "cylex_phone:mtaPhotos"
    const froglyPostsKey = "cylex_phone:froglyPosts"
    const getFroglyPosts = () => {
        try {
            const data = JSON.parse(localStorage.getItem(froglyPostsKey) || "[]")
            if (Array.isArray(data)) return data
        } catch {}
        return []
    }
    const saveFroglyPosts = posts => {
        try {
            localStorage.setItem(froglyPostsKey, JSON.stringify(posts))
        } catch {}
    }
    const mediaOwner = () => String(bootstrap.identifier || bootstrap.phoneNumber || "")
    let mediaRevision = 0

    window.__mtaPhoneSaveCapture = async (blob, details) => {
        const owner = mediaOwner()
        if (!owner) throw new Error("Telefon verileri henüz hazır değil")
        const photo = await window.__mtaPhoneMedia.save(owner, blob, details)
        if (owner === mediaOwner()) {
            bootstrap.photos = [photo, ...(Array.isArray(bootstrap.photos) ? bootstrap.photos : [])]
            syncBootstrapState()
        }
        return photo
    }

    window.GetParentResourceName = () => "cylex_phone"

    const decoder = new TextDecoder("utf-8")
    window.__mtaPhoneDecode = value => JSON.parse(decoder.decode(Uint8Array.from(atob(value), character => character.charCodeAt(0))))
    let readySent = false
    window.__mtaPhoneNotifyReady = () => {
        if (readySent || !window.$store || !document.querySelector("#app .phone-container")) return
        if (!window.mta || typeof window.mta.triggerEvent !== "function") return
        readySent = true
        window.mta.triggerEvent("cylex_phone:browserReady")
    }

    const parse = value => {
        if (typeof value !== "string") return value
        try {
            return JSON.parse(value)
        } catch {
            return value
        }
    }

    const response = value => {
        const payload = value === undefined ? true : value
        return {
            ok: true,
            status: 200,
            statusText: "OK",
            json: async () => payload,
            text: async () => typeof payload === "string" ? payload : JSON.stringify(payload),
            blob: async () => new Blob([typeof payload === "string" ? payload : JSON.stringify(payload)])
        }
    }

    const post = payload => window.postMessage(payload, "*")
    const storeState = () => window.$store && window.$store.state
    const cleanNumber = value => String(value == null ? "" : value).replace(/\s+/g, "")
    const splitName = value => {
        const parts = String(value || "").replace(/_/g, " ").trim().split(/\s+/)
        return { firstname: parts.shift() || "Bilinmeyen", lastname: parts.join(" ") }
    }

    const contactList = rows => (Array.isArray(rows) ? rows : []).map(row => {
        const names = splitName(row.name)
        return {
            id: row.id,
            identifier: row.identifier || row.number,
            firstname: row.firstname || names.firstname,
            lastname: row.lastname == null ? names.lastname : row.lastname,
            phoneNumber: cleanNumber(row.phoneNumber || row.number),
            picture: row.picture || row.photo || row.avatar || "",
            avatar: row.avatar || row.photo || row.picture || "",
            tag: row.tag || row.notes || "",
            favorite: Boolean(row.favorite)
        }
    })

    const contactName = number => {
        const target = cleanNumber(number)
        const found = contactList(bootstrap.contacts).find(item => cleanNumber(item.phoneNumber) === target)
        return found ? `${found.firstname} ${found.lastname}`.trim() : target
    }

    const messageItem = row => {
        let attachment = row.attachments
        if (typeof attachment === "string" && attachment) attachment = parse(attachment)
        const item = {
            id: row.id || `${row.time || Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
            message: row.message || row.text || "",
            text: row.text || row.message || "",
            sender: cleanNumber(row.sender || row.from_number || row.from),
            receiver: cleanNumber(row.receiver || row.to_number || row.to),
            time: Number(row.time || row.timestamp || Date.now() / 1000),
            isRead: Boolean(row.is_read || row.isRead),
            deleted: Boolean(row.deleted)
        }
        if (attachment && typeof attachment === "object") Object.assign(item, attachment)
        return item
    }

    const conversations = () => {
        const output = {}
        const own = cleanNumber(bootstrap.phoneNumber)
        const grouped = bootstrap.messages && typeof bootstrap.messages === "object" ? bootstrap.messages : {}
        Object.keys(grouped).forEach(key => {
            const target = cleanNumber(key)
            const messages = (Array.isArray(grouped[key]) ? grouped[key] : []).map(messageItem)
            output[target] = {
                id: target,
                type: "single",
                name: contactName(target),
                target,
                phoneNumber: target,
                picture: "",
                list: {
                    [own]: { phoneNumber: own },
                    [target]: { phoneNumber: target }
                },
                messages,
                lastMessage: messages[messages.length - 1] || null,
                unread: messages.filter(item => item.receiver === own && !item.isRead).length
            }
        })
        ;(Array.isArray(bootstrap.chats) ? bootstrap.chats : []).forEach(chat => {
            const target = cleanNumber(chat.number || chat.targetNumber)
            if (!target) return
            if (!output[target]) {
                output[target] = {
                    id: target,
                    type: "single",
                    name: chat.name || contactName(target),
                    target,
                    phoneNumber: target,
                    picture: chat.photo || "",
                    list: {
                        [own]: { phoneNumber: own },
                        [target]: { phoneNumber: target }
                    },
                    messages: [],
                    lastMessage: chat.last_message ? { message: chat.last_message, time: chat.last_time } : null,
                    unread: Number(chat.unread || 0)
                }
            }
        })
        return output
    }

    const callList = rows => (Array.isArray(rows) ? rows : []).map(row => ({
        id: row.id || row.timestamp || row.time,
        phoneNumber: cleanNumber(row.phoneNumber || row.number),
        number: cleanNumber(row.phoneNumber || row.number),
        duration: Number(row.duration || 0) > 0 ? Number(row.duration) * 1000 : null,
        state: row.type === "missed" ? 1 : row.type === "incoming" ? 0 : 2,
        time: Number(row.timestamp || row.time || Date.now() / 1000) * (Number(row.timestamp || row.time || 0) < 100000000000 ? 1000 : 1),
        isPrivate: Boolean(row.isPrivate),
        name: row.name || contactName(row.number)
    }))

    const photoList = rows => (Array.isArray(rows) ? rows : []).map(row => typeof row === "string" ? {
        id: row,
        url: row,
        src: row,
        type: "image",
        date: Date.now()
    } : {
        ...row,
        url: row.url || row.src || row.photo,
        src: row.src || row.url || row.photo,
        type: row.type || "image"
    })

    const transactionList = rows => (Array.isArray(rows) ? rows : []).map(row => ({
        ...row,
        amount: Number(row.amount || 0),
        date: row.date || new Date(Number(row.time || Date.now() / 1000) * 1000).toISOString()
    }))

    const noteList = rows => (Array.isArray(rows) ? rows : []).map(row => ({
        ...row,
        title: row.title || "Not",
        text: row.text == null ? row.content || "" : row.text
    }))

    const syncBootstrapState = () => {
        const state = storeState()
        if (!state) return
        state.data.contacts = contactList(bootstrap.contacts)
        state.data.recentCalls = callList(bootstrap.callHistory || bootstrap.calls)
        state.data.bank = Number(bootstrap.bankBalance || 0)
        state.appdata.gallery.photos = photoList(bootstrap.photos)
        state.appdata.bank.transactions = transactionList(bootstrap.transactions)
        state.appdata.notes.notes = noteList(bootstrap.notes)
        state.self_userdata.notes = noteList(bootstrap.notes)
        state.appdata.messages.messages = conversations()
        state.appdata.twitter.tweets = Array.isArray(bootstrap.tweets) ? bootstrap.tweets : []
        if (state.appdata && state.appdata.frogly) {
            state.appdata.frogly.posts = getFroglyPosts()
        }
    }

    const firstLoginPayload = () => {
        const names = splitName(bootstrap.playerName || "GZL Oyuncu")
        const cleanName = (bootstrap.playerName || "oyuncu").replace(/[^a-zA-Z0-9_]/g, "").toLowerCase() || "oyuncu"
        const settings = bootstrap.settings || {}
        const wallpaper = settings.wallpaper && String(settings.wallpaper).startsWith("images/") ? settings.wallpaper : "images/background/b1.png"
        const selectedAccounts = settings.selectedAccounts || {
            twitter: { tag: cleanName, password: "gzl", logged: true },
            instagram: { tag: cleanName, password: "gzl", logged: true },
            hacker: { tag: cleanName, password: "gzl", logged: false },
            frogly: { tag: cleanName, password: "gzl", logged: true },
            swiper: { tag: cleanName, password: "gzl", logged: false },
            foffy: { tag: cleanName, password: "gzl", logged: false }
        }
        if (!selectedAccounts.frogly || !selectedAccounts.frogly.tag) {
            selectedAccounts.frogly = { tag: cleanName, password: "gzl", logged: true }
        }
        if (!selectedAccounts.twitter || !selectedAccounts.twitter.tag) {
            selectedAccounts.twitter = { tag: cleanName, password: "gzl", logged: true }
        }
        if (!selectedAccounts.instagram || !selectedAccounts.instagram.tag) {
            selectedAccounts.instagram = { tag: cleanName, password: "gzl", logged: true }
        }
        return {
            version: "9123845690325481243",
            can_see_object: false,
            upload_data: {
                Type: "fivemanage",
                BlacklistedUrls: [],
                LogWebhook: "",
                image: { token: "mta" },
                video: { token: "mta" },
                audio: { token: "mta" }
            },
            self_userdata: {
                firstname: names.firstname,
                lastname: names.lastname,
                phoneNumber: cleanNumber(bootstrap.phoneNumber || "555-0000"),
                iban: bootstrap.iban || "GZL-0000",
                picture: bootstrap.picture || "",
                online: true,
                setup: true,
                silentMode: Boolean(settings.silentMode),
                airplane: Boolean(settings.airplane),
                faceid: settings.faceid !== false,
                bluetooth: Boolean(settings.bluetooth),
                notification: settings.notification || "default",
                ringtone_sound: settings.ringtone || "default",
                blocked_numbers: settings.blocked_numbers || {},
                selectedAccounts,
                recentAccounts: settings.recentAccounts || {},
                pendingNotifications: [],
                selectedLockBackground: wallpaper,
                selectedHomeBackground: wallpaper,
                notes: noteList(bootstrap.notes)
            },
            data: {
                bank: Number(bootstrap.bankBalance || 0),
                identifier: String(bootstrap.identifier || bootstrap.phoneNumber || ""),
                in_game_time: bootstrap.inGameTime || "00:00",
                hasVpn: Boolean(bootstrap.hasVpn),
                inCamera: false,
                minimizedCallNotification: false,
                isTalking: false,
                sound: settings.sound !== false,
                notification: settings.notification !== false,
                faceid: settings.faceid !== false,
                focus: Boolean(settings.focus),
                wifi: settings.wifi !== false,
                ethernet: false,
                flashlight: false,
                brightness: Number(settings.brightness || 100),
                volume: Number(settings.volume == null ? 50 : settings.volume),
                scale: 1,
                contacts: contactList(bootstrap.contacts),
                recentCalls: callList(bootstrap.callHistory || bootstrap.calls),
                jobs: bootstrap.jobs || { allJobs: [], groups: [], playerJob: "" },
                AppAccounts: {
                    frogly: {
                        [cleanName]: {
                            tag: cleanName,
                            nickname: bootstrap.playerName || "Oyuncu",
                            picture: bootstrap.picture || "images/icons/default-user.png",
                            verified: false
                        }
                    },
                    twitter: {
                        [cleanName]: {
                            tag: cleanName,
                            nickname: bootstrap.playerName || "Oyuncu",
                            picture: bootstrap.picture || "images/icons/default-user.png",
                            verified: false
                        }
                    },
                    instagram: {
                        [cleanName]: {
                            tag: cleanName,
                            nickname: bootstrap.playerName || "Oyuncu",
                            picture: bootstrap.picture || "images/icons/default-user.png",
                            verified: false
                        }
                    }
                }
            },
            appdata: {
                gallery: { photos: photoList(bootstrap.photos), photo_albums: [] },
                bank: { transactions: transactionList(bootstrap.transactions) },
                notes: { notes: noteList(bootstrap.notes) },
                frogly: {
                    posts: getFroglyPosts(),
                    explorePosts: [],
                    messages: {}
                }
            }
        }
    }

    const applyBootstrap = value => {
        bootstrap = parse(value) || {}
        const savedPhotos = parse(localStorage.getItem(localPhotoKey))
        if (Array.isArray(savedPhotos) && savedPhotos.length) {
            const remotePhotos = Array.isArray(bootstrap.photos) ? bootstrap.photos : []
            const known = new Set(remotePhotos.map(photo => String(photo.id || photo.url || photo.src || photo.photo)))
            bootstrap.photos = [...savedPhotos.filter(photo => !known.has(String(photo.id || photo.url || photo.src || photo.photo))), ...remotePhotos]
        }
        post({ action: "first_login", value: firstLoginPayload() })
        setTimeout(syncBootstrapState, 0)
        const revision = ++mediaRevision
        window.__mtaPhoneMedia.list(mediaOwner()).then(photos => {
            if (revision !== mediaRevision) return
            const remote = Array.isArray(bootstrap.photos) ? bootstrap.photos.filter(photo => !photo.local) : []
            bootstrap.photos = [...photos, ...remote]
            syncBootstrapState()
        }).catch(error => console.error("[cylex_phone] Galeri:", error))
    }

    const saveLocalPhotos = () => {
        const photos = (Array.isArray(bootstrap.photos) ? bootstrap.photos : []).filter(photo => String(photo.url || photo.src || photo.photo || "").startsWith("data:image/")).slice(0, 8)
        try {
            localStorage.setItem(localPhotoKey, JSON.stringify(photos))
        } catch {
            if (photos.length > 1) localStorage.setItem(localPhotoKey, JSON.stringify(photos.slice(0, Math.ceil(photos.length / 2))))
        }
    }

    const selectedMessageId = data => cleanNumber(data.selectedMessageId || data.messageId || data.number || data.targetNumber || data.target)

    const drawCameraPreview = imageUrl => {
        const draw = () => {
            const canvas = document.getElementById("tempCanvasCamera")
            if (!canvas) return
            const image = new Image()
            image.onload = () => {
                const width = canvas.clientWidth || 390
                const height = canvas.clientHeight || 844
                canvas.width = width
                canvas.height = height
                const context = canvas.getContext("2d", { alpha: false })
                const scale = Math.max(width / image.width, height / image.height)
                const drawWidth = image.width * scale
                const drawHeight = image.height * scale
                context.drawImage(image, (width - drawWidth) / 2, (height - drawHeight) / 2, drawWidth, drawHeight)
            }
            image.src = imageUrl
        }
        requestAnimationFrame(draw)
        setTimeout(draw, 150)
    }

    const showCall = (number, callstate, type, title) => {
        const value = {
            id: callId,
            title: title || contactName(number),
            text: callstate === "talking" ? "0:00" : callstate === "incoming" ? "Gelen arama" : "Aranıyor",
            timeout: -1,
            type: type || "dynamic-phonecall",
            icon: { name: "app-icon/call.png" },
            _data: {
                number: cleanNumber(number),
                callstate,
                startedAt: Math.floor(Date.now() / 1000),
                isPrivate: false
            }
        }
        post({ action: "delete-notification", id: callId })
        post({ action: "notification", value })
    }

    const normalize = (endpoint, value, requestData) => {
        const result = parse(value)
        if (endpoint.startsWith("camera:") && result && result.success) window.dispatchEvent(new CustomEvent("mta-camera-state", { detail: { endpoint, data: requestData, result } }))
        if (endpoint === "callapp:getContacts") return contactList(result)
        if (endpoint === "messages:getConversations") return conversations()
        if (endpoint === "messages:getSpecificMessage") {
            const id = selectedMessageId(requestData)
            const item = conversations()[id]
            return { found: Boolean(item), messageId: id, messageData: item || null }
        }
        if (endpoint === "messages:fetchChatMessages") return { success: true, hasMore: false, messages: (conversations()[selectedMessageId(requestData)] || {}).messages || [] }
        if (endpoint === "bank:refreshBank") return { bank: Number(bootstrap.bankBalance || 0), balance: Number(bootstrap.bankBalance || 0), transactions: transactionList(bootstrap.transactions) }
        if (endpoint === "yellowPage:fetchPosts" || endpoint === "yellowPage:fetchMore") return Array.isArray(result) ? result : []
        if (endpoint === "twitter:fetchTimeline" || endpoint === "twitter:fetchMore") return Array.isArray(result) ? result : []
        if (endpoint === "darkchat:fetchConversations" || endpoint === "darkchat:getConversations") return result && typeof result === "object" ? result : {}
        if (endpoint === "camera:enter" || endpoint === "camera:takePhoto") {
            if (typeof result === "string" && result.startsWith("data:image/")) {
                lastCameraImage = result
                return result
            }
        }
        if (endpoint === "startPhoneCall" && result && result.status) {
            if (result.status === "calling") showCall(requestData.number, "calling", "dynamic-started")
            return result
        }
        if ((endpoint === "notes:saveText" || endpoint === "notes:removeNote") && result && Array.isArray(result.notes)) {
            bootstrap.notes = result.notes
            setTimeout(syncBootstrapState, 0)
        }
        if (endpoint === "gallery:sendPhoto" && result && result.photo) {
            bootstrap.photos = bootstrap.photos || []
            bootstrap.photos.unshift(result.photo)
            setTimeout(syncBootstrapState, 0)
        }
        return result
    }

    const fallback = (endpoint, data = {}) => {
        const state = storeState()
        if (endpoint === "notifications:getPending") return { notifications: [] }
        if (endpoint === "callapp:getContacts") return state ? state.data.contacts : []
        if (endpoint === "messages:getConversations") return conversations()
        if (endpoint === "messages:getSpecificMessage") {
            const id = selectedMessageId(data)
            const item = conversations()[id]
            return { found: Boolean(item), messageId: id, messageData: item || null }
        }
        if (endpoint === "messages:fetchChatMessages") return { success: true, hasMore: false, messages: [] }
        if (endpoint === "bank:refreshBank") return { bank: Number(bootstrap.bankBalance || 0), balance: Number(bootstrap.bankBalance || 0), transactions: transactionList(bootstrap.transactions) }
        if (endpoint === "swiper:getSelfProfile") return {}
        if (/messages:getConversations$/i.test(endpoint)) return {}
        if (/messages:(fetchChatMessages|getSpecificMessage)$/i.test(endpoint)) return { success: true, found: false, hasMore: false, messages: [] }
        if (/(:get|:fetch|:search|:refresh|:closest|:profile:)/i.test(endpoint)) return []
        return { success: true }
    }

    window.__mtaPhoneImagePart = (id, chunk, complete) => {
        const entry = pending.get(String(id))
        if (!entry) return
        if (typeof chunk !== "string" || chunk.length > 48000) {
            window.__mtaPhoneResolve(id, false, "camera_transfer_invalid")
            return
        }
        entry.imageParts = entry.imageParts || []
        entry.imageSize = (entry.imageSize || 0) + chunk.length
        if (entry.imageSize > 16 * 1024 * 1024) {
            window.__mtaPhoneResolve(id, false, "camera_transfer_too_large")
            return
        }
        entry.imageParts.push(chunk)
        if (complete) window.__mtaPhoneResolve(id, entry.imageParts.join(""))
    }

    window.__mtaPhoneResolve = (id, value, failed) => {
        const entry = pending.get(String(id))
        if (!entry) return
        clearTimeout(entry.timeout)
        pending.delete(String(id))
        if (failed) {
            entry.resolve(response({ success: false, error: String(failed) }))
            return
        }
        entry.resolve(response(normalize(entry.endpoint, value, entry.data)))
    }

    window.__mtaPhoneReceive = value => {
        const payload = parse(value)
        if (payload && typeof payload === "object") post(payload)
    }

    window.__mtaPhoneBootstrap = applyBootstrap

    window.__mtaPhoneIncomingCall = value => {
        const data = parse(value) || {}
        showCall(data.number || data.callerNumber, "incoming", "dynamic-phonecall", data.callerName)
    }

    window.__mtaPhoneCallState = (state, number) => {
        if (state === "ended") {
            post({ action: "delete-notification", id: callId })
            return
        }
        post({
            action: "update-notification",
            id: callId,
            params: {
                text: state === "active" ? "0:00" : state,
                _data: {
                    number: cleanNumber(number || ""),
                    callstate: state === "active" ? "talking" : state,
                    startedAt: Math.floor(Date.now() / 1000),
                    isPrivate: false
                }
            }
        })
    }

    document.addEventListener("click", event => {
        if (!event.target.closest(".phone-lockscreen-bottom")) return
        setTimeout(() => {
            const state = storeState()
            if (!state || state.selectedApp !== "lockscreen") return
            if (window.$store && typeof window.$store.dispatch === "function") window.$store.dispatch("onClickApp", "home")
            else state.selectedApp = "home"
        }, 650)
    }, true)

    const localFrames = new Map([
        ["html-classic.itch.zone", "games/index.html?game=tower"],
        ["funhtml5games.com", "games/index.html?game=number"],
        ["duowfriends.eu", "games/index.html?game=uno"],
        ["gemioli.com/hooligans", "games/index.html?game=skate"],
        ["gemioli.com/relicrunway", "games/index.html?game=temple"]
    ])
    const localFrameSource = source => {
        const value = String(source || "")
        for (const [remote, local] of localFrames) if (value.includes(remote)) return local
        return value
    }
    const nativeFrameSetAttribute = HTMLIFrameElement.prototype.setAttribute
    const frameSourceDescriptor = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, "src")
    HTMLIFrameElement.prototype.setAttribute = function(name, value) {
        return nativeFrameSetAttribute.call(this, name, String(name).toLowerCase() === "src" ? localFrameSource(value) : value)
    }
    if (frameSourceDescriptor && frameSourceDescriptor.get && frameSourceDescriptor.set) Object.defineProperty(HTMLIFrameElement.prototype, "src", {
        configurable: frameSourceDescriptor.configurable,
        enumerable: frameSourceDescriptor.enumerable,
        get: frameSourceDescriptor.get,
        set(value) {
            frameSourceDescriptor.set.call(this, localFrameSource(value))
        }
    })
    const localizeFrame = frame => {
        if (!(frame instanceof HTMLIFrameElement)) return
        const source = frame.getAttribute("src") || ""
        const local = localFrameSource(source)
        if (local !== source) frame.setAttribute("src", local)
    }
    new MutationObserver(records => records.forEach(record => {
        if (record.type === "attributes") localizeFrame(record.target)
        record.addedNodes.forEach(node => {
            localizeFrame(node)
            if (node.querySelectorAll) node.querySelectorAll("iframe").forEach(localizeFrame)
        })
    })).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ["src"] })

    window.__mtaPhoneEvent = (kind, value) => {
        const data = parse(value) || {}
        const state = storeState()
        if (kind === "message") {
            const own = cleanNumber(bootstrap.phoneNumber)
            const sender = cleanNumber(data.sender || data.from_number || data.from)
            const receiver = cleanNumber(data.receiver || data.to_number || data.to)
            const target = sender === own ? receiver : sender
            bootstrap.messages = bootstrap.messages || {}
            bootstrap.messages[target] = bootstrap.messages[target] || []
            const exists = bootstrap.messages[target].some(item => data.id && item.id === data.id || item.time === data.time && item.message === data.message && cleanNumber(item.from_number || item.from) === sender)
            if (!exists) bootstrap.messages[target].push(data)
            if (state) state.appdata.messages.messages = conversations()
            if (!exists && sender !== own) {
                post({
                    action: "notification",
                    value: {
                        id: `message-${data.id || data.time || Date.now()}`,
                        title: data.from_name || contactName(sender),
                        text: data.message || data.text || "Yeni mesaj",
                        timeout: 5,
                        type: "notification",
                        icon: { name: "app-icon/messages.svg" },
                        _data: { type: "new-message-income", messageId: sender, app: "messages", sender }
                    }
                })
            }
            return
        }
        if (kind === "calls") {
            bootstrap.calls = Array.isArray(data) ? data : []
            bootstrap.callHistory = bootstrap.calls
            if (state) state.data.recentCalls = callList(bootstrap.calls)
            return
        }
        if (kind === "transaction") {
            bootstrap.transactions = bootstrap.transactions || []
            bootstrap.transactions.unshift(data)
            if (state) {
                state.appdata.bank.transactions = transactionList(bootstrap.transactions)
                if (data.balance != null) state.data.bank = Number(data.balance)
            }
            return
        }
        if (kind === "tweet") {
            bootstrap.tweets = bootstrap.tweets || []
            bootstrap.tweets.unshift(data)
            if (state) state.appdata.twitter.tweets = bootstrap.tweets.slice()
            return
        }
        if (kind === "tweet-likes") {
            const tweet = (bootstrap.tweets || []).find(item => String(item.id) === String(data.id))
            if (tweet) tweet.likes = data.likes || []
            if (state) state.appdata.twitter.tweets = (bootstrap.tweets || []).slice()
            return
        }
        if (kind === "dark-message") {
            bootstrap.darkMessages = bootstrap.darkMessages || []
            bootstrap.darkMessages.push(data)
            return
        }
        if (kind === "notification") {
            post({ action: "notification", value: data })
            return
        }
        if (kind === "photo") {
            const photos = bootstrap.photos || []
            const photo = photos.find(item => String(item.id) === String(data.id))
            if (photo) {
                photo.src = data.url
                photo.url = data.url
            }
            if (state) state.appdata.gallery.photos = photoList(photos)
        }
    }

    window.__mtaPhoneSetActive = state => {
        active = Boolean(state)
        window.dispatchEvent(new CustomEvent("mta-phone-active", { detail: active }))
        document.documentElement.dataset.phoneActive = active ? "true" : "false"
        document.querySelectorAll("video,audio").forEach(media => {
            if (!active && !media.paused) {
                media.dataset.mtaResume = "true"
                media.pause()
            } else if (active && media.dataset.mtaResume === "true") {
                delete media.dataset.mtaResume
                media.play().catch(() => {})
            }
        })
    }

    window.fetch = (input, options = {}) => {
        const url = typeof input === "string" ? input : input && input.url || ""
        if (url.startsWith("data:") || url.startsWith("blob:") || url.startsWith("http://mta/")) return nativeFetch(input, options)
        if (url.startsWith("https://fmapi.net/api/v2/")) return Promise.resolve(response({ status: "ok", data: { url: lastCameraImage } }))
        const prefix = "https://cylex_phone/"
        if (!url.startsWith(prefix)) return nativeFetch(input, options)
        const endpoint = decodeURIComponent(url.slice(prefix.length))
        let data = {}
        try {
            data = options.body ? JSON.parse(options.body) : {}
        } catch {
            data = {}
        }
        if (data && typeof data.data === "object" && data.data !== null) data = data.data
        if (endpoint === "frogly:sendPost") {
            const charTag = ((bootstrap.playerName || "oyuncu").replace(/[^a-zA-Z0-9_]/g, "").toLowerCase()) || "oyuncu"
            const posts = getFroglyPosts()
            const post = {
                id: Date.now(),
                tag: charTag,
                text: data.text || "",
                images: Array.isArray(data.images) ? data.images : (data.images ? [data.images] : []),
                price: Number(data.price || 0),
                time: Math.floor(Date.now() / 1000),
                likes: [],
                comments: [],
                purchased: []
            }
            posts.unshift(post)
            saveFroglyPosts(posts)
            const state = storeState()
            if (state && state.appdata && state.appdata.frogly) {
                state.appdata.frogly.posts = posts
            }
            return Promise.resolve(response({ success: true, post }))
        }
        if (endpoint === "frogly:fetchTimeline" || endpoint === "frogly:fetchExplorePosts" || endpoint === "frogly:getPosts") {
            const posts = getFroglyPosts()
            return Promise.resolve(response({ success: true, posts, hasMore: false }))
        }
        if (endpoint === "frogly:sendPostComment") {
            const charTag = ((bootstrap.playerName || "oyuncu").replace(/[^a-zA-Z0-9_]/g, "").toLowerCase()) || "oyuncu"
            const posts = getFroglyPosts()
            const target = posts.find(p => String(p.id) === String(data.id))
            if (target) {
                target.comments = target.comments || []
                target.comments.push({
                    id: Date.now(),
                    tag: charTag,
                    text: data.text || "",
                    time: Math.floor(Date.now() / 1000),
                    likes: []
                })
                saveFroglyPosts(posts)
                const state = storeState()
                if (state && state.appdata && state.appdata.frogly) {
                    state.appdata.frogly.posts = posts
                }
            }
            return Promise.resolve(response({ success: true }))
        }
        if (endpoint === "frogly:likePost") {
            const charTag = ((bootstrap.playerName || "oyuncu").replace(/[^a-zA-Z0-9_]/g, "").toLowerCase()) || "oyuncu"
            const posts = getFroglyPosts()
            const target = posts.find(p => String(p.id) === String(data.id))
            if (target) {
                target.likes = target.likes || []
                const idx = target.likes.indexOf(charTag)
                if (idx === -1) target.likes.push(charTag)
                else target.likes.splice(idx, 1)
                saveFroglyPosts(posts)
                const state = storeState()
                if (state && state.appdata && state.appdata.frogly) {
                    state.appdata.frogly.posts = posts
                }
            }
            return Promise.resolve(response({ success: true }))
        }
        if (endpoint === "app:createAccount" || endpoint === "app:loginAccount") {
            const app = data.app || "frogly"
            const tag = (data.tag || "").toLowerCase()
            const state = storeState()
            if (state) {
                if (state.self_userdata && state.self_userdata.selectedAccounts) {
                    state.self_userdata.selectedAccounts[app] = {
                        tag,
                        password: data.password || "",
                        logged: true
                    }
                }
                if (state.data && state.data.AppAccounts) {
                    state.data.AppAccounts[app] = state.data.AppAccounts[app] || {}
                    state.data.AppAccounts[app][tag] = {
                        tag,
                        nickname: data.nickname || data.tag,
                        picture: bootstrap.picture || "images/icons/default-user.png",
                        verified: false
                    }
                }
            }
            return Promise.resolve(response({ success: true }))
        }
        if (endpoint === "gallery:removePhotos" || endpoint === "gallery:removeBrokenImages") {
            const ids = Array.isArray(data.ids) ? data.ids : [data.id]
            const localIds = ids.filter(id => String(id).startsWith("mta-capture-"))
            if (localIds.length) return window.__mtaPhoneMedia.remove(mediaOwner(), localIds).then(() => {
                bootstrap.photos = (bootstrap.photos || []).filter(photo => !localIds.includes(photo.id))
                syncBootstrapState()
                const remaining = ids.filter(id => !localIds.includes(id))
                return remaining.length ? window.fetch(input, { ...options, body: JSON.stringify({ ids: remaining }) }) : response({ success: true })
            }).catch(error => response({ success: false, error: error.message }))
        }
        if (endpoint === "gallery:toggleFavorite" && String(data.id).startsWith("mta-capture-")) {
            return window.__mtaPhoneMedia.favorite(mediaOwner(), data.id).then(photo => {
                if (photo) bootstrap.photos = (bootstrap.photos || []).map(item => item.id === photo.id ? photo : item)
                syncBootstrapState()
                return response({ success: Boolean(photo) })
            }).catch(error => response({ success: false, error: error.message }))
        }
        if (endpoint === "gallery:sendPhoto") {
            const source = data.url || data.src || data.photo || lastCameraImage
            if (String(source).startsWith("data:image/")) {
                const photo = { ...data, id: data.id || `mta-${Date.now()}`, url: source, src: source, photo: source, type: "image", date: data.date || Date.now() }
                bootstrap.photos = Array.isArray(bootstrap.photos) ? bootstrap.photos : []
                bootstrap.photos.unshift(photo)
                saveLocalPhotos()
                setTimeout(syncBootstrapState, 0)
                return Promise.resolve(response({ success: true, photo }))
            }
        }
        if (!window.mta || typeof window.mta.triggerEvent !== "function") return Promise.resolve(response(fallback(endpoint, data)))
        return new Promise(resolve => {
            const id = String(++sequence)
            const timeout = setTimeout(() => {
                pending.delete(id)
                resolve(response(fallback(endpoint, data)))
            }, 10000)
            pending.set(id, { resolve, timeout, endpoint, data })
            window.mta.triggerEvent("cylex_phone:browserRequest", id, endpoint, JSON.stringify(data))
        })
    }

    if (typeof window.invokeNative !== "function") {
        window.invokeNative = (_, value) => {
            if (window.mta && typeof window.mta.triggerEvent === "function") window.mta.triggerEvent("cylex_phone:openExternal", String(value || ""))
        }
    }

    let typingState = false
    const isEditable = el => {
        if (!el || el.disabled || el.readOnly) return false
        if (el.isContentEditable) return true
        const tag = (el.tagName || "").toUpperCase()
        if (tag === "TEXTAREA" || tag === "IFRAME") return true
        if (tag === "INPUT") {
            const type = (el.type || "text").toLowerCase()
            return !["button", "checkbox", "radio", "range", "submit", "reset", "file", "color", "image"].includes(type)
        }
        return false
    }

    const checkTyping = () => {
        if (!active) return false
        const el = document.activeElement
        return isEditable(el)
    }

    window.__mtaPhoneSyncTyping = () => {
        const state = checkTyping()
        if (state !== typingState) {
            typingState = state
            if (window.mta && typeof window.mta.triggerEvent === "function") {
                window.mta.triggerEvent("cylex_phone:typing", state)
            }
        }
    }

    document.addEventListener("focusin", window.__mtaPhoneSyncTyping, true)
    document.addEventListener("focusout", () => setTimeout(window.__mtaPhoneSyncTyping, 40), true)
    document.addEventListener("focus", window.__mtaPhoneSyncTyping, true)
    document.addEventListener("blur", () => setTimeout(window.__mtaPhoneSyncTyping, 40), true)
    document.addEventListener("input", window.__mtaPhoneSyncTyping, true)

    document.addEventListener("click", event => {
        const target = event.target
        if (!target) return
        const editable = target.closest ? target.closest("input, textarea, [contenteditable='true']") : null
        if (editable && !editable.disabled && !editable.readOnly && isEditable(editable)) {
            if (document.activeElement !== editable) {
                editable.focus()
            }
            setTimeout(window.__mtaPhoneSyncTyping, 10)
        } else {
            setTimeout(window.__mtaPhoneSyncTyping, 40)
        }
    }, true)

    window.addEventListener("mta-phone-active", () => {
        if (!active && typingState && document.activeElement) document.activeElement.blur()
        window.__mtaPhoneSyncTyping()
    })

    window.addEventListener("keydown", event => {
        if (!active) return
        if (event.key === "Escape") {
            if (typingState && document.activeElement && typeof document.activeElement.blur === "function") {
                document.activeElement.blur()
                window.__mtaPhoneSyncTyping()
                event.preventDefault()
                event.stopPropagation()
                return
            }
            if (window.mta && typeof window.mta.triggerEvent === "function") {
                event.preventDefault()
                window.mta.triggerEvent("cylex_phone:closeRequest")
            }
        } else if ((event.key === "F1" || event.key === "F4") && window.mta && typeof window.mta.triggerEvent === "function") {
            event.preventDefault()
            window.mta.triggerEvent("cylex_phone:closeRequest")
        }
    }, true)

    window.__mtaPhoneSetActive(false)
})()
