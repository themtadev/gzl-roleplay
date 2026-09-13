window.APP = {
  template: '#app_template',
  name: 'app',
  data() {
    return {
      style: CONFIG.style,
      showInput: false,
      showWindow: false,
      shouldHide: false,
      backingSuggestions: [],
      removedSuggestions: [],
      templates: CONFIG.templates,
      message: '',
      messages: [],
      oldMessages: [],
      oldMessagesIndex: -1,
      tplBackups: [],
      msgTplBackups: []
    };
  },
  destroyed() {
    clearInterval(this.focusTimer);
    window.removeEventListener('message', this.listener);
  },
  mounted() {
    post('http://chat/loaded', JSON.stringify({}));
    this.listener = (event) => {
      const item = event.data || event.detail;
      if (!item) return;
      if (typeof this[item.type] === 'function') {
        this[item.type](item);
      }
    };
    window.addEventListener('message', this.listener);
  },
  watch: {
    messages() {
      if (this.showWindowTimer) {
        clearTimeout(this.showWindowTimer);
      }
      this.showWindow = true;
      this.resetShowWindowTimer();

      const messagesObj = this.$refs.messages;
      this.$nextTick(() => {
        if (messagesObj) {
          messagesObj.scrollTop = messagesObj.scrollHeight;
        }
      });
    },
  },
  computed: {
    suggestions() {
      return this.backingSuggestions.filter((el) => this.removedSuggestions.indexOf(el.name) <= -1);
    },
  },
  methods: {
    ON_SCREEN_STATE_CHANGE({ shouldHide }) {
      this.shouldHide = shouldHide;
    },
    ON_OPEN(data) {
      this.shouldHide = false;
      this.showInput = true;
      this.showWindow = true;
      if (data && typeof data.message === 'string') {
        this.message = data.message;
      }
      if (this.showWindowTimer) {
        clearTimeout(this.showWindowTimer);
      }
      this.$nextTick(() => {
        if (this.$refs.input) {
          this.$refs.input.focus();
        }
      });
      clearInterval(this.focusTimer);
      this.focusTimer = setInterval(() => {
        if (this.$refs.input && this.showInput) {
          this.$refs.input.focus();
        } else {
          clearInterval(this.focusTimer);
        }
      }, 100);
    },
    ON_MESSAGE({ message }) {
      if (!message) return;
      this.messages.push(message);
      if (this.messages.length > 100) {
        this.messages.splice(0, this.messages.length - 100);
      }
    },
    ON_CLEAR() {
      this.messages = [];
      this.oldMessages = [];
      this.oldMessagesIndex = -1;
    },
    ON_SUGGESTION_ADD({ suggestion }) {
      if (!suggestion || !suggestion.name) return;
      const duplicateSuggestion = this.backingSuggestions.find(a => a.name === suggestion.name);
      if (duplicateSuggestion) {
        if (suggestion.help || suggestion.params) {
          duplicateSuggestion.help = suggestion.help || "";
          duplicateSuggestion.params = suggestion.params || [];
        }
        return;
      }
      if (!suggestion.params) {
        suggestion.params = [];
      }

      const remIdx = this.removedSuggestions.indexOf(suggestion.name);
      if (remIdx > -1) {
        this.removedSuggestions.splice(remIdx, 1);
      }

      this.backingSuggestions.push(suggestion);
    },
    ON_SUGGESTION_REMOVE({ name }) {
      if (this.removedSuggestions.indexOf(name) <= -1) {
        this.removedSuggestions.push(name);
      }
    },
    ON_COMMANDS_RESET() {
      this.removedSuggestions = [];
      this.backingSuggestions = [];
    },
    ON_TEMPLATE_ADD({ template }) {
      if (!template || !template.id) return;
      this.templates[template.id] = template.html;
    },
    ON_UPDATE_THEMES({ themes }) {
      if (!themes) return;
      for (const [tplId, tpl] of Object.entries(themes)) {
        if (typeof tpl === 'string') {
          this.templates[tplId] = tpl;
        }
      }
    },
    clearShowWindowTimer() {
      clearTimeout(this.showWindowTimer);
    },
    resetShowWindowTimer() {
      this.clearShowWindowTimer();
      const timeout = (CONFIG && CONFIG.fadeTimeout) ? CONFIG.fadeTimeout : 7000;
      this.showWindowTimer = setTimeout(() => {
        if (!this.showInput) {
          this.showWindow = false;
        }
      }, timeout);
    },
    keyUp() {
      this.resize();
    },
    keyDown(e) {
      if (e.which === 38 || e.which === 40) {
        e.preventDefault();
        this.moveOldMessageIndex(e.which === 38);
      } else if (e.which === 33) {
        const buf = this.$refs.messages;
        if (buf) buf.scrollTop = buf.scrollTop - 100;
      } else if (e.which === 34) {
        const buf = this.$refs.messages;
        if (buf) buf.scrollTop = buf.scrollTop + 100;
      }
    },
    moveOldMessageIndex(up) {
      if (up && this.oldMessages.length > this.oldMessagesIndex + 1) {
        this.oldMessagesIndex += 1;
        this.message = this.oldMessages[this.oldMessagesIndex];
      } else if (!up && this.oldMessagesIndex - 1 >= 0) {
        this.oldMessagesIndex -= 1;
        this.message = this.oldMessages[this.oldMessagesIndex];
      } else if (!up && this.oldMessagesIndex - 1 === -1) {
        this.oldMessagesIndex = -1;
        this.message = '';
      }
    },
    resize() {
      const input = this.$refs.input;
      if (!input) return;
      input.style.height = '5px';
      input.style.height = `${input.scrollHeight + 2}px`;
    },
    send(e) {
      const trimmed = this.message.trim();
      if (trimmed !== '') {
        post('http://chat/chatResult', JSON.stringify({
          message: trimmed,
        }));
        this.oldMessages.unshift(trimmed);
        this.oldMessagesIndex = -1;
        this.hideInput();
      } else {
        this.hideInput(true);
      }
    },
    handlePaste(e) {
      e.preventDefault();
      const clipboard = e.clipboardData || window.clipboardData;
      if (!clipboard) return;
      const text = clipboard.getData('text/plain') || clipboard.getData('text') || '';
      if (!text) return;
      const input = this.$refs.input;
      if (input) {
        const start = input.selectionStart || 0;
        const end = input.selectionEnd || 0;
        const val = this.message || '';
        this.message = val.substring(0, start) + text + val.substring(end);
        this.$nextTick(() => {
          input.selectionStart = input.selectionEnd = start + text.length;
          this.resize();
        });
      }
    },
    hideInput(canceled = false) {
      post('http://chat/chatResult', JSON.stringify({ canceled: true }));
      this.message = '';
      this.showInput = false;
      clearInterval(this.focusTimer);
      this.resetShowWindowTimer();
    },
  },
};
