const SoundEngine = (function () {
    let ctx = null;

    function getAudioContext() {
        if (!ctx) {
            const AudioCtx = window.AudioContext || window.webkitAudioContext;
            if (AudioCtx) {
                ctx = new AudioCtx();
            }
        }
        if (ctx && ctx.state === 'suspended') {
            ctx.resume();
        }
        return ctx;
    }

    function playTone(freq, type, duration, gainVal = 0.15, decay = 0.05) {
        try {
            const actx = getAudioContext();
            if (!actx) return;
            const osc = actx.createOscillator();
            const gain = actx.createGain();
            osc.type = type;
            osc.frequency.setValueAtTime(freq, actx.currentTime);
            gain.gain.setValueAtTime(gainVal, actx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.0001, actx.currentTime + duration + decay);
            osc.connect(gain);
            gain.connect(actx.destination);
            osc.start();
            osc.stop(actx.currentTime + duration + decay);
        } catch (e) {}
    }

    return {
        playClick: function () {
            playTone(850, 'sine', 0.04, 0.1, 0.02);
        },
        playTab: function () {
            playTone(600, 'sine', 0.05, 0.12, 0.03);
        },
        playAdd: function () {
            try {
                const actx = getAudioContext();
                if (!actx) return;
                const osc1 = actx.createOscillator();
                const osc2 = actx.createOscillator();
                const gain = actx.createGain();
                osc1.type = 'triangle';
                osc2.type = 'sine';
                osc1.frequency.setValueAtTime(523.25, actx.currentTime);
                osc2.frequency.setValueAtTime(659.25, actx.currentTime + 0.05);
                gain.gain.setValueAtTime(0.12, actx.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.0001, actx.currentTime + 0.18);
                osc1.connect(gain);
                osc2.connect(gain);
                gain.connect(actx.destination);
                osc1.start();
                osc2.start(actx.currentTime + 0.05);
                osc1.stop(actx.currentTime + 0.18);
                osc2.stop(actx.currentTime + 0.18);
            } catch (e) {}
        },
        playQty: function () {
            playTone(1100, 'sine', 0.025, 0.08, 0.015);
        },
        playDelete: function () {
            playTone(320, 'sawtooth', 0.06, 0.08, 0.04);
        },
        playSuccess: function () {
            try {
                const actx = getAudioContext();
                if (!actx) return;
                const notes = [587.33, 880, 1174.66];
                notes.forEach((freq, idx) => {
                    const osc = actx.createOscillator();
                    const gain = actx.createGain();
                    osc.type = 'sine';
                    osc.frequency.setValueAtTime(freq, actx.currentTime + idx * 0.07);
                    gain.gain.setValueAtTime(0.14, actx.currentTime + idx * 0.07);
                    gain.gain.exponentialRampToValueAtTime(0.0001, actx.currentTime + idx * 0.07 + 0.22);
                    osc.connect(gain);
                    gain.connect(actx.destination);
                    osc.start(actx.currentTime + idx * 0.07);
                    osc.stop(actx.currentTime + idx * 0.07 + 0.22);
                });
            } catch (e) {}
        },
        playError: function () {
            try {
                const actx = getAudioContext();
                if (!actx) return;
                const osc = actx.createOscillator();
                const gain = actx.createGain();
                osc.type = 'sawtooth';
                osc.frequency.setValueAtTime(140, actx.currentTime);
                osc.frequency.setValueAtTime(110, actx.currentTime + 0.08);
                gain.gain.setValueAtTime(0.18, actx.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.0001, actx.currentTime + 0.25);
                osc.connect(gain);
                gain.connect(actx.destination);
                osc.start();
                osc.stop(actx.currentTime + 0.25);
            } catch (e) {}
        },
        playOpen: function () {
            playTone(480, 'sine', 0.08, 0.12, 0.06);
        },
        playClose: function () {
            playTone(360, 'sine', 0.06, 0.1, 0.04);
        }
    };
})();
