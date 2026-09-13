# Envanter performans değişiklikleri

- Açık tarayıcıdaki 400 ms durdur/uyandır döngüsü, mouse dinleyicileri ve periyodik kontrol zamanlayıcısı kaldırıldı. Kapalı tarayıcı çizimi durduruluyor.
- Kapalı envantere gelen tam senkronizasyonlar Lua tarafında saklanıyor; açıldığında güncel görüntü gönderiliyor.
- Tooltip slot yanında sabitleniyor; mouse hareketinde Floating UI hesaplaması yapılmıyor.
- Sürükleme ikonunun konumu React render yerine, kare başına en fazla bir DOM transform güncellemesiyle değişiyor.
- Slot oluşturma sırasında tekrarlanan tüm eşya taraması tek indekslemeye dönüştürüldü.
- Delta karşılaştırması metadata, string slot anahtarları ve envanter başlık değişikliklerini dikkate alıyor.
- İç içe drop hedeflerinin aynı bırakmada hem taşıma hem yere atma işlemi göndermesi düzeltildi.

## Derleme

`web/build` klasöründe `npm.cmd run build` çalıştırın. Kaynak giriş `ui.html`; Vite önce `build_output` içine üretir ve başarılı çıktı aşamasında MTA'nın `meta.xml` içinde kullandığı `index.html` ve iki asset dosyasını günceller. Kaynak TSX değişiklikleri sonraki derlemelerde korunur.

Değişiklik öncesi dosyalar `performance-backup` klasöründedir.

### Görünüm düzeltmesi

İlk derlemede projedeki eski kaynak tasarımın çalışan bundle ile eşleşmediği atlandı. Çalışan yedekteki CSS `src/design.css` içine, slot/başlık/kontrol/hotbar düzenleri TSX kaynaklarına geri taşındı. Ana giriş artık bu tasarımı ve yalnızca sürüklenen katmanı etkileyen `src/performance.css` dosyasını kullanır; `src/index.scss` aktif değildir. Orijinal karartma, renkler, ölçüler ve responsive sınıflar korunur.

`tests/design-regression.cjs`, yedek ve güncel bundle'ı aynı veriyle Chrome'da açar. 1366×768, 1920×1080 ve 2560×1440 boyutlarında hem geometri/stil değerleri hem PNG ekran görüntüleri birebir eşleşti. Çalıştırma: `CODEX_NODE_MODULES` tanımlandıktan sonra `node tests/design-regression.cjs`.

## Doğrulama

TypeScript ve üretim derlemesi geçti. `tests/browser-performance.cjs`, Playwright ve kurulu Chrome ile 40 slotlu envanter, tooltip konumu, sürükleme, tek bırakma işlemi ve beş açma-kapama döngüsünü doğrular. `CODEX_NODE_MODULES` ortam değişkeni Playwright içeren node_modules klasörünü göstermelidir.

Lua test bağımlılıkları: `npm.cmd install --prefix tests/runtime`. Kaynak kökünde `node tests/client-performance.cjs` çalıştırın. MTA fonksiyonları taklit edilerek metadata deltaları, kapalı senkronizasyon, açma/kapama ve geç callback davranışı doğrulanır. Client ayrıca Lua 5.1 sözdizimi kontrolünden geçti.

## Oyun içi kontrol

### Restart / TAB yaşam döngüsü düzeltmeleri

- İstemci başlangıcı ve TAB artık sunucudan envanter ister; ilk veriyi almak için F2 gerekli değildir.
- Başlangıç mesajları React'in `uiLoaded` bildirimi sonrasında gönderilir. TAB isteği veri ve arayüz hazır olana kadar saklanır; ikinci TAB bekleyen isteği iptal eder.
- Hotbar süresi görüntülendiği anda başlar. Açık/kapalı durumu ve süre Lua tarafından yönetilir; ikinci bir React zamanlayıcısıyla yarışmaz.
- Karakter değişimi, giriş ekranı ve ölüm hotbar/ana envanteri temizler. Kapalıyken gelen slot deltaları yerel hotkey önbelleğine de uygulanır.
- F2'nin iki farklı dinleyicide işlenmesi kaldırıldı. React Escape için tek callback gönderir; I tuşu açık envanteri de kapatır.
- Progress bar başlatılamazsa eşya kullanım zamanlayıcısı başlatılmaz.

`tests/client-performance.cjs` başlangıç/TAB/veri/React hazır olma sıralarının altı permütasyonunu, bekleyen isteğin iptalini, zaman aşımı sonrası ilk TAB'ı, oturum/ölüm temizliğini ve başarısız progress bar durumunu doğrular. Tarayıcı testi de Lua'nın hotbar süresini yönetmesini ve tek Escape callback'ini kontrol eder.

Sunucu konsolunda `restart gzl_inventory` ile değişiklikleri yükleyin. Aynı sahnede kapalı/açık envanter FPS değerlerini, mouse hareketini, dolu slotlar arasında sürüklemeyi, boş alana bırakmayı, sağ tık menüsünü ve TAB hotbar akışını karşılaştırın. Testleri ekran çözünürlüğünüzde ve normal sunucu yükünde yapın.

Bu çalışma sırasında gerçek MTA istemcisinde FPS ölçümü yapılmadı. Tarayıcı testleri CEF/oyun GPU yükünü temsil etmez; yüzde iyileşme veya her cihazda sıfır takılma garantisi verilmez.
