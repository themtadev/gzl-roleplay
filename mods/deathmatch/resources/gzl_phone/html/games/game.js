(() => {
    const gameName = new URLSearchParams(location.search).get("game") || "tower"
    const game = document.getElementById("game")
    const title = document.getElementById("title")
    const subtitle = document.getElementById("subtitle")
    const scoreLabel = document.getElementById("score")
    const resetButton = document.getElementById("reset")
    let resetGame = () => {}
    let score = 0
    const setScore = value => {
        score = value
        scoreLabel.textContent = `Skor ${score}`
    }
    const random = max => Math.floor(Math.random() * max)
    const tower = () => {
        title.textContent = "Pixel Tower"
        subtitle.textContent = "Bloğu bırak, kuleyi dengede tut."
        game.innerHTML = '<div class="panel tower"><div class="tower-stack"></div><button class="action" type="button">BLOĞU BIRAK</button></div>'
        const stack = game.querySelector(".tower-stack")
        let width = 94
        const add = () => {
            if (width < 28) {
                subtitle.textContent = "Kule devrildi. Yeniden dene."
                return
            }
            const block = document.createElement("div")
            block.className = "block"
            block.style.width = `${width}%`
            block.style.marginLeft = `${random(19) - 9}%`
            stack.append(block)
            width -= random(7)
            setScore(score + 1)
        }
        game.querySelector(".action").onclick = add
        add()
    }
    const numberGame = () => {
        title.textContent = "2048"
        subtitle.textContent = "Kaydır veya yön tuşlarını kullan."
        game.innerHTML = '<div class="panel board"></div>'
        const board = game.querySelector(".board")
        let cells = Array(16).fill(0)
        const spawn = () => {
            const empty = cells.map((value, index) => value ? -1 : index).filter(index => index >= 0)
            if (empty.length) cells[empty[random(empty.length)]] = Math.random() < .9 ? 2 : 4
        }
        const render = () => {
            board.innerHTML = cells.map(value => `<div class="cell ${value ? `v${value}` : ""}">${value || ""}</div>`).join("")
            setScore(cells.reduce((sum, value) => sum + value, 0))
        }
        const rows = direction => {
            const output = []
            for (let outer = 0; outer < 4; outer++) {
                const row = []
                for (let inner = 0; inner < 4; inner++) {
                    const x = direction === "left" ? inner : direction === "right" ? 3 - inner : outer
                    const y = direction === "up" ? inner : direction === "down" ? 3 - inner : outer
                    row.push(direction === "left" || direction === "right" ? y * 4 + x : y * 4 + x)
                }
                output.push(row)
            }
            return output
        }
        const move = direction => {
            const before = cells.join()
            rows(direction).forEach(indexes => {
                const values = indexes.map(index => cells[index]).filter(Boolean)
                for (let i = 0; i < values.length - 1; i++) if (values[i] === values[i + 1]) {
                    values[i] *= 2
                    values.splice(i + 1, 1)
                }
                while (values.length < 4) values.push(0)
                indexes.forEach((index, i) => cells[index] = values[i])
            })
            if (before !== cells.join()) spawn()
            render()
        }
        let sx = 0
        let sy = 0
        board.onpointerdown = event => {
            sx = event.clientX
            sy = event.clientY
        }
        board.onpointerup = event => {
            const dx = event.clientX - sx
            const dy = event.clientY - sy
            if (Math.max(Math.abs(dx), Math.abs(dy)) < 20) return
            move(Math.abs(dx) > Math.abs(dy) ? dx > 0 ? "right" : "left" : dy > 0 ? "down" : "up")
        }
        document.onkeydown = event => {
            const key = event.key.replace("Arrow", "").toLowerCase()
            if (["left", "right", "up", "down"].includes(key)) move(key)
        }
        spawn()
        spawn()
        render()
    }
    const uno = () => {
        title.textContent = "Uno"
        subtitle.textContent = "Aynı renk veya sayıyı eşleştir."
        const colors = ["red", "blue", "green", "yellow"]
        const card = () => ({ color: colors[random(colors.length)], value: random(9) + 1 })
        let top = card()
        let hand = Array.from({ length: 7 }, card)
        const render = message => {
            game.innerHTML = `<div class="panel uno"><div class="uno-table"><div class="top-card ${top.color}">${top.value}</div></div><div class="hand">${hand.map((item, index) => `<button class="card ${item.color}" data-index="${index}" type="button">${item.value}</button>`).join("")}</div><div class="uno-status">${message || "Kartını seç"}</div></div>`
            game.querySelectorAll(".card").forEach(button => button.onclick = () => {
                const index = Number(button.dataset.index)
                const selected = hand[index]
                if (selected.color !== top.color && selected.value !== top.value) {
                    render("Bu kart oynanamaz")
                    return
                }
                top = selected
                hand.splice(index, 1)
                setScore(score + 10)
                if (!hand.length) {
                    render("Kazandın")
                    return
                }
                const rival = card()
                top = rival
                if (!hand.some(item => item.color === top.color || item.value === top.value)) hand.push(card())
                render("Rakip oynadı")
            })
        }
        render()
    }
    const skate = () => {
        title.textContent = "Skate Surfers"
        subtitle.textContent = "Engeli gör, güvenli şeride geç."
        game.innerHTML = '<div class="panel skate"><div class="road"><span class="obstacle">🚧</span><span class="rider">🛹</span></div><div class="lanes"><button class="lane" data-lane="0">←</button><button class="lane" data-lane="1">↑</button><button class="lane" data-lane="2">→</button></div></div>'
        const rider = game.querySelector(".rider")
        const obstacle = game.querySelector(".obstacle")
        let danger = random(3)
        let current = 1
        const draw = () => {
            rider.style.setProperty("--lane", current)
            obstacle.style.setProperty("--lane", danger)
        }
        game.querySelectorAll(".lane").forEach(button => button.onclick = () => {
            current = Number(button.dataset.lane)
            if (current === danger) {
                setScore(Math.max(0, score - 2))
                subtitle.textContent = "Engele çarptın. Devam et."
            } else {
                setScore(score + 5)
                subtitle.textContent = "Temiz geçiş. Sıradaki engel hazır."
            }
            danger = random(3)
            draw()
        })
        draw()
    }
    const temple = () => {
        title.textContent = "Temple Run"
        subtitle.textContent = "Gösterilen yolu aynı sırayla takip et."
        const symbols = ["↑", "→", "↓", "←"]
        game.innerHTML = '<div class="panel temple"><div class="sequence">◆</div><div class="temple-grid"><button data-key="0">↑</button><button data-key="1">→</button><button data-key="3">←</button><button data-key="2">↓</button></div><div class="temple-status">Başlamak için bir yöne dokun</div></div>'
        const display = game.querySelector(".sequence")
        const status = game.querySelector(".temple-status")
        let sequence = [random(4)]
        let input = 0
        let showing = false
        const show = () => {
            showing = true
            input = 0
            status.textContent = "Yolu ezberle"
            sequence.forEach((value, index) => setTimeout(() => {
                display.textContent = symbols[value]
                setTimeout(() => display.textContent = "◆", 320)
                if (index === sequence.length - 1) setTimeout(() => {
                    showing = false
                    status.textContent = "Şimdi sen"
                }, 450)
            }, index * 620))
        }
        game.querySelectorAll("button").forEach(button => button.onclick = () => {
            if (showing) return
            const value = Number(button.dataset.key)
            if (value !== sequence[input]) {
                sequence = [random(4)]
                setScore(0)
                status.textContent = "Yanlış yol"
                setTimeout(show, 500)
                return
            }
            input++
            if (input === sequence.length) {
                setScore(score + sequence.length * 4)
                sequence.push(random(4))
                setTimeout(show, 350)
            }
        })
        show()
    }
    const games = { tower, number: numberGame, uno, skate, temple }
    resetGame = () => {
        setScore(0)
        document.onkeydown = null
        games[gameName in games ? gameName : "tower"]()
    }
    resetButton.onclick = resetGame
    resetGame()
})()
