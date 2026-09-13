Vue.component("message", {
  template: "#message_template",
  data() {
    return {};
  },
  computed: {
    textEscaped() {
      let s = this.template ? this.template : (this.templates[this.templateId] || this.templates[CONFIG.defaultTemplateId] || '{0}');

      if (this.template) {
        this.templateId = -1;
      }

      if (
        this.templateId == CONFIG.defaultTemplateId &&
        this.args && this.args.length == 1
      ) {
        s = this.templates[CONFIG.defaultAltTemplateId] || '{0}';
      }

      if (this.args && Array.isArray(this.args)) {
        s = s.replace(/{(\d+)}/g, (match, number) => {
          const argEscaped =
            this.args[number] !== undefined
              ? this.escape(this.args[number])
              : match;
          if (number == 0 && this.color && Array.isArray(this.color)) {
            return this.colorizeOld(argEscaped);
          }
          return argEscaped;
        });
      }

      return this.colorize(s);
    }
  },
  methods: {
    colorizeOld(str) {
      return `<span style="color: rgb(${this.color[0]}, ${this.color[1]}, ${this.color[2]})">${str}</span>`;
    },
    colorize(str) {
      if (!str) return '';
      // Protect existing HTML tags and only colorize text content
      return str.split(/(<[^>]*>)/g).map((part) => {
        if (part.startsWith('<') && part.endsWith('>')) {
          return part; // Leave HTML tags completely untouched!
        }
        let s = "<span>" + part + "</span>";
        // Support MTA HEX colors: #RRGGBB
        s = s.replace(/#([0-9A-Fa-f]{6})/g, (match, hex) => `</span><span style="color: #${hex}">`);
        // Support GTA / FiveM color codes: ^0 - ^9
        s = s.replace(/\^([0-9])/g, (match, color) => `</span><span class="color-${color}">`);

        const styleDict = {
          "*": "font-weight: bold;",
          _: "text-decoration: underline;",
          "~": "text-decoration: line-through;",
          "=": "text-decoration: underline line-through;",
          r: "text-decoration: none;font-weight: normal;"
        };

        const styleRegex = /\^(\_|\*|\=|\~|\/|r)(.*?)(?=$|\^r|<\/em>)/;
        while (s.match(styleRegex)) {
          s = s.replace(
            styleRegex,
            (str, style, inner) => `<em style="${styleDict[style]}">${inner}</em>`
          );
        }
        return s.replace(/<span[^>]*><\/span[^>]*>/g, "");
      }).join('');
    },
    escape(unsafe) {
      return String(unsafe)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    }
  },
  props: {
    templates: {
      type: Object,
      default: () => ({})
    },
    args: {
      type: Array,
      default: () => []
    },
    template: {
      type: String,
      default: null
    },
    templateId: {
      type: String,
      default: CONFIG.defaultTemplateId
    },
    multiline: {
      type: Boolean,
      default: false
    },
    color: {
      type: Array,
      default: false
    }
  }
});
