let notificationsEnabled = true;
let showingEmojiMenu = false;
let showingChatInput = false;
let enableEmojiMenu = true;
let boxTimeout = null;
let showingUsedCommand = -1;
let commandList = [];
let commandSuggestions = [];
let usedCommands = [];
let defaultSuggestions = [];
let currentRenderedSuggestions = "";

function post(url, data) {
  let eventName = url;
  if (typeof url === 'string' && url.includes('/')) {
    const parts = url.split('/');
    eventName = parts[parts.length - 1];
  }
  const payload = (typeof data === 'string') ? data : JSON.stringify(data || {});
  if (window.mta && window.mta.triggerEvent) {
    mta.triggerEvent("chat:onNuiCallback", eventName, payload);
  }
}

function getTime() {
  const d = new Date();
  const h = d.getHours().toString().padStart(2, '0');
  const m = d.getMinutes().toString().padStart(2, '0');
  return `${h}:${m}`;
}

function escapeHtml(text) {
  if (typeof text !== 'string') return '';
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return text.replace(/[&<>"']/g, (m) => map[m]);
}

function parseText(str) {
  if (typeof str !== 'string') return '';
  let safe = escapeHtml(str);
  safe = safe.replace(/\^([0-9])/g, (m, c) => `</span><span class="chat-textColor-${c}">`);
  safe = safe.replace(/#([0-9a-fA-F]{6})/g, (m, c) => `</span><span style="color: #${c};">`);
  safe = safe.replaceAll("\n", "<br/>");
  return safe;
}

function addMessageCard(type, typeColor, header, content, time, textColor) {
  time = time || getTime();
  type = type || 'BİLGİ';
  typeColor = typeColor || '#3b82f6';
  header = escapeHtml(header || '');
  content = parseText(content || '');
  const bottomStyle = textColor ? `style="color: ${textColor};"` : '';

  const msgHtml = `
    <div class="message">
      <div class="message-top">
        <div class="message-top-left">
          <div style="background-color: ${typeColor};" class="message-type">${type}</div>
          <div class="message-header">${header}</div>
        </div>
        <div class="message-time">${time}</div>
      </div>
      <div class="message-bottom" ${bottomStyle}>${content}</div>
    </div>
  `;

  const $box = $(".message-box");
  $box.append(msgHtml);
  if ($box.children().length > 100) {
    $box.children().first().remove();
  }
  $box.scrollTop($box.prop("scrollHeight"));

  if (notificationsEnabled) {
    showChatBox();
    clearTimeout(boxTimeout);
    boxTimeout = setTimeout(() => {
      if (!showingChatInput) {
        hideChatBox();
      }
    }, 7000);
  }
}

function handleIncomingMessage(raw) {
  if (!raw) return;
  if (raw.type && (raw.content || raw.header)) {
    addMessageCard(raw.type, raw.typeColor, raw.header, raw.content, raw.time, raw.textColor);
    return;
  }
  if (raw.args && Array.isArray(raw.args)) {
    let tpl = raw.template || '';
    let type = 'SAY';
    let typeColor = '#2563eb';
    let header = raw.args[0] || '';
    let content = raw.args[1] || raw.args[0] || '';
    let textColor = raw.textColor || null;

    if (tpl.includes('class="chat-message me"')) {
      type = 'ME';
      typeColor = '#8e44ad';
    } else if (tpl.includes('class="chat-message do"')) {
      type = 'DO';
      typeColor = '#16a085';
    } else if (tpl.includes('class="chat-message local-ooc"')) {
      type = 'OOC';
      typeColor = '#64748b';
    } else if (tpl.includes('class="chat-message global-ooc"')) {
      type = 'GLOBAL';
      typeColor = '#ea580c';
    } else if (tpl.includes('class="chat-message shout"')) {
      type = 'BAĞIRMA';
      typeColor = '#dc2626';
    } else if (tpl.includes('class="chat-message whisper"')) {
      type = 'FISILTI';
      typeColor = '#0d9488';
    } else if (tpl.includes('class="chat-message pm"')) {
      type = 'PM';
      typeColor = '#d97706';
    } else if (tpl.includes('class="chat-message server"') || tpl.includes('DUYURU')) {
      type = 'DUYURU';
      typeColor = '#e11d48';
      header = 'YÖNETİM';
      content = raw.args[0] || '';
    } else if (tpl.includes('class="chat-message advert"') || tpl.includes('ZAR')) {
      type = 'ZAR';
      typeColor = '#ca8a04';
      content = `Zar attı ve [${raw.args[1] || ''}] geldi.`;
    } else if (tpl.includes('class="chat-message error"') || tpl.includes('HATA')) {
      type = 'HATA';
      typeColor = '#ef4444';
      header = 'SİSTEM';
      content = raw.args[0] ? `Bilinmeyen komut: /${raw.args[0]}` : tpl.replace(/<[^>]+>/g, '');
    } else if (raw.args.length === 1) {
      type = 'BİLGİ';
      typeColor = '#3b82f6';
      header = 'BİLGİ';
      content = raw.args[0];
    }
    addMessageCard(type, typeColor, header, content, raw.time, textColor);
    return;
  }
  if (typeof raw === 'string') {
    addMessageCard('BİLGİ', '#3b82f6', 'BİLGİ', raw);
  }
}

function clearMessages() {
  $(".message-box").empty();
  usedCommands = [];
  showingUsedCommand = -1;
}

function showChatBox() {
  $(".message-box").css("opacity", "1");
}

function hideChatBox() {
  $(".message-box").css("opacity", "0");
}

function showChatInput(initialText) {
  showingChatInput = true;
  const $input = $("#chat-text-input");
  $input.val(initialText || '');
  $(".chat-input-part").css("display", "flex");
  showChatBox();
  clearTimeout(boxTimeout);

  if (initialText && initialText.startsWith("/")) {
    onTextInput();
  } else {
    updateSuggestions([]);
  }

  $input.focus();
  setTimeout(() => {
    $input.val(initialText || '');
    $input.focus();
  }, 40);
  setTimeout(() => {
    $input.focus();
  }, 120);
}

function hideChatInput(sendCancel) {
  $(".chat-input-part").css("display", "none");
  hideEmojiMenu();
  hideSuggestions();
  showingChatInput = false;
  showingUsedCommand = -1;
  $("#chat-text-input").val("");

  if (sendCancel) {
    post('chatResult', { canceled: true });
  }

  clearTimeout(boxTimeout);
  boxTimeout = setTimeout(() => {
    if (!showingChatInput) {
      hideChatBox();
    }
  }, 4000);
}

function processInput() {
  const inputVal = $("#chat-text-input").val().trim();
  hideChatInput(false);

  if (inputVal.length > 0) {
    if (usedCommands.length === 0 || usedCommands[0] !== inputVal) {
      usedCommands.unshift(inputVal);
      if (usedCommands.length > 50) usedCommands.pop();
    }
    post('chatResult', { message: inputVal });
  } else {
    post('chatResult', { canceled: true });
  }
}

function showUsedCommands(isUp) {
  if (usedCommands.length === 0) return;
  if (isUp) {
    showingUsedCommand++;
    if (showingUsedCommand >= usedCommands.length) {
      showingUsedCommand = usedCommands.length - 1;
    }
  } else {
    showingUsedCommand--;
    if (showingUsedCommand < -1) {
      showingUsedCommand = -1;
    }
  }

  const $input = $("#chat-text-input");
  if (showingUsedCommand === -1) {
    $input.val("");
  } else {
    $input.val(usedCommands[showingUsedCommand]);
  }
  onTextInput();
}

function onTextInput() {
  const val = $("#chat-text-input").val().trim();
  if (!val.startsWith("/")) {
    updateSuggestions([]);
    return;
  }

  const query = val.slice(1).toLowerCase();
  if (query.length === 0) {
    updateSuggestions(defaultSuggestions);
    return;
  }

  const matched = [];
  commandSuggestions.forEach((s) => {
    const sName = s.name.startsWith("/") ? s.name.slice(1).toLowerCase() : s.name.toLowerCase();
    if (sName.startsWith(query)) {
      matched.push(s);
    }
  });

  commandList.forEach((cmd) => {
    const cLower = cmd.startsWith("/") ? cmd.slice(1).toLowerCase() : cmd.toLowerCase();
    if (cLower.startsWith(query) && !matched.some((m) => (m.name.startsWith("/") ? m.name.slice(1).toLowerCase() : m.name.toLowerCase()) === cLower)) {
      matched.push({ name: "/" + cmd, help: "" });
    }
  });

  defaultSuggestions.forEach((s) => {
    const sName = s.name.startsWith("/") ? s.name.slice(1).toLowerCase() : s.name.toLowerCase();
    if (sName.startsWith(query) && !matched.some((m) => (m.name.startsWith("/") ? m.name.slice(1).toLowerCase() : m.name.toLowerCase()) === sName)) {
      matched.push(s);
    }
  });

  updateSuggestions(matched.slice(0, 8));
}

function updateSuggestions(list) {
  const $sug = $(".suggestions");
  if (!list || list.length === 0 || showingEmojiMenu) {
    currentRenderedSuggestions = "";
    $sug.empty().css("display", "none");
    return;
  }

  const listKey = list.map((item) => (item.name.startsWith("/") ? item.name : `/${item.name}`)).join("|");
  if (listKey === currentRenderedSuggestions) {
    return;
  }
  currentRenderedSuggestions = listKey;

  $sug.empty();
  list.forEach((item) => {
    const cmdName = item.name.startsWith("/") ? item.name : `/${item.name}`;
    const $pill = $('<div class="suggestion"></div>').text(cmdName);
    $pill.on("click", () => {
      $("#chat-text-input").val(`${cmdName} `).focus();
      onTextInput();
    });
    $sug.append($pill);
  });

  $sug.css("display", "flex");
}

function showSuggestions() {
  if (!showingEmojiMenu && currentRenderedSuggestions !== "") {
    $(".suggestions").css("display", "flex");
  }
}

function hideSuggestions() {
  currentRenderedSuggestions = "";
  $(".suggestions").empty().css("display", "none");
}

function loadEmojiMenu() {
  if (typeof emojiList === 'undefined' || !Array.isArray(emojiList)) return;
  const $menu = $(".chat-emoji-menu");
  $menu.empty();
  emojiList.forEach((emoji) => {
    const $item = $('<div class="emoji-menu-emoji"></div>').text(emoji);
    $item.on("click", () => emojiClicked(emoji));
    $menu.append($item);
  });
}

function showEmojiMenu() {
  if (!enableEmojiMenu) return;
  hideSuggestions();
  $(".chat-emoji-menu").css("display", "flex");
  showingEmojiMenu = true;
}

function hideEmojiMenu() {
  $(".chat-emoji-menu").css("display", "none");
  showingEmojiMenu = false;
  showSuggestions();
}

function toggleEmojiMenu() {
  if ($(".chat-emoji-menu").css("display") === "none") {
    if ($(".chat-emoji-menu").children().length === 0) {
      loadEmojiMenu();
    }
    showEmojiMenu();
  } else {
    hideEmojiMenu();
  }
}

function emojiClicked(emoji) {
  const $input = $("#chat-text-input");
  $input.val($input.val() + emoji).focus();
  onTextInput();
}

function toggleNotification() {
  notificationsEnabled = !notificationsEnabled;
  if (notificationsEnabled) {
    $("#notification-img").attr("src", "img/bell.png");
  } else {
    $("#notification-img").attr("src", "img/bell-slash.png");
  }
}

window.sendNuiMessage = function(data) {
  let payload = data;
  if (typeof data === 'string') {
    try { payload = JSON.parse(data); } catch(e) {}
  }
  if (Array.isArray(payload) && payload.length > 0 && payload[0] && (payload[0].type || payload[0].action)) {
    payload = payload[0];
  }
  if (!payload) return;

  const action = payload.action || payload.type;

  switch (action) {
    case "showChat":
    case "ON_OPEN":
      showChatInput(payload.message || "");
      break;

    case "hideChat":
    case "ON_CLOSE":
      hideChatInput(false);
      break;

    case "addMessage":
    case "ON_MESSAGE":
      handleIncomingMessage(payload.message);
      break;

    case "clear":
    case "ON_CLEAR":
      clearMessages();
      break;

    case "addSuggestion":
    case "ON_SUGGESTION_ADD":
      if (payload.suggestion) {
        const s = payload.suggestion;
        const exists = commandSuggestions.some((x) => x.name.toLowerCase() === s.name.toLowerCase());
        if (!exists) {
          commandSuggestions.push(s);
        }
      }
      break;

    case "ON_SUGGESTION_REMOVE":
      if (payload.name) {
        commandSuggestions = commandSuggestions.filter((x) => x.name.toLowerCase() !== payload.name.toLowerCase());
      }
      break;

    case "ON_COMMANDS_RESET":
      commandSuggestions = [];
      break;
  }
};

window.addEventListener("message", ({ data }) => {
  if (data) {
    window.sendNuiMessage(data);
  }
});

$(document).ready(() => {
  post('loaded', {});

  defaultSuggestions = [
    { name: "/me", help: "Fiziksel eylem" },
    { name: "/do", help: "Durum bildirimi" },
    { name: "/b", help: "Yerel OOC" },
    { name: "/ooc", help: "Genel OOC" },
    { name: "/s", help: "Bağırma" },
    { name: "/w", help: "Fısıltı" },
    { name: "/pm", help: "Özel mesaj" },
    { name: "/zarat", help: "Zar at" },
    { name: "/clear", help: "Temizle" },
    { name: "/otur", help: "Oturma animasyonu (1-10)" },
    { name: "/elkaldir", help: "Tek el kaldır/indir (X)" },
    { name: "/teslim", help: "İki el teslim ol (Shift+X)" },
    { name: "/sit", help: "Oturma animasyonu (1-10)" },
    { name: "/oturliste", help: "Oturma stilleri listesi" }
  ];

  $("#chat-text-input").on("input", function() {
    onTextInput();
  });

  $(".chat-input").on("click", function() {
    $("#chat-text-input").focus();
  });

  $("#chat-emoji-icon").on("click", toggleEmojiMenu);
  $("#notification").on("click", toggleNotification);

  $(window).on("keydown", function(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      hideChatInput(true);
    } else if (e.key === "Enter") {
      e.preventDefault();
      processInput();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      showUsedCommands(true);
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      showUsedCommands(false);
    }
  });

  loadEmojiMenu();
});
