window.CONFIG = {
  defaultTemplateId: 'default',
  defaultAltTemplateId: 'defaultAlt',
  templates: {
    'default': '<div class="chat-message">{0}: {1}</div>',
    'defaultAlt': '<div class="chat-message">{0}</div>',
    'print': '<pre>{0}</pre>',
    'example:important': '<h1>^2{0}</h1>'
  },
  fadeTimeout: 4000,
  suggestionLimit: 5,
  style: {
    background: 'transparent',
    width: '38%',
    height: '22%',
  }
};