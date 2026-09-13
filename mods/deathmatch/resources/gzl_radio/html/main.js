let createPageValue = false
let currentFrequency = null
let inRadio = false
let passwordMode = false
let memberListExpanded = true
let requestSequence = 0
const pendingRequests = new Map()

const one = selector => document.querySelector(selector)
const all = selector => Array.from(document.querySelectorAll(selector))

function setVisible(selector, visible, display = "block") {
    all(selector).forEach(element => {
        element.style.display = visible ? display : "none"
    })
}

function setText(selector, value) {
    all(selector).forEach(element => {
        element.textContent = value
    })
}

function setValue(selector, value) {
    all(selector).forEach(element => {
        element.value = value
    })
}

function setActive(selector, active) {
    all(selector).forEach(element => {
        element.classList.toggle("active", active)
    })
}

function radioRequest(action, data = {}) {
    return new Promise(resolve => {
        requestSequence += 1
        const id = requestSequence
        pendingRequests.set(id, resolve)
        if (window.mta && typeof window.mta.triggerEvent === "function") {
            window.mta.triggerEvent("gzl_radio:cefEvent", action, JSON.stringify(data), id)
        } else {
            pendingRequests.delete(id)
            resolve({ ok: false })
        }
        window.setTimeout(() => {
            if (pendingRequests.has(id)) {
                pendingRequests.delete(id)
                resolve({ ok: false })
            }
        }, 8000)
    })
}

function cleanFrequency(value) {
    const number = Number.parseFloat(String(value).replace(",", "."))
    if (!Number.isFinite(number) || number <= 0) return null
    return number.toFixed(1)
}

function changePage(page) {
    setVisible(".pages", false)
    setVisible(`.page-${page}`, true)
    setActive(".buttons", false)
    setActive(`.button-${page}`, true)
    setText(".radio-channel-text", "Telsiz Frekansı;")
    setActive(".radio-channel-input-box", false)
    setActive(".bluetooth-icon", false)
    if (!inRadio) {
        setValue(".radio-input", "00.0")
        currentFrequency = null
    }
    one(".radio-input").placeholder = "00.0"
    passwordMode = false
}

function memberListSmall() {
    memberListExpanded = !memberListExpanded
    setActive(".menu-container", memberListExpanded)
}

function back() {
    if (!passwordMode) return
    currentFrequency = null
    setText(".radio-channel-text", "Telsiz Frekansı;")
    setActive(".radio-channel-input-box", false)
    setActive(".bluetooth-icon", false)
    setValue(".radio-input", "00.0")
    one(".radio-input").placeholder = "00.0"
    passwordMode = false
}

function createPage() {
    createPageValue = !createPageValue
    setVisible(".channel-list-item-container", !createPageValue, "flex")
    setVisible(".create-channel", createPageValue)
}

function resetConnectionView() {
    currentFrequency = null
    inRadio = false
    passwordMode = false
    setVisible(".connect-btn", true, "flex")
    setVisible(".disconnect-btn", false)
    setVisible(".menu-container", false)
    setText(".text-mhz", "00.0Mhz")
    setValue(".radio-input", "00.0")
    one(".radio-input").disabled = false
    one(".radio-input").placeholder = "00.0"
    setText(".radio-channel-text", "Telsiz Frekansı;")
    setActive(".radio-channel-input-box", false)
    setActive(".bluetooth-icon", false)
    setActive(".star-icon", false)
    setActive(".kablo-icon", false)
    renderMembers([])
}

function applyConnected(data) {
    currentFrequency = String(data.frequency)
    inRadio = true
    passwordMode = false
    setText(".radio-channel-text", "Telsiz Frekansı;")
    setActive(".radio-channel-input-box", false)
    setActive(".bluetooth-icon", false)
    one(".radio-input").placeholder = "00.0"
    setValue(".radio-input", currentFrequency)
    one(".radio-input").disabled = true
    setVisible(".connect-btn", false)
    setVisible(".disconnect-btn", true, "flex")
    setVisible(".menu-container", true)
    setText(".text-mhz", `${currentFrequency}Mhz`)
    setActive(".star-icon", data.favorite === true)
    setActive(".kablo-icon", true)
    renderMembers(data.members || [])
    if (Array.isArray(data.favorites)) renderFavorites(data.favorites)
}

function applyBootstrap(data) {
    renderFavorites(data.favorites || [])
    if (data.frequency) {
        applyConnected(data)
    } else {
        resetConnectionView()
        renderFavorites(data.favorites || [])
    }
}

function renderMembers(members) {
    const menuList = one(".member-items-container")
    const radioList = one(".mic-items-container")
    menuList.replaceChildren()
    radioList.replaceChildren()
    members.forEach(member => {
        const id = String(member.id)
        const menuItem = document.createElement("div")
        menuItem.className = "member-item"
        menuItem.dataset.memberId = id
        const antenna = document.createElement("img")
        antenna.className = "menu-anten-icon"
        antenna.src = "public/menu-anten-icon.svg"
        const name = document.createElement("p")
        name.className = "member-item-text"
        name.textContent = String(member.name)
        const mic = document.createElement("img")
        mic.className = "menu-mic-icon"
        mic.src = "public/menu-mic-icon.svg"
        menuItem.append(antenna, name, mic)
        menuList.append(menuItem)
        const radioItem = document.createElement("div")
        radioItem.className = "mic-item"
        radioItem.dataset.memberId = id
        const radioName = document.createElement("p")
        radioName.className = "mic-item-name"
        radioName.textContent = String(member.name)
        const radioMic = document.createElement("img")
        radioMic.className = "green-mic-item"
        radioMic.src = "public/green-mic-item.svg"
        radioItem.append(radioName, radioMic)
        radioList.append(radioItem)
    })
    setText(".member-list-num", String(members.length))
}

function renderFavorites(favorites) {
    const list = one(".channel-list-item-container")
    list.replaceChildren()
    favorites.forEach(frequency => {
        const item = document.createElement("div")
        item.className = "channel-list-item"
        const label = document.createElement("p")
        label.className = "mhz-text"
        label.textContent = `${frequency}Mhz`
        const star = document.createElement("img")
        star.className = "star-channel-icon"
        star.src = "public/star-icon-channel.svg"
        star.addEventListener("click", () => quickFavorite(String(frequency)))
        const connectIcon = document.createElement("img")
        connectIcon.className = "channel-kablo-icon"
        connectIcon.src = "public/kablo-con-channel.svg"
        connectIcon.addEventListener("click", () => quickConnect(String(frequency)))
        item.append(label, star, connectIcon)
        list.append(item)
    })
}

function setTalking(id, talking) {
    all("[data-member-id]").forEach(element => {
        if (element.dataset.memberId === String(id)) {
            element.classList.toggle("active", talking === true)
        }
    })
}

async function createChannel() {
    const frequency = cleanFrequency(one(".radio-input-2").value)
    if (!frequency) return
    const response = await radioRequest("createChannel", {
        frequency,
        password: one(".channel-password-inp").value
    })
    if (!response.ok) return
    setValue(".radio-input-2", "")
    setValue(".channel-password-inp", "")
    if (createPageValue) createPage()
    changePage("main")
    applyConnected(response)
}

async function connect() {
    if (!passwordMode) {
        const frequency = cleanFrequency(one(".radio-input").value)
        if (!frequency) return
        const response = await radioRequest("connect", { frequency })
        if (response.status === "password") {
            currentFrequency = frequency
            passwordMode = true
            setText(".radio-channel-text", "Telsiz Şifresi;")
            setActive(".radio-channel-input-box", true)
            setActive(".bluetooth-icon", true)
            setValue(".radio-input", "")
            one(".radio-input").placeholder = "Şifre..."
            return
        }
        if (response.ok) applyConnected(response)
        return
    }
    const password = one(".radio-input").value
    if (!password || !currentFrequency) return
    const response = await radioRequest("password", {
        frequency: currentFrequency,
        password
    })
    if (response.ok) {
        applyConnected(response)
    } else if (response.status === "missing") {
        back()
    } else {
        setValue(".radio-input", "")
    }
}

async function disconnect() {
    const response = await radioRequest("disconnect")
    if (response.ok) resetConnectionView()
}

async function quickConnect(frequency) {
    if (inRadio) return
    changePage("main")
    setValue(".radio-input", frequency)
    await connect()
}

async function quickFavorite(frequency) {
    const response = await radioRequest("favorite", { frequency })
    if (response.ok) {
        renderFavorites(response.favorites || [])
        if (currentFrequency === response.frequency) setActive(".star-icon", response.favorite === true)
    }
}

async function favorite() {
    if (!inRadio || !currentFrequency) return
    await quickFavorite(currentFrequency)
}

function volume(increase) {
    if (inRadio) radioRequest("volume", { increase: increase === true })
}

function resetPosition() {
    const menu = one(".menu-container")
    localStorage.removeItem("radioMenuPosition")
    menu.style.left = ""
    menu.style.right = "1vh"
    menu.style.top = "1.5vh"
}

function closeInterface() {
    const radio = one(".telsiz-main-container")
    radio.style.bottom = "-80vh"
    window.setTimeout(() => setVisible(".telsiz-main-container", false), 500)
}

window.radioDispatch = function(payload) {
    if (!payload || typeof payload !== "object") return
    if (payload.type === "response") {
        const resolve = pendingRequests.get(payload.id)
        if (resolve) {
            pendingRequests.delete(payload.id)
            resolve(payload.data || {})
        }
    } else if (payload.type === "open") {
        setVisible(".telsiz-main-container", true)
        window.setTimeout(() => {
            one(".telsiz-main-container").style.bottom = "1vh"
        }, 50)
        radioRequest("bootstrap").then(response => {
            if (response.ok) applyBootstrap(response)
        })
    } else if (payload.type === "close") {
        closeInterface()
    } else if (payload.type === "forceKick") {
        resetConnectionView()
    } else if (payload.type === "state") {
        if (payload.data && payload.data.frequency === currentFrequency) {
            renderMembers(payload.data.members || [])
        }
    } else if (payload.type === "talking") {
        setTalking(payload.id, payload.value)
    } else if (payload.type === "resetPosition") {
        resetPosition()
    }
}

document.addEventListener("DOMContentLoaded", () => {
    const menu = one(".menu-container")
    const savedPosition = JSON.parse(localStorage.getItem("radioMenuPosition") || "null")
    if (savedPosition) {
        menu.style.left = `${savedPosition.left}px`
        menu.style.top = `${savedPosition.top}px`
        menu.style.right = "auto"
    }
    let dragging = false
    let offsetX = 0
    let offsetY = 0
    menu.addEventListener("mousedown", event => {
        dragging = true
        const rect = menu.getBoundingClientRect()
        offsetX = event.clientX - rect.left
        offsetY = event.clientY - rect.top
    })
    document.addEventListener("mousemove", event => {
        if (!dragging) return
        menu.style.left = `${event.clientX - offsetX}px`
        menu.style.top = `${event.clientY - offsetY}px`
        menu.style.right = "auto"
    })
    document.addEventListener("mouseup", () => {
        if (!dragging) return
        dragging = false
        const rect = menu.getBoundingClientRect()
        localStorage.setItem("radioMenuPosition", JSON.stringify({ left: rect.left, top: rect.top }))
    })
    document.addEventListener("keyup", event => {
        if (event.key === "Escape") radioRequest("exit")
    })
    const updateClock = () => {
        const date = new Date()
        setText(".top-clock", `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`)
    }
    updateClock()
    window.setInterval(updateClock, 5000)
})
