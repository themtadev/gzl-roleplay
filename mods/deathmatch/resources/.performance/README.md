# GZL CPU / FPS incelemesi — 2026-09-10

41 resource'un meta.xml dosyasında kayıtlı 196 Lua scripti statik olarak tarandı ve Lua 5.1 ile derlendi. Sözdizimi hatası yok. Envanter: audit.json. Bu tarama canlı CPU profili değildir; tüm scriptlerin performansının ölçüldüğü anlamına gelmez. meta.xml dışında kalan yedekler ve FiveM referans kodu değişiklik kapsamına alınmadı.

## Uygulanan değişiklikler

- gzl_radar/client/main.lua: blip listesi ve ad/ikon/renk bilgisi en fazla 100 ms aralıkla toplanır. Konumlar her karede güncellenir. Silinen ve dimension/interior değiştiren öğeler önbellekten çıkarılır. Yeni blip ve metadata değişikliği en fazla 100 ms gecikebilir.
- gzl_radar/client/main.lua ve gzl_map/client/gui.lua: menü oyuncu sayısı en fazla saniyede bir taranır; kapalıyken yeni timer çalıştırılmaz.
- gzl_animations/client/main.lua: idle durum kontrolü kare başına yerine 100 ms timer ile çalışır. Klavye olayında animasyon iptali hâlâ anlıktır; diğer durum kontrolleri en fazla 100 ms gecikebilir.
- gzl_mechanic/client/neon.lua: stream dışında kalan araçların data değişiminde neon yaratılmaz. İki marker'dan biri oluşturulamazsa diğeri temizlenir.
- gzl_atmosphere/client/materials.lua: sabit iç mekân shader değerleri yalnızca shader oluşturulduğunda gönderilir; dinamik değerler mevcut hızda güncellenir.

Orijinaller before/ altında saklandı. Geri almak için ilgili orijinal dosyayı aynı resource yoluna kopyalayın. optimize.py ilk uygulama içindir; tekrar çalıştırmayın.

## Doğrulama ve sınırlar

`python .performance/verify.py`: bütün kayıtlı Lua kaynaklarının Lua 5.1 sözdizimi kontrolü ve gerçek radar önbellek fonksiyonunun stub ortamında davranış testleri. Hareketli konum, liste tarama sayısı, silinme, dimension değişimi, süre dolması ve saatin geri gitmesi sınandı. MTA içinde sürüş, animasyon, neon ve görsel regresyon testi henüz yapılmadı. Canlı sunucuya restart uygulanmadı.

## FPS araştırması

Mevcut ../mtaserver.conf içinde fpslimit zaten 0. Bu yüzden sunucunun FPS sınırını değiştirerek ek kazanç sağlanmadı. MTA istemci sınırı ayrıca kontrol edilmeli. F8 konsolunda `fps_limit 400` ile istemci hedef sınırı denenebilir; sınır yükseltmek donanımın ürettiği FPS'yi artırmaz.

Resmî belgeler:
- https://wiki.multitheftauto.com/wiki/SetFPSLimit — modern sürümlerde 25–32767; istemci/sunucu sınırının düşüğü geçerli. Yüksek FPS'nin GTA fiziği ve bazı oyun davranışları üzerinde sorunları olabilir.
- https://wiki.multitheftauto.com/wiki/OnClientRender — render handler'ları her karede çalışır; FPS yükseldikçe aynı mantığın saniyedeki maliyeti artar.

200 FPS = 5 ms/kare, 300 FPS = 3,33 ms/kare, 400 FPS = 2,5 ms/kare. 200'den 400'e çıkmak toplam kare süresini yarıya indirmeyi gerektirir. Script CPU'su dışında GPU, model/texture yükü, shader'lar ve GTA motorunun maliyeti de belirleyicidir. Bu değişiklikler için ölçülmüş FPS kazancı iddiası yoktur.

## Oyunda A/B ölçümü

1. gzl_rescpu çalışırken aynı konum, kamera, çözünürlük, FPS sınırı ve benzer oyuncu/araç yoğunluğu kullanın. Yüklemeler bittikten sonra başlayın.
2. Orijinal dosyalarla `/perfbench once` çalıştırın; 30 saniyelik sonucu F8'den kaydedin.
3. Değişiklikleri yükleyip ilgili resource'ları yeniden başlatın; aynı sahnede `/perfbench sonra` çalıştırın.
4. Ortalama FPS yanında p99 kare süresini karşılaştırın. En az üç eşleştirilmiş deneme yapın. Oyun penceresi odak dışına çıkarsa ölçüm iptal edilir.
5. Kalabalık araç alanı, casino, ATM, açık harita ve karakterin boşta kaldığı sahneleri ayrı sınayın. Araç neonunun stream dışına çıkıp geri dönmesini ve farklı interior/dimension geçişlerini kontrol edin.

Yeni optimizasyon öncelikleri canlı resource CPU profiline göre belirlenmeli; timer sıklıklarını veya fizik/kamera render işlemlerini topluca düşürmek doğru değildir.
