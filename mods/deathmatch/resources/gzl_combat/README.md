# GZL Combat — 0.1 prototip

Sunucu konsolunda `refresh`, ardından `start gzl_combat` çalıştırın.
Mevcut envanterinizden tabanca, pompalı, SMG, AK veya M4 kuşanın.
Kaynak oyuncuya silah veya mermi vermez. Kalıcı başlangıç ayarı değiştirilmedi.

## Kontroller

- Sağ fare (veya mevcut nişan tuşu): nişan.
- Sol fare: ateş; otomatik olarak nişan duruşuna geçer.
- Nişan/ateş sırasında WASD: yönlü hareket ve strafe.
- Shift + yön + nişan/ateş: yerde hızlandırılmış muharebe koşusu.
- Nişan dışında Shift + W/A/S/D: kameraya göre dairesel koşu; gövde hareket
  yönüne döner. W → W+A → A → A+S → S → S+D → D → D+W ile deneyin.
  Dönüşlerde hız korunur, çapraz basmak ek hız sağlamaz. Hız ve dönüş oranı
  config.lua içindeki circleRunSpeed/circleTurnRate ile ayarlanır.
- Q: serbest omuz kamerasını sağ/sol değiştirir (nişan kamerasını değiştirmez).
- V: yakın/orta/uzak serbest kamera; nişandayken seçilen mesafe nişan bırakılınca görünür.
- V döngüsü: yakın → orta → uzak → birinci şahıs → yakın (gzl_firstperson açıkken).
- Home: doğrudan birinci şahıs aç/kapat.
- Takla kamerası başlangıç açısını ve FOV değerini koruyarak oyuncuyu takip eder;
  kamera gövdeyle birlikte dönmez ve duvar yakınlığında mesafeyi kısaltır.
- Sağ fare + Space + A/D: sola/sağa takla. W/S ve çapraz yönler de kamera
  yönüne göre uygulanır; yönsüz Space sağa takla atar. W/S için de yönlendirilmiş
  GTA SA yan takla animasyonu kullanılır, özel ileri/geri GTA V animasyonu değildir.
  Takla 800 ms, başlangıçlar arası bekleme 1600 ms. Ateş/jump/hareket kontrolleri
  bu sırada kilitlenir ve bitince geri yüklenir; hasar bağışıklığı verilmez.
  Duvar kontrolü, ölüm/menü/araç iptali bulunur. Animasyon diğer oyunculara
  sunucuda doğrulanan sabit animasyon adlarıyla iletilir; fizik MTA senkronizasyonundadır.
  Ateş tuşu fiziksel basıldığı karede sprintten nişana geçiş başlatılır;
  mermi hızı, reload veya silahın yerel ateş aralığı atlanmaz.
- `/combat`: yerel sistemi açar/kapatır.

## Gerçek kapsam

Bu sürüm GTA V/FiveM'in birebir yeniden yazımı değildir. Serbest dolaşımda özel
omuz kamerası ve kamera çarpışma ışını kullanır. Nişan/ateş sırasında yerel GTA
kamerasına geçer: mermi yönü, mermi sayısı, şarjör, atış aralığı, hasar ve ağ
senkronizasyonu MTA üzerinden çalışır. `setPedAimTarget` yerel oyuncuda çalışmadığı
için sabit kamera altında çalışıyormuş gibi kullanılmaz.

Nişan hareketi normal ve Shift hızlarında ayrı yatay hız takibi, yumuşak hızlanma,
hızlı fren ve yön değiştirme tepkisi kullanır. Yan adım ileri hareketten, geri adım
yan adımdan daha yavaştır. Gövde genişliğinde iki yükseklikte duvar kontrolü yapılır.
Temas edilen nesne/platform üzerinde ve güçlü dış hızda yerel hareket devralır.
Shift koşusu mevcut nişan animasyonuna yatay fizik hızı uygular; özel GTA V koşu/üst
gövde animasyonu içermez. Düşme, zıplama, eğilme, reload ve özel animasyonda hız
eklenmez. Çapraz hareket normalize edilir; dikey hız korunur. Merdiven, eğim,
dar kapı ve hareketli platform davranışları oyun içinde doğrulanmalıdır.
Nişangâh gerçek GTA hedef ucuna çizilir; genişlemesi görseldir, mermi dağılımını
değiştirmez. Özel geri tepme, animasyon harmanlama ve bağımsız atış sistemi henüz yok.

## Entegrasyon

`gzl_firstperson` açıkken kamera kontrolü ona bırakılır. `gzl_core` varsayılan
yürümesi etkin oturum boyunca askıya alınır ve çıkışta geri yüklenir. Araç, su,
ölüm, menü, imleç ve yazı girişinde oturum kapanır. Başlangıçta başka bir kamera
etkinken devralmaz. Sinematik kaynakları kamera kontrolünü almadan önce
`exports.gzl_combat:setCombatEnabled(false)` çağırmalı, bitince `true` vermeli.

Silah hareket/serbest nişan/tek silah bayrakları sunucuda tüm oyunculara uygulanır;
`/combat` bunları oyuncuya özel geri almaz. `stop gzl_combat` eski değerleri geri
yükler (başka kaynak sonradan farklı değer yazmışsa onu korur). Başka silah
özelliklerini değiştiren kaynaklarla birlikte test edilmelidir. Yeni hasar eventi
veya istemcinin hedef bildirimine güvenen bir hasar yolu eklenmedi.

## Oyun içi kabul kontrolü

1. M4 ve tabancayla duvar/hedefe uzak-yakın ateş: iz ve nişangâh uyuşuyor mu?
2. Sağ fare + WASD; ardından Shift + WASD + sol fare: yön, hız, hasar ve mermi.
3. Duvar, dar kapı, eğim, merdiven; havadayken Shift: duvardan geçiş/hız fırlaması olmamalı.
4. Reload, silah değişimi, boş şarjör, pompalı ve tek/çift silah geçişleri.
5. İkinci oyuncudan bakarak mermi, hareket ve hasar senkronizasyonu.
6. Menü, sohbet, telefon, araç, ölüm, FPS kamera ve `/combat` geçişleri.
7. Kaynağı durdur/başlat: kamera, crosshair ve varsayılan yürüme geri gelmeli.

Statik testler gerçek MTA fizik ve animasyon testinin yerine geçmez.

API referansları: https://wiki.multitheftauto.com/wiki/SetWeaponProperty
ve https://wiki.multitheftauto.com/wiki/SetPedAimTarget
