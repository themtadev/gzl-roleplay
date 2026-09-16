# Conversion regression checks

Run from the gzl_phone resource directory:

```text
python tests/regression.py
python tests/services.py
node tests/bridge.cjs
python tests/build_locales.py
```

Python checks require `lupa` with Lua 5.1. The service suite uses isolated in-memory SQLite and a deterministic password test double. Production uses MTA bcrypt. These checks do not open or modify the live phone database.

`python tests/services.py --fixture` generates synthetic preview accounts and posts. Serve the resource locally and open `tests/preview.html`. This preview checks rendering and input; it does not simulate MTA keyboard focus, voice routing, real uploads, or all server callbacks. Test media URLs are placeholders.

Implemented coverage includes six social account services, post ownership and interactions, direct messages, Darkchat membership, gallery album persistence, mail and vehicle adapters, character isolation, bank callback races, and bridge response contracts. Turkish/English switching and persistence, Turkish label translations, hashtag suggestions/counts/exact searches, and private social notification creation/clearing are also covered. Supported operations vary by app: having an account service does not mean every feature of that app is implemented.

Before treating this conversion as production complete, verify in MTA with two characters: typing and closing the phone, signup/login/logout, cross-player posts and messages, phone calls and radio restoration, gallery capture and albums across reconnect, mail delivery, owned vehicle markers, and banking refresh. Restart gzl_phone and gzl_creator to load the edited scripts. The shader queue forward reference is fixed in the sibling creator resource.

## Remaining integration work

- Music search requires a compatible service in `Config.MusicSearchProxy`; the former Cylex endpoint rejects requests. Playback and media sharing still require working providers.
- Housing, company management, billing, racing, casino/crypto, streaming/video calls, AI, and news features have not received complete server implementations in this change.
- Social premium/paid features, reports, some search/notification operations, and Swiper matching are incomplete. Unsupported service actions return explicit errors.
- Foffy direct messages accept the UI's composite conversation IDs; other social UI-specific message contracts still need multi-client game verification.
- Legacy client-only social accounts/posts and old Darkchat member formats are not automatically migrated. Keep backups before deployment. Shared legacy photo storage is retained but no longer automatically exposed across characters; new photo cache keys are character-specific.
- Cross-resource offline bank transfers span separate databases and are not a single atomic transaction. The regression checks cover concurrent balance changes, not crashes between database writes.
- Live database files already modified in the workspace were not edited by these fixes.
