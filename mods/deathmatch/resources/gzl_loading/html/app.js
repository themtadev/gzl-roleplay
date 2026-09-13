const tracks=[
    {title:'Gece Sürüşü',artist:'GZL RP',duration:44,bpm:92,notes:[110,164.81,196,220,146.83,196,246.94,220]},
    {title:'Los Santos',artist:'GZL Sessions',duration:52,bpm:104,notes:[130.81,196,261.63,246.94,146.83,220,293.66,261.63]},
    {title:'Yol Hikâyesi',artist:'GZL Radio',duration:48,bpm:84,notes:[98,146.83,174.61,196,110,164.81,220,196]}
]

const state={track:0,playing:false,shuffle:false,liked:false,muted:false,volume:.42,elapsed:0,lastTick:performance.now(),audio:null,master:null,filter:null,noteTimer:null,noteIndex:0,toastTimer:null,closing:false}
const $=id=>document.getElementById(id)
const timeline=$('timeline')
const loadingStartedAt=performance.now()

function iconUse(id){return `<svg><use href="#${id}"/></svg>`}
function formatTime(value){const total=Math.max(0,Math.floor(value));return `${Math.floor(total/60)}:${String(total%60).padStart(2,'0')}`}
function applyTimeline(){const track=tracks[state.track];const ratio=Math.max(0,Math.min(1,state.elapsed/track.duration));timeline.max=track.duration;timeline.value=state.elapsed;timeline.style.background=`linear-gradient(90deg,#d5d7da 0%,#d5d7da ${ratio*100}%,rgba(255,255,255,.13) ${ratio*100}%,rgba(255,255,255,.13) 100%)`;$('current-time').textContent=formatTime(state.elapsed);$('duration').textContent=formatTime(track.duration)}
function renderTrack(){const track=tracks[state.track];$('track-title').textContent=track.title;$('track-artist').textContent=track.artist;state.elapsed=0;state.noteIndex=0;applyTimeline()}
function ensureAudio(){if(state.audio)return;const AudioContext=window.AudioContext||window.webkitAudioContext;state.audio=new AudioContext();state.master=state.audio.createGain();state.filter=state.audio.createBiquadFilter();state.filter.type='lowpass';state.filter.frequency.value=1200;state.filter.Q.value=.7;state.filter.connect(state.master);state.master.connect(state.audio.destination);state.master.gain.value=state.volume}
function playTone(frequency,when,duration,level,type){const osc=state.audio.createOscillator();const gain=state.audio.createGain();osc.type=type||'sine';osc.frequency.setValueAtTime(frequency,when);gain.gain.setValueAtTime(.0001,when);gain.gain.exponentialRampToValueAtTime(level,when+.025);gain.gain.exponentialRampToValueAtTime(.0001,when+duration);osc.connect(gain);gain.connect(state.filter);osc.start(when);osc.stop(when+duration+.05)}
function scheduleNote(){if(!state.playing||!state.audio)return;const track=tracks[state.track];const now=state.audio.currentTime;const note=track.notes[state.noteIndex%track.notes.length];playTone(note,now,.62,.055,'triangle');playTone(note*2,now+.12,.34,.018,'sine');if(state.noteIndex%4===0)playTone(note/2,now,.85,.07,'sine');state.noteIndex+=1}
function startSequencer(){clearInterval(state.noteTimer);scheduleNote();const delay=60000/tracks[state.track].bpm/2;state.noteTimer=setInterval(scheduleNote,delay)}
function setPlaying(value){ensureAudio();if(state.audio.state==='suspended')state.audio.resume();state.playing=value;state.lastTick=performance.now();$('play').innerHTML=iconUse(value?'i-pause':'i-play');if(value)startSequencer();else clearInterval(state.noteTimer)}
function changeTrack(direction,index){if(Number.isInteger(index))state.track=index;else if(state.shuffle)state.track=Math.floor(Math.random()*tracks.length);else state.track=(state.track+direction+tracks.length)%tracks.length;renderTrack();if(state.playing)startSequencer();showToast({text:`${tracks[state.track].title} çalıyor`})}
function animate(now){if(state.playing){state.elapsed+=(now-state.lastTick)/1000;if(state.elapsed>=tracks[state.track].duration)changeTrack(1);applyTimeline()}if(!state.closing){const loadingPercent=Math.min(99,Math.floor((now-loadingStartedAt)/300));$('loading-percent').textContent=loadingPercent;$('progress-fill').style.width=`${loadingPercent}%`}state.lastTick=now;requestAnimationFrame(animate)}

$('play').addEventListener('click',()=>setPlaying(!state.playing))
$('previous').addEventListener('click',()=>changeTrack(-1))
$('next').addEventListener('click',()=>changeTrack(1))
$('shuffle').addEventListener('click',()=>{state.shuffle=!state.shuffle;$('shuffle').classList.toggle('enabled',state.shuffle);showToast({text:state.shuffle?'Karışık çalma açık':'Karışık çalma kapalı'})})
$('favorite').addEventListener('click',()=>{state.liked=!state.liked;$('favorite').classList.toggle('liked',state.liked);showToast({text:state.liked?'Favorilere eklendi':'Favorilerden çıkarıldı'})})
$('volume').addEventListener('click',()=>{ensureAudio();state.muted=!state.muted;state.master.gain.setTargetAtTime(state.muted?0:state.volume,state.audio.currentTime,.03);$('volume').classList.toggle('enabled',state.muted);showToast({text:state.muted?'Ses kapatıldı':'Ses açıldı'})})
timeline.addEventListener('input',event=>{state.elapsed=Number(event.target.value);state.lastTick=performance.now();applyTimeline()})

document.querySelectorAll('[data-social]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('[data-social]').forEach(item=>item.classList.remove('active'));button.classList.add('active');if(window.mta)mta.triggerEvent('gzl_loading:social',button.dataset.social);else showToast({text:`${button.dataset.social} bağlantısı seçildi`})}))
document.querySelector('.player-label').addEventListener('click',()=>openPanel('tracks'))
document.querySelectorAll('.player-tabs .tab').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('.player-tabs .tab').forEach(item=>item.classList.remove('active'));button.classList.add('active');if(button.dataset.action==='music'){closePanel();showToast({text:`${tracks[state.track].title} hazır`})}if(button.dataset.action==='shuffle')$('shuffle').click();if(button.dataset.action==='queue')openPanel('tracks')}))

const panels={
    about:`<h3>GZL Roleplay</h3><p>Gerçekçi ekonomi, güçlü rol ortamı ve yaşayan Los Santos deneyimi.</p><div class="stat-grid"><div class="stat"><b>7/24</b><span>AKTİF</span></div><div class="stat"><b>TR</b><span>ROLEPLAY</span></div><div class="stat"><b>1.6</b><span>MTA:SA</span></div></div>`,
    gallery:`<h3>Şehirden Kareler</h3><div class="gallery-grid"><div style="background-image:url('../assets/background.png');background-position:20% 50%"></div><div style="background-image:url('../assets/background.png');background-position:52% 48%"></div><div style="background-image:url('../assets/background.png');background-position:75% 65%"></div><div style="background-image:url('../assets/background.png');background-position:95% 55%"></div></div>`,
    team:`<h3>Yönetim Ekibi</h3><div class="team-list"><div><b>GZL Yönetim</b><span>Kurucu</span></div><div><b>Roleplay Ekibi</b><span>Oyun Yönetimi</span></div><div><b>Destek Ekibi</b><span>Oyuncu Desteği</span></div></div>`,
    updates:`<h3>Sunucu Bilgileri</h3><p>Karakter sistemi, özel araçlar, gelişmiş envanter, telefon, radar ve rol odaklı ekonomi sistemleri yüklendi.</p><p>İyi roller dileriz.</p>`
}

function trackPanel(){return `<h3>Müzik Listesi</h3><div class="track-list">${tracks.map((track,index)=>`<button data-track="${index}"><b>${track.title}</b><span>${formatTime(track.duration)}</span></button>`).join('')}</div>`}
function openPanel(name){$('panel-content').innerHTML=name==='tracks'?trackPanel():panels[name];$('info-panel').classList.add('open');$('info-panel').setAttribute('aria-hidden','false');document.querySelectorAll('.dock button').forEach(item=>item.classList.toggle('active',item.dataset.panel===name));document.querySelectorAll('[data-track]').forEach(button=>button.addEventListener('click',()=>{changeTrack(0,Number(button.dataset.track));setPlaying(true)}))}
function closePanel(){$('info-panel').classList.remove('open');$('info-panel').setAttribute('aria-hidden','true');document.querySelectorAll('.dock button').forEach(item=>item.classList.remove('active'))}
document.querySelectorAll('.dock button').forEach(button=>button.addEventListener('click',()=>{if(button.classList.contains('active'))closePanel();else openPanel(button.dataset.panel)}))
$('close-panel').addEventListener('click',closePanel)

window.showToast=function(payload){const toast=$('toast');toast.textContent=payload.text||'';toast.classList.add('show');clearTimeout(state.toastTimer);state.toastTimer=setTimeout(()=>toast.classList.remove('show'),2300)}
window.setLoadingState=function(payload){const percent=Math.max(0,Math.min(100,Number(payload.percent)||0));$('loading-percent').textContent=Math.round(percent);$('loading-label').textContent=payload.status||'Oyun yükleniyor';$('loaded-count').textContent=Number(payload.loaded)||0;$('progress-fill').style.width=`${percent}%`}
window.completeLoading=function(){if(state.closing)return;state.closing=true;window.setLoadingState({percent:100,loaded:Number($('loaded-count').textContent)||0,status:'Oyun hazır'});setTimeout(()=>{$('screen').classList.add('closing')},350);setTimeout(()=>{if(window.mta)mta.triggerEvent('gzl_loading:close')},1300)}

renderTrack()
requestAnimationFrame(animate)
