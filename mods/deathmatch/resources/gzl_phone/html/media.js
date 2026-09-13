(() => {
    let database
    const urls = new Map()
    const open = () => database || (database = new Promise((resolve, reject) => {
        const request = indexedDB.open("cylex_phone_media", 1)
        request.onupgradeneeded = () => request.result.createObjectStore("captures", { keyPath: "id" })
        request.onsuccess = () => resolve(request.result)
        request.onerror = () => { database = null; reject(request.error) }
    }))
    const query = async (mode, action) => {
        const db = await open()
        return new Promise((resolve, reject) => {
            const transaction = db.transaction("captures", mode)
            const request = action(transaction.objectStore("captures"))
            transaction.oncomplete = () => resolve(request.result)
            transaction.onabort = transaction.onerror = () => reject(transaction.error || new Error("Galeri kaydedilemedi"))
        })
    }
    const view = record => {
        let cached = urls.get(record.id)
        if (!cached) {
            cached = { url: URL.createObjectURL(record.blob) + (record.type === "video" ? "#video.webm" : "#photo.jpg"), thumbnail: record.thumbnail ? URL.createObjectURL(record.thumbnail) + "#photo.jpg" : "" }
            urls.set(record.id, cached)
        }
        return { id: record.id, url: cached.url, src: cached.url, thumbnail: cached.thumbnail || undefined, type: record.type, date: record.date, duration: record.duration, favorite: Boolean(record.favorite), local: true }
    }
    window.__mtaPhoneMedia = {
        async list(owner) {
            const records = await query("readonly", store => store.getAll())
            return records.filter(record => record.owner === owner).sort((a, b) => b.date - a.date).map(view)
        },
        async save(owner, blob, details = {}) {
            if (!(blob instanceof Blob) || !blob.size || blob.size > 40 * 1024 * 1024) throw new Error("Kayıt boş veya 40 MB sınırını aşıyor")
            const records = await query("readonly", store => store.getAll())
            const total = records.reduce((size, record) => size + record.blob.size + (record.thumbnail ? record.thumbnail.size : 0), 0)
            if (total + blob.size + (details.thumbnail ? details.thumbnail.size : 0) > 256 * 1024 * 1024) throw new Error("Galeri dolu. Eski kayıtları silerek yer açabilirsin.")
            const record = { id: "mta-capture-" + Date.now() + "-" + Math.random().toString(36).slice(2), owner, blob, type: blob.type.startsWith("video/") ? "video" : "image", date: Date.now(), thumbnail: details.thumbnail, duration: details.duration }
            await query("readwrite", store => store.put(record))
            return view(record)
        },
        async remove(owner, ids) {
            for (const id of ids) {
                const record = await query("readonly", store => store.get(id))
                if (!record || record.owner !== owner) continue
                await query("readwrite", store => store.delete(id))
                const cached = urls.get(id)
                if (cached) {
                    URL.revokeObjectURL(cached.url.split("#")[0])
                    if (cached.thumbnail) URL.revokeObjectURL(cached.thumbnail.split("#")[0])
                    urls.delete(id)
                }
            }
        },
        async favorite(owner, id) {
            const record = await query("readonly", store => store.get(id))
            if (!record || record.owner !== owner) return null
            record.favorite = !record.favorite
            await query("readwrite", store => store.put(record))
            return view(record)
        }
    }
})()
