"""Build the bundled Turkish dictionary from reviewed translations."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = json.loads((ROOT / 'tests/locale-source.json').read_text(encoding='utf-8'))
labels, overrides = {}, {}
section = ''
for line in (ROOT / 'tests/translations-tr.txt').read_text(encoding='utf-8').splitlines():
    if line.startswith('['):
        section = line[1:-1]
    elif line:
        key, value = line.split('=', 1)
        value = value.replace('\\n', '\n')
        original = source[section][key]
        assert original.count('%s') == value.count('%s'), (section, key)
        labels[original] = value
        overrides[section, key] = value
labels.update({'Airplane Mode': 'Uçak Modu', 'Sounds & Ringtone': 'Sesler ve Zil Sesi',
               'Pet': 'Evcil Hayvan', 'Language': 'Dil'})
translated = {section: {key: overrides.get((section, key), labels.get(value, value))
                       for key, value in entries.items()} for section, entries in source.items()}
translated['settings'].update(language='Dil', about='Hakkında', wallpaper='Duvar Kâğıdı',
                              pet='Evcil Hayvan', focus='Ekran ve Parlaklık', sound='Sesler ve Zil Sesi')
def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'))
(ROOT / 'html/locales.js').write_text('window.__mtaPhoneLocales = ' + encode({'tr': translated}) +
    ';\nwindow.__mtaPhoneTurkishLabels = ' + encode(labels) + ';\n', encoding='utf-8')
print(f'PASS: {sum(map(len, translated.values()))} locale entries; format placeholders preserved')
