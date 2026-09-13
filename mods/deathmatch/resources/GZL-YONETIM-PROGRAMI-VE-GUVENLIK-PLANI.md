# GZL yönetim programı ve güvenlik planı

Son güncelleme: 10 Eylül 2026

## Kullanıcının istediği sonuç

GZL MTA sunucusu için güçlü bir admin altyapısı, anticheat ve bunları yöneten özel bir masaüstü programı yapılacak. Kullanıcı nickname'e veya elle yazılan oyuncu/karakter ID'sine yetki vermek istemiyor. Navicat açıp veritabanı düzenlemek yerine programdan hesap kullanıcı adıyla arayıp yetki verebilmeli.

Kabul edilen iş sırası: **admin altyapısı → anticheat → özel program**. Admin tarafı bitmeden kullanıcının isteğiyle anticheat'e geçildi; admin tarafındaki kalan işler unutulmamalı.

Program henüz geliştirilmedi. Aşağıdaki teknoloji ve ekran tercihleri önerilen tasarımdır; tamamlanmış özellikler değildir.

## Program kullanıcıya nasıl görünecek?

Windows üzerinde çalışan, Türkçe, koyu temalı, okunaklı bir masaüstü uygulaması. GZL renkleri ve mevcut oyun arayüzüyle uyumlu tasarım. Ana ekran gereksiz grafiklerle dolmayacak.

Sol menü:

1. Genel durum
2. Oyuncular ve hesaplar
3. Yetkili yönetimi
4. Anticheat olayları
5. Cezalar
6. İşlem geçmişi
7. Ayarlar

### Giriş

- Oyun hesabından ayrı yönetim hesabı ile giriş.
- Parola + TOTP iki aşamalı doğrulama.
- Kısa ömürlü erişim oturumu, iptal edilebilir yenileme oturumu.
- Oturum listesi ve diğer cihazlardan çıkış.
- Başarısız girişlerde hız sınırı; parolalar ve token'lar loglanmaz.
- İlk kurucu hesabı yalnızca sunucuda yerel kurulum işlemiyle oluşturulur. İnternete açık kurucu oluşturma endpoint'i olmaz.
- Uygulama dosyasına ortak yönetici şifresi, veritabanı parolası veya kalıcı API anahtarı gömülmez.

### Genel durum

- Sunucu erişilebilir mi, oyuncu sayısı, çalışma süresi.
- Admin ve anticheat servislerinin gerçekten çalışıp çalışmadığı.
- Son önemli güvenlik olayları ve bekleyen incelemeler.
- Bağlantı kopuksa açıkça gösterilir; eski veri canlıymış gibi sunulmaz.
- Anticheat'in mevcut kapsamı dürüstçe gösterilir. “Yüzde 100 koruma” etiketi kullanılmaz.

### Oyuncular ve hesaplar

- Hesap kullanıcı adıyla arama; çevrimdışı hesaplar da bulunabilir.
- Sonuçlarda hesap adı, karakter adı, çevrimiçi durumu ve mevcut rol.
- Benzer isimlerde yanlış kişiye işlem yapılmaması için hesap oluşturulma tarihi gibi ayırt edici bilgiler.
- Profilde ceza geçmişi, yönetim işlemleri ve ilgili anticheat olayları.
- Nickname değişikliği yetkiyi etkilemez. Kullanıcıya ID yazdırılmaz; arka planda kayıtlar sabit hesap anahtarıyla ilişkilendirilir.
- Serial/IP yalnızca ihtiyaç duyan rollere gösterilir. Serial tek başına kimlik doğrulama veya kesin suç kanıtı sayılmaz.

### Yetkili yönetimi

Akış: hesabı ara → hesabı seç → mevcut rolü gör → yeni rolü seç → gerekçe yaz → değişikliği onayla.

- Önerilen roller: Destek, Moderatör, Admin, Yönetici, Kurucu.
- Rol adları ve ayrıntılı izin matrisi uygulamaya başlamadan netleştirilecek.
- Yetki verme, düşürme ve kaldırma işlemleri kalıcı kaydedilir.
- Eşit/üst rütbeyi değiştirme ve kendini yükseltme engellenir.
- Kurucu atama sıradan yetki ekranından yapılamaz; ayrı korunan kurulum/kurtarma prosedürü gerekir.
- Hassas değişikliklerde tekrar TOTP istenir.
- Yetki kaldırılınca açık oyun oturumuna yansır; eski panel açık kalsa bile sunucu işlemi reddeder.
- `/aduty` ve görev geçmişi planlanıyor; henüz uygulanmadı.
- Yetki geçmişinde kim, hangi hesabı, hangi rolden hangi role, ne zaman ve hangi gerekçeyle değiştirdi görünür.

### Anticheat olayları

- Kategoriler: yetki/veri değiştirme girişimi, event spam, geçersiz payload, ekonomi ihlali, silah/projectile tutarsızlığı, hareket şüphesi.
- Her olayda zaman, oyuncu hesabı, kural kodu, kural sürümü, sunucunun gözlemleri, uygulanan işlem.
- Durumlar: yeni, inceleniyor, doğrulandı, yanlış pozitif, kapatıldı.
- “Engellenen işlem” ile “yalnızca şüpheli davranış” ayrı gösterilir.
- Oyuncu bazında zaman çizelgesi; tekrarlanan olaylar gruplanır.
- Bir client bildirimi tek başına otomatik ban gerekçesi olmaz.
- Mevcut kayıtlar sadece sunucu logunda; aranabilir kalıcı olay deposu henüz yapılmadı.

### Cezalar

- Uyarı, kick, süreli ban, kalıcı ban, ban kaldırma.
- Yetki ve rütbe kontrolü API'de ve MTA tarafında yapılır.
- Gerekçe ve varsa kanıt/olay bağlantısı zorunlu.
- Ban kaldırma da ayrı bir denetim kaydı üretir.
- İşlem tekrar gönderildiğinde iki kez uygulanmaması sağlanır.

### Ayarlar

- API bağlantısı, yönetim oturumları, bildirim tercihleri.
- Kural bazında log/engelleme/ceza modu; değişiklikler sürümlenir ve kaydedilir.
- Anticheat'i topluca kapatan sıradan bir buton bulunmaz.
- Keyfî Lua çalıştırma, SQL yazma, shell veya sınırsız sunucu konsolu ekranı bulunmaz.
- Resource işlemleri eklenirse yalnızca açıkça izin verilen resource/işlem listesi kullanılır.

## Önerilen mimari

**Windows uygulaması → HTTPS yönetim API'si → kalıcı işlem kuyruğu → MTA sunucu köprüsü**

- Öneri: Tauri + React + TypeScript masaüstü arayüz; TypeScript tabanlı API ve PostgreSQL yönetim veritabanı. Teknoloji seçimi kesinleştirilmedi, bağımlılıklar kurulmadı.
- Masaüstü uygulama oyun veritabanına doğrudan bağlanmaz.
- API kullanıcı ve rol doğrulamasını yapar, işlemi kaydeder.
- MTA köprüsü sunucu tarafında doğrulanmış, kısa süreli, türü ve parametreleri sınırlı işleri alır; sonucu API'ye bildirir.
- Başlangıçta MTA'nın dışarı doğru HTTPS ile kuyruk sorgulaması tercih edilebilir. Sunucunun Lua çalıştırma arayüzü internete açılmaz.
- Her iş: benzersiz işlem ID'si, işlem türü, hedef hesap anahtarı, parametreler, oluşturan yönetici, oluşturulma/sona erme zamanı.
- İşlenmiş ID'ler kalıcı tutulur; tekrar gönderim aynı sonucu döndürür.
- Yetki değişimi veritabanında başarılı olmadan program “başarılı” göstermez.
- Servis bağlantısı koparsa yetki verme başarısız/askıda gösterilir. Güvensiz bir “yerel fallback” ile yetki verilmez.
- MTA köprü kimliği, TLS doğrulaması, anahtar rotasyonu ve replay engeli tasarımda tamamlanmalı.
- Uygulama token'ları mümkünse Windows Credential Manager gibi işletim sistemi korumalı depoda saklanır.

### Yönetim veri modeli önerisi

- `management_users`: yönetim kullanıcıları ve parola hash'i.
- `management_sessions`: iptal edilebilir oturumlar.
- `roles`, `permissions`, `role_permissions`: izin matrisi.
- `account_role_assignments`: oyun hesabına rol atamaları.
- `management_jobs`: MTA'ya gönderilecek işler ve sonuçları.
- `audit_events`: yönetici işlemleri.
- `security_events`: anticheat olayları.
- `sanctions`: cezalar ve kaldırılma geçmişi.

Mevcut oyun hesabındaki `accounts.admin_level` ile yeni rol tablosu arasında tek bir yetki kaynağı seçilmeli; iki bağımsız tablo birbirini geçersiz kılmamalı. Geçiş planı ve geri dönüş hazırlanmalı.

## Şu ana kadar gerçekten yapılanlar

### Admin

- `gzl_auth/server/admin.lua`: doğrulanmış girişten doldurulan sunucu oturum tablosu; `getAdminLevel` export'u.
- Core ve txAdmin admin kontrolleri bu oturuma bağlandı. Bazı başka resource kontrolleri de taşındı; bütün legacy kontroller bitmedi.
- `accountadmin kullanıcıadı seviye` yalnızca sunucu konsolundan çalışacak şekilde eklendi. Kullanıcı bu komut konusunda endişeli; program hazır olduğunda kaldırılması veya yalnızca kurtarma aracı olarak tutulması ayrıca netleştirilmeli.
- txAdmin geçici giveAdmin yolu kapatıldı; bazı rütbe/üst rütbe kontrolleri eklendi.
- `/aduty`, tam rol matrisi ve bütün admin işlemlerinin kalıcı denetim kaydı henüz tamamlanmadı.
- Auth resource yeniden başlarsa sunucu oturumları boşalır; yeniden giriş gerekir.

### Anticheat

- `gzl_anticheat` resource'u ve launcher entegrasyonu eklendi.
- Seçili auth/inventory/ATM/market/txAdmin/vehicles remote handler'larına event sıklığı ve sınırlı payload doğrulaması eklendi. Bütün event'ler kapsanmıyor.
- Seçili hesap, admin ve ekonomi element-data alanlarında native `clientChangesPolicy="deny"` kullanıldı. Bütün alternatif anahtarlar henüz kapsanmıyor; örneğin `char:bank_money` ayrıca incelenmeli.
- Native event spam, invalid event, protected data ve teleport bildirimleri loglanıyor.
- Projectile spam ve yayadan araç tipi projectile denemelerine sınırlı engel eklendi. Silah uyuşmazlığı yalnızca loglanıyor.
- Dolu envantere nakit transferinde karşılıksız para kazanma yolu kapatıldı.
- Inventory swap slot/tür/adet ve aynı slot kontrolleri eklendi.
- Silah kılıfa koyma/yeniden kuşanma sırasında kalan mermi saklanıyor. Ölüm, çıkış, eşya transferi ve aynı silahtan çoklu eşya için tam mühimmat muhasebesi hâlâ gerekiyor.
- Cam temizleme görevinde ekip, konum, oturum ve tek ödeme kontrolleri eklendi; görevsiz stopAnimation ile unfreeze yolu kapatıldı.
- Bu sistem executor/aimbot/ESP/godmode veya bütün hız/uçma hilelerini tespit eden tamamlanmış bir ürün değildir.

### En son ACL değişiklikleri — henüz canlı doğrulanmadı

- `../acl.xml` Admin grubundan `resource.*`, `resource.gzl_radar`, `resource.gzl_chat` kaldırıldı. Everyone grubundaki resource.* normal varsayılan izin üyeliği olarak kaldı.
- Gerekli ayrıcalıklı işlevler için `GZLScoped_...` grupları eklendi: launcher start/stop, txAdmin kick/ban, radar kick, phone fetchRemote, komut yönlendiren resource'lara executeCommandHandler, GPS loadstring, ATM xmlLoadFile, core restartResource.
- Launcher'ın diğer resource'ları değiştirme erişimi yapılandırmada listelenen isimlerle sınırlandı; core yalnızca gzl_mods için erişim aldı.
- Launcher'ın değişiklik yapan export'larına dış resource çağrısını reddeden kontrol eklendi. Bu export'ların mevcut kaynaklarda çağıranı bulunmadı.
- Launcher ACL kontrolü artık Admin eklemeyi önermiyor; gereken start/stop iznini arıyor.
- Core `/restartres` seviye 5+ ve yalnızca gzl_mods olacak şekilde daraltıldı.
- Varsayılan admin/admin2/webadmin/acpanel resource üyelikleri ve mevcut kullanıcı üyelikleri korundu. Bunlar ayrıca incelenmeli.
- ACL dosyası diskte değişti. Canlı ACL reload, sunucu restart veya oyun içi test yapılmadı. Çalışan sunucunun ACL kaydı diskteki değişiklikleri ezebilir; uygulama prosedürü ayrıca ele alınmalı.
- ACL düzenleme betiğinin ilk denemesi UTF-8 okuma hatasıyla dosyayı yazmadan durdu; ikinci deneme tamamlandı.

## Son taramada bulunan KRİTİK açık — henüz düzeltilmedi

`gps/gps.lua` içinde `allowedRPC` listesinde **spawnPlayer** var. `onServerCall` ve `onServerCallback` istemciden isim/parametre alıp `_G[fnName](...)` çağırıyor. Mevcut handler'larda çağıran doğrulaması, hedef yetkisi ve uygun parametre kontrolü yok.

**Sonraki teknik adım:** bu generic RPC'den spawnPlayer'ı kaldır; yalnızca gerekli rota fonksiyonlarını açık bir dispatch tablosuyla kullan; client kimliği, payload, koordinat/node tipi ve hesaplama sıklığını doğrula. Cevabı istemcinin seçtiği source yerine gerçek client'a gönder. `gps/util.lua` çağrı sözleşmesini bozmadan test et. Bu bulgu kullanıcı program planını istediği için henüz kodda düzeltilmedi.

## Devam sırası

1. GPS RPC açığını kapat ve saldırı regresyon testi yaz.
2. Son ACL XML/izin farklarını doğrula; Lua syntax ve launcher/export/core davranış testlerini çalıştır. Özel scriptlerin ihtiyaçları statik tarandı fakat canlı yetki reddi testi yapılmadı.
3. Legacy ACL/element-data admin kontrollerini bitir. Komut yönlendirme ve resource export'larının başka yetkilere dolaylı erişim vermediğini incele.
4. Tüm ekonomik işlemleri tekrar gönderim, negatif/kesirli sayı, kapasite ve başarısız yazım açısından denetle.
5. Silah/mermi sahipliğini server-side kayıtla tut; transfer, ölüm, çıkış, yeniden giriş senaryolarını çöz.
6. Hareket/hasar kurallarını canlı ölçümle geliştir; meşru admin hareketleri için sunucunun verdiği süreli muafiyetler tasarla. İstemciden muafiyet alınmaz.
7. Yapılandırılabilir, kalıcı ve oranı sınırlı güvenlik olay deposu kur.
8. Admin sistemi ve AC testleri oturduktan sonra yönetim API'si ve masaüstü uygulamasına başla.

## Test ve kabul ölçütleri

- Sahte admin element data yetki sağlamaz.
- Normal hesap admin event'i çalıştıramaz; eşit/üst rütbe koruması geçerlidir.
- Yetki kaldırma açık oturumda uygulanır.
- Aynı ekonomi/ödül işleminin tekrarı ekstra para/eşya üretmez.
- İşlem başarısızsa bakiye ve envanter birlikte değişmeden kalır.
- Silahı çıkar/koy, değiştir, ver, öl, çık/gir döngülerinde mermi üretilmez.
- Launcher'a başka resource üzerinden yetkisiz başlat/durdur yaptırtılamaz.
- GPS event'iyle oyuncu spawn/teleport ettirilemez.
- Lag, meşru teleport, araç silahı ve normal yoğun kullanım yanlış ban üretmez.
- API aynı işi tekrar gönderirse yalnızca bir kez uygulanır.
- Programdan başka kullanıcı adına veya daha yüksek rolle işlem yapılamaz.
- Her önemli işlemde kullanıcıya doğru başarı/başarısızlık durumu ve denetim kaydı vardır.

## Mevcut testler ve yedekler

- `.performance/verify.py`: meta.xml'de kayıtlı Lua'ların Lua 5.1 sözdizimi kontrolü ve radar testi. Son ACL turundan ÖNCE 198 Lua kaynak kontrolü geçmişti; son ACL turundaki Lua değişikliklerinden sonra tekrar çalıştırılmalı.
- `.anticheat-backup/test_phase2.py`: nakit aktarımı yan etkisi, slot sınırları ve görevsiz unfreeze regresyon testleri.
- `.admin-backup/`: ilk admin değişikliklerinden önceki dosyalar.
- `.anticheat-backup/`: ilk AC değişikliklerinden önceki dosyalar.
- `.anticheat-backup/phase2/`: ikinci AC turunda alınan ilgili dosya yedekleri.
- `.anticheat-backup/acl-hardening/`: en son ACL, launcher ve core yedekleri; acl.xml orijinali burada.
- `gzl_anticheat/README.md`: uygulanan korumalar ve kapsam sınırları.
- Sunucu canlı testleri yapılmadı. Statik test geçmesi canlıda güvenli/uyumlu olduğu anlamına gelmez.

## Resmî başvuru kaynakları

- https://wiki.multitheftauto.com/wiki/Script_security
- https://wiki.preview.multitheftauto.com/reference/Anti_Cheat_Guide
- https://wiki.multitheftauto.com/wiki/Access_Control_List
- https://wiki.multitheftauto.com/wiki/SetElementData
- https://wiki.multitheftauto.com/wiki/OnPlayerProjectileCreation
- https://wiki.multitheftauto.com/wiki/OnPlayerDamage

Wiki'nin ana tavsiyeleri: istemciden gelen bilgiye güvenme; gerçek çağıran için client kullan; hassas kararları sunucuda ver; resource'lara en az gerekli ACL yetkisi tanımla; serial veya client-side kod gizlemeyi güvenlik garantisi sayma; bütün SD seçeneklerini körlemesine açma.
