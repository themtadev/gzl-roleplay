# GZL sunucu güvenlik katmanı

## İkinci incelemede kapatılan somut yollar

- Envanter addItem, nakit bakiyesini artırmadan önce kapasiteyi doğrular. Dolu envantere başarısız nakit verme artık alıcıya karşılıksız para yazmaz.
- Swap işlemi konteyner türü, gerçek slot sınırları, pozitif/tam slot, sonlu/tam adet ve aynı slota taşıma açısından doğrulanır. count=0 mevcut tüm yığını taşıma anlamını korur.
- Silah kılıfa konurken kalan mermi metadata'ya yazılır. Aynı silah slotundaki takip edilen başka silaha geçilirken de önceki silahın mermisi saklanır. Bu tam bir kalıcı mühimmat muhasebesi değildir: ölüm, bağlantı kopması ve silah/eşya transferi ayrıca ele alınmalıdır.
- Cam temizleme görevi depo yakınlığı, ekip liderliği, benzersiz/boşta ekip üyeleri ile açılır; ekip üyeleri kopyalanır. Ödeme depo yakınında ve yalnızca bir kez yapılır. Temizlik bildirimi sunucuda başlatılmış aynı pencere oturumunu ve 1–120 saniye süresini gerektirir. Görevsiz stopAnimation çağrısı oyuncunun donmasını kaldıramaz. Mini oyunun gerçekten oynandığı kanıtlanmaz; süre/mesafe/oturum denetlenir.
- Projectile event'inde saniyede 30 üstü çoğaltma diğer oyunculara gönderilmez. Yaya oyuncudan araç tipi projectile engellenir. Araç silahlarının tür/izin denetimi henüz eklenmedi. Silah sahipliği uyuşmazlığı yalnızca loglanır; ağ sıralaması nedeniyle otomatik ceza yoktur.

İkinci aşama orijinalleri `.anticheat-backup/phase2` altında. Davranış testleri: `python .anticheat-backup/test_phase2.py`. Nakit başarısızlığı/success, slot sınırları, geçersiz adet ve görevsiz unfreeze testleri geçti. 198 Lua kaynağı sözdizimi kontrolünden geçti. Oyun içi test ve canlı dağıtım yapılmadı. Cam temizleme client/server dosyaları birlikte güncellenmelidir.

Projectile iptalinin kapsamı: https://wiki.multitheftauto.com/wiki/OnPlayerProjectileCreation — diğer oyunculara oluşturulmasını engeller. Normal hasarı onPlayerDamage iptaliyle engellediğimiz iddia edilmez; bu event iptal edilemez: https://wiki.multitheftauto.com/wiki/OnPlayerDamage.

Bu resource bir Lua executor tespit motoru değildir. MTA'nın yerleşik anticheat'ini tamamlayan sunucu kontrolleridir. Aimbot, ESP, godmode, hız hilesi veya tüm event mantık açıklarının çözüldüğü iddia edilmez.

## Uygulananlar

- Auth, inventory, ATM, market, txAdmin ve vehicles içindeki doğrudan anonim remote handler'lara allowEvent kontrolü eklendi. Kontrol bağlı olduğu handler çalışmadan önce döner; cancelEvent ile diğer handler'ların duracağı varsayılmaz.
- Oyuncu başına toplam 80/s, event başına 20/s; auth event'leri 2/s. Limit aşımındaki istek işlenmez. Bu sayılar canlı yük ölçümüyle ayarlanmalıdır.
- NaN/sonsuz sayı, döngülü/aşırı derin tablo ve aşırı büyük payload reddedilir. Payload ve şifreler loglanmaz.
- Login/register kullanıcı adı ve şifre tipi/boyutu doğrulanır. Envanter use/give/drop slot ve adet değerleri pozitif tam sayı olmak zorundadır.
- Hesap/karakter kimliği, admin ve seçili para/banka alanları için server setter'larına clientChangesPolicy=deny eklendi. Yeni oyuncuda eksik admin alanları da korunur.
- Motorun geçersiz event, event eşiği, korunan veri değişimi ve beklenmedik teleport bildirimleri sunucu loguna yazılır. Oyuncu başına log aralığı 5 saniyedir. Teleport yalnızca inceleme kaydıdır; otomatik ban/kick yoktur.
- Her kare çalışan tarama, sürekli debug hook veya oyuncunun bilgisayarında dosya taraması yoktur.

## Çalıştırma

MTA server 1.6.0 r22930 veya üstü gerekir. Launcher'ın ilk fazına eklendi. Canlı sunucuya restart uygulanmadı. Bakımda tam yeniden başlatma tercih edilir; oyuncular yeniden giriş yapmalı. Elle başlatmada önce `refresh`, sonra `start gzl_anticheat`, ardından değişen resource'lar başlatılır. Anticheat çalışmıyorsa entegre remote handler'lar güvenlik gereği isteği reddeder; login/envanter de kullanılamaz.

Önceki dosyalar resources/.anticheat-backup altında. Geri almada yalnızca anticheat'i durdurmayın: entegre handler dosyalarını ve launcher ayarını da yedekten geri alın.

## Doğrulama

198 kayıtlı Lua kaynağı Lua 5.1 ile derlendi. Stub ortamında allowEvent için kimlik, NaN/sonsuz, büyük string, döngülü tablo, auth limiti, normal event limiti, pencere yenilenmesi ve saat geri dönüşü testleri geçti. MTA içinde native deny davranışı ve oynanış henüz test edilmedi.

Canlı öncesi: normal giriş/kayıt, ATM, alışveriş, envanter taşıma/verme/bırakma, admin paneli ve araç motorunu sınayın. Test hesabıyla korunan admin/para alanını değiştirmeyi deneyip sunucu değerinin değişmediğini doğrulayın. Event limitini aşan isteklerde işlem sayısının sınırlı kaldığını kontrol edin. Meşru teleportta ceza olmadığını doğrulayın.

## Kaynaklar

- https://wiki.multitheftauto.com/wiki/Script_security
- https://wiki.multitheftauto.com/wiki/SetElementData
- https://wiki.multitheftauto.com/wiki/OnPlayerTriggerEventThreshold
- https://wiki.multitheftauto.com/wiki/OnPlayerTeleport

Kalan kapsam: diğer resource event'lerinin tek tek iş kuralı denetimi, işlem atomikliği, sunucuda silah sahipliği ve hasar doğrulaması, hareket muafiyetleri ve canlı yük testleri. Bu katman bütün hileleri engelleme garantisi vermez.
