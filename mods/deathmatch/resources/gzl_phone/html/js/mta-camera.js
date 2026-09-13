const request = async (event, data = {}) => {
    const result = await (await fetch("https://cylex_phone/" + event, { method: "POST", body: JSON.stringify(data) })).json()
    if (result && result.success === false) throw new Error(result.error || "Kamera kullanılamıyor")
    return result
}

const effects = {
    natural: "none",
    valencia: "sepia(0.24) saturate(1.2) contrast(1.05)",
    lark: "brightness(1.12) saturate(0.8)",
    reyes: "sepia(0.3) contrast(0.85) brightness(1.12)",
    blue: "sepia(0.35) hue-rotate(165deg) saturate(1.25)",
    blue2: "saturate(1.55) hue-rotate(15deg) contrast(1.1)",
    blue3: "sepia(0.45) saturate(1.25)",
    blue4: "grayscale(1) contrast(1.15)",
    blue5: "sepia(0.4) hue-rotate(330deg) contrast(1.12)"
}

const identity = () => [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
const multiply = (a, b) => a.map(row => b[0].map((_, column) => row.reduce((sum, value, index) => sum + value * b[index][column], 0)))
const colorMatrices = Object.fromEntries(Object.entries(effects).map(([name, filter]) => {
    let matrix = identity()
    for (const match of filter.matchAll(/([a-z-]+)\(([\d.]+)(deg)?\)/g)) {
        const type = match[1], value = Number(match[2])
        let next = identity()
        if (type === "brightness" || type === "contrast") {
            for (let i = 0; i < 3; i++) { next[i][i] = value; next[i][3] = type === "contrast" ? (1 - value) / 2 : 0 }
        } else if (type === "saturate" || type === "grayscale") {
            const amount = type === "grayscale" ? 1 - value : value
            const luminance = [0.213, 0.715, 0.072]
            for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) next[i][j] = luminance[j] * (1 - amount) + (i === j ? amount : 0)
        } else if (type === "sepia") {
            const sepia = [[0.393, 0.769, 0.189], [0.349, 0.686, 0.168], [0.272, 0.534, 0.131]]
            for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) next[i][j] = sepia[i][j] * value + (i === j ? 1 - value : 0)
        } else if (type === "hue-rotate") {
            const c = Math.cos(value * Math.PI / 180), s = Math.sin(value * Math.PI / 180)
            next = [[0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0], [0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0], [0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0], [0, 0, 0, 1]]
        }
        matrix = multiply(next, matrix)
    }
    return [name, matrix.slice(0, 3).flat().map(value => Math.round(value * 100000) / 100000)]
}))

const decodeImage = source => new Promise((resolve, reject) => {
    if (typeof source !== "string" || !source.startsWith("data:image/")) return reject(new Error("Kamera görüntüsü alınamadı"))
    const image = new Image()
    image.onload = () => resolve(image)
    image.onerror = () => reject(new Error("Fotoğraf okunamadı"))
    image.src = source
})

const toBlob = canvas => new Promise((resolve, reject) => canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error("Fotoğraf oluşturulamadı")), "image/jpeg", 0.9))

const notify = (component, message) => {
    const parent = component.$el
    if (!parent || !parent.appendChild) return
    let label = parent.querySelector(".mta-camera-message")
    if (!label) {
        label = document.createElement("div")
        label.className = "mta-camera-message"
        parent.appendChild(label)
    }
    label.textContent = message
    clearTimeout(component._messageTimer)
    component._messageTimer = setTimeout(() => label.remove(), 3500)
}

export class GameRender {
    constructor() {
        this.width = 360
        this.height = 640
        this.effect = "natural"
        this.selfie = false
        this.landscape = false
        this.zoom = 1
        this.running = false
        this.nativePreview = false
        this.recordingFrames = false
        this.generation = 0
        this.onState = event => {
            const { endpoint, data, result } = event.detail
            if (endpoint === "camera:changeEffect") this.effect = data.effect in effects ? data.effect : "natural"
            if (endpoint === "camera:frontCam") this.selfie = Boolean(result.selfie)
            if (endpoint === "camera:landscape") this.landscape = Boolean(data.enabled)
            this.resize()
            if (this.lastImage && (!this.nativePreview || this.recordingFrames)) this.draw(this.lastImage, this.canvas)
            if (this.nativePreview) this.trackViewport()
        }
        window.addEventListener("mta-camera-state", this.onState)
    }

    resize() {
        this.width = this.landscape ? 640 : 360
        this.height = this.landscape ? 480 : 640
        if (this.canvas && (this.canvas.width !== this.width || this.canvas.height !== this.height)) {
            this.canvas.width = this.width
            this.canvas.height = this.height
        }
    }

    draw(image, canvas) {
        if (!canvas) return
        const context = canvas.getContext("2d", { alpha: false })
        const ratio = canvas.width / canvas.height
        let width = image.width, height = image.height
        if (width / height > ratio) width = height * ratio
        else height = width / ratio
        context.save()
        context.filter = effects[this.effect]
        if (this.selfie) {
            context.translate(canvas.width, 0)
            context.scale(-1, 1)
        }
        context.drawImage(image, (image.width - width) / 2, (image.height - height) / 2, width, height, 0, 0, canvas.width, canvas.height)
        context.restore()
    }

    renderToTarget(canvas) {
        if (!canvas) return
        if (this.canvas !== canvas) {
            this.detachInput()
            this.canvas = canvas
            canvas.title = "Sürükle: kamerayı çevir · Tekerlek: yakınlaştır"
            this.attachInput()
            if (this.nativePreview) this.enableNativePreview()
        }
        this.resize()
        if (!this.running && document.documentElement.dataset.phoneActive === "true") this.start()
    }

    async start() {
        if (this.running || !this.canvas || !this.canvas.isConnected) return
        this.running = true
        const generation = ++this.generation
        try {
            const state = await request("camera:enter")
            if (!this.running || generation !== this.generation) return
            this.selfie = Boolean(state.selfie)
            this.zoom = 1
            this.nativePreview = Boolean(state.nativePreview)
            if (this.nativePreview) this.enableNativePreview()
            else await this.frame(generation)
        } catch (error) {
            this.running = false
            if (this.onError) this.onError(error)
        }
    }

    async frame(generation) {
        if (!this.running || generation !== this.generation || !this.canvas.isConnected) return
        if (this.nativePreview && !this.recordingFrames) return
        if (!this.capturing) {
            try {
                this.frameRequest = request("camera:frame")
                const image = await decodeImage(await this.frameRequest)
                if (!this.running || generation !== this.generation) return
                this.lastImage = image
                this.draw(image, this.canvas)
            } catch (error) {
                if (this.running && generation === this.generation && this.onError) this.onError(error)
            } finally {
                this.frameRequest = null
            }
        }
        if (this.running && generation === this.generation && (!this.nativePreview || this.recordingFrames)) this.timer = setTimeout(() => this.frame(generation), 70)
    }

    enableNativePreview() {
        this.disableNativePreview()
        this.canvas.classList.add("mta-native-camera-canvas")
        this.transparentElements = []
        let element = this.canvas.parentElement
        while (element && element !== document.body) {
            element.classList.add("mta-camera-transparent")
            this.transparentElements.push(element)
            if (element.classList.contains("phone-frame")) break
            element = element.parentElement
        }
        this.layoutRoot = this.canvas.closest(".phone-container")
        this.layoutChanged = () => this.trackViewport()
        this.resizeObserver = new ResizeObserver(this.layoutChanged)
        this.resizeObserver.observe(this.canvas)
        this.layoutObserver = new MutationObserver(this.layoutChanged)
        for (const parent of this.transparentElements) this.layoutObserver.observe(parent, { attributes: true, attributeFilter: ["class", "style"] })
        if (this.layoutRoot) {
            this.layoutObserver.observe(this.layoutRoot, { attributes: true, attributeFilter: ["class", "style"] })
            this.layoutRoot.addEventListener("transitionrun", this.layoutChanged, true)
            this.layoutRoot.addEventListener("animationstart", this.layoutChanged, true)
        }
        window.addEventListener("resize", this.layoutChanged)
        this.trackViewport()
    }

    trackViewport() {
        if (!this.running || !this.nativePreview) return
        this.layoutUntil = performance.now() + 900
        if (this.layoutFrame) return
        const update = () => {
            this.layoutFrame = null
            if (!this.running || !this.canvas.isConnected) return
            const rect = this.canvas.getBoundingClientRect()
            const phone = this.canvas.closest(".phone-container-in")
            const camera = this.canvas.closest(".camera-container")
            if (!phone || !camera) return
            const clip = phone.getBoundingClientRect()
            let alpha = 1
            for (const element of this.transparentElements || []) alpha *= Number(getComputedStyle(element).opacity)
            const round = value => Math.round(value * 10) / 10
            const scale = clip.width / (phone.offsetWidth || clip.width)
            const body = JSON.stringify({ visible: rect.width > 1 && rect.height > 1 && alpha > 0.01, x: round(rect.x), y: round(rect.y), width: round(rect.width), height: round(rect.height), clip: [clip.x, clip.y, clip.width, clip.height].map(round), radius: round(parseFloat(getComputedStyle(phone).borderTopLeftRadius) * scale), cameraRadius: round(parseFloat(getComputedStyle(camera).borderTopLeftRadius) * scale), alpha: round(alpha), colors: colorMatrices[this.effect] })
            if (body !== this.lastViewport && window.mta) {
                window.mta.triggerEvent("cylex_phone:cameraViewport", body)
                this.lastViewport = body
            }
            if (performance.now() < this.layoutUntil) this.layoutFrame = requestAnimationFrame(update)
        }
        this.layoutFrame = requestAnimationFrame(update)
    }

    disableNativePreview() {
        if (this.resizeObserver) this.resizeObserver.disconnect()
        if (this.layoutObserver) this.layoutObserver.disconnect()
        cancelAnimationFrame(this.layoutFrame)
        this.layoutFrame = null
        this.lastViewport = null
        if (this.layoutRoot && this.layoutChanged) {
            this.layoutRoot.removeEventListener("transitionrun", this.layoutChanged, true)
            this.layoutRoot.removeEventListener("animationstart", this.layoutChanged, true)
        }
        if (this.layoutChanged) window.removeEventListener("resize", this.layoutChanged)
        for (const element of this.transparentElements || []) element.classList.remove("mta-camera-transparent")
        this.transparentElements = []
        if (this.canvas) this.canvas.classList.remove("mta-native-camera-canvas")
    }

    async beginRecordingFrames() {
        if (!this.nativePreview) return
        this.recordingFrames = true
        await this.frame(this.generation)
    }

    endRecordingFrames() {
        this.recordingFrames = false
        if (this.nativePreview) clearTimeout(this.timer)
    }

    async capture() {
        if (!this.running || this.capturing) throw new Error("Kamera henüz hazır değil")
        this.capturing = true
        try {
            if (this.frameRequest) await this.frameRequest.catch(() => {})
            const image = await decodeImage(await request("camera:takePhoto"))
            const canvas = document.createElement("canvas")
            const ratio = this.landscape ? 4 / 3 : 9 / 16
            canvas.height = Math.min(image.height, Math.round(image.width / ratio))
            canvas.width = Math.round(canvas.height * ratio)
            this.draw(image, canvas)
            return await toBlob(canvas)
        } finally {
            this.capturing = false
        }
    }

    attachInput() {
        const canvas = this.canvas
        let pointer, lastX, lastY, dx = 0, dy = 0
        this.pointerDown = event => {
            if (event.button !== 0) return
            pointer = event.pointerId
            lastX = event.clientX
            lastY = event.clientY
            canvas.setPointerCapture(pointer)
            event.stopPropagation()
        }
        this.pointerMove = event => {
            if (event.pointerId !== pointer) return
            dx += (event.clientX - lastX) * 0.18
            dy += (event.clientY - lastY) * 0.18
            lastX = event.clientX
            lastY = event.clientY
            if (!this.lookTimer) this.lookTimer = setTimeout(() => {
                this.lookTimer = null
                if (this.running) request("camera:look", { x: dx, y: dy }).catch(() => {})
                dx = dy = 0
            }, 50)
        }
        this.pointerUp = () => { pointer = null }
        this.wheel = event => {
            event.preventDefault()
            this.zoom = Math.max(0.8, Math.min(3, this.zoom + (event.deltaY < 0 ? 0.15 : -0.15)))
            request("camera:zoom", { zoom: this.zoom }).catch(() => {})
        }
        canvas.addEventListener("pointerdown", this.pointerDown)
        canvas.addEventListener("pointermove", this.pointerMove)
        canvas.addEventListener("pointerup", this.pointerUp)
        canvas.addEventListener("pointercancel", this.pointerUp)
        canvas.addEventListener("wheel", this.wheel, { passive: false })
    }

    detachInput() {
        if (!this.canvas) return
        this.canvas.removeEventListener("pointerdown", this.pointerDown)
        this.canvas.removeEventListener("pointermove", this.pointerMove)
        this.canvas.removeEventListener("pointerup", this.pointerUp)
        this.canvas.removeEventListener("pointercancel", this.pointerUp)
        this.canvas.removeEventListener("wheel", this.wheel)
        clearTimeout(this.lookTimer)
        this.lookTimer = null
    }

    animate() { if (!this.running) this.start() }

    pause() {
        this.running = false
        this.generation++
        clearTimeout(this.timer)
        clearTimeout(this.lookTimer)
        this.lookTimer = null
        this.endRecordingFrames()
        this.disableNativePreview()
        if (this.nativePreview && window.mta) window.mta.triggerEvent("cylex_phone:cameraViewport", JSON.stringify({ visible: false }))
    }

    stop() {
        this.pause()
        this.detachInput()
        window.removeEventListener("mta-camera-state", this.onState)
        this.lastImage = null
    }
}

export function installCameraComponent(component) {
    const methods = component.methods
    methods.initCamera = function() {
        if (!this.MainRender) this.MainRender = new GameRender()
        this.MainRender.onError = error => notify(this, error.message)
        this.$nextTick(() => {
            this.load_preview_for_no_object()
            this.removeDragListeners()
            this.addDragListeners()
        })
        if (!this._activeListener) {
            this._activeListener = event => {
                if (event.detail) this.MainRender && this.MainRender.start()
                else {
                    if (this.videoStarted) this.stopVideoRecording()
                    if (this.MainRender) this.MainRender.pause()
                }
            }
            window.addEventListener("mta-phone-active", this._activeListener)
        }
    }
    methods.load_preview_for_no_object = async function() {
        await this.$nextTick()
        const canvas = this.$el && this.$el.querySelector("#tempCanvasCamera")
        if (canvas && this.MainRender) this.MainRender.renderToTarget(canvas)
    }
    methods.takePhoto = async function() {
        if (this.isUploading || !this.MainRender) return
        this.isUploading = true
        try {
            const photo = await this.MainRender.capture()
            await window.__mtaPhoneSaveCapture(photo)
            notify(this, "Fotoğraf galeriye kaydedildi")
        } catch (error) {
            notify(this, error.message)
        } finally {
            this.isUploading = false
        }
    }
    methods.set_selected_camera = async function() {
        if (this.videoStarted) await this.stopVideoRecording()
        await this.load_preview_for_no_object()
        await request("camera:changeCamera", { camera: this.selectedCamera }).catch(error => notify(this, error.message))
    }
    methods.takeVideo = async function() {
        if (this.videoStarted) return this.stopVideoRecording()
        if (this.isUploading || !this.MainRender || !this.MainRender.running) return
        let stream
        try {
            if (!window.MediaRecorder || !HTMLCanvasElement.prototype.captureStream) throw new Error("Bu MTA sürümünde video kaydı desteklenmiyor")
            const mimeType = ["video/webm;codecs=vp8", "video/webm;codecs=vp9", "video/webm"].find(type => MediaRecorder.isTypeSupported(type))
            if (!mimeType) throw new Error("Video kodlayıcısı kullanılamıyor")
            await this.MainRender.beginRecordingFrames()
            if (!this.MainRender.lastImage) throw new Error("Kayıt görüntüsü hazır değil")
            stream = this.MainRender.canvas.captureStream(12)
            const recorder = new MediaRecorder(stream, { mimeType, videoBitsPerSecond: 1200000 })
            const chunks = []
            const started = Date.now()
            const thumbnail = await toBlob(this.MainRender.canvas)
            recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data) }
            recorder.onstop = async () => {
                if (this.MainRender) this.MainRender.endRecordingFrames()
                clearTimeout(this._recordingLimit)
                clearInterval(this.timerInterval)
                this.timerInterval = null
                this.videoStarted = false
                this.isUploading = true
                stream.getTracks().forEach(track => track.stop())
                try {
                    const seconds = Math.max(1, Math.round((Date.now() - started) / 1000))
                    const duration = String(Math.floor(seconds / 60)).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0")
                    await window.__mtaPhoneSaveCapture(new Blob(chunks, { type: "video/webm" }), { thumbnail, duration })
                    notify(this, "Video galeriye kaydedildi")
                } catch (error) {
                    notify(this, error.message)
                } finally {
                    this.isUploading = false
                    this.mediaRecorder = null
                }
            }
            recorder.onerror = event => notify(this, event.error && event.error.message || "Video kaydedilemedi")
            this.mediaRecorder = recorder
            recorder.start(1000)
            notify(this, "Sessiz video · en fazla 60 saniye")
            this.videoStarted = true
            this.videoTimer = "00:00:00"
            this.timerInterval = setInterval(() => {
                const seconds = Math.floor((Date.now() - started) / 1000)
                this.videoTimer = String(Math.floor(seconds / 60)).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0")
            }, 250)
            this._recordingLimit = setTimeout(() => this.stopVideoRecording(), 60000)
        } catch (error) {
            if (this.MainRender) this.MainRender.endRecordingFrames()
            if (stream) stream.getTracks().forEach(track => track.stop())
            notify(this, error.message)
        }
    }
    methods.stopVideoRecording = function() {
        if (this.MainRender) this.MainRender.endRecordingFrames()
        clearTimeout(this._recordingLimit)
        clearInterval(this.timerInterval)
        this.timerInterval = null
        this.videoStarted = false
        if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") this.mediaRecorder.stop()
    }
    methods.destroyCamera = function() {
        this.stopVideoRecording()
        this.removeDragListeners()
        if (this.MainRender) this.MainRender.stop()
        this.MainRender = null
        if (this._activeListener) window.removeEventListener("mta-phone-active", this._activeListener)
        this._activeListener = null
        this.isLandscape = false
        this.$store.state.wideCameraMode = false
        this.selectedCamera = "photo"
        this.selectedEffect = "natural"
        request("camera:close").catch(() => {})
    }
}
