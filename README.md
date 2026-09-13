# 🏙️ GZL Roleplay v1.0 — Tam Taşınabilir MTA:SA Altyapısı

Selamlar beyler, Script Dünyam ailesi için uzun süredir üzerinde uğraşıp toparladığım **GZL Roleplay v1.0** paketini sonunda GitHub\'da açık kaynak olarak paylaşıyorum. 

Piyasadaki yarım yamalak, içi açık ve hata dolu paketlerden bıktığım için baştan aşağı elden geçirdim. En güzel yanı da **XAMPP, MySQL, Navicat vs. kurmakla hiç uğraşmıyorsunuz.** Tamamen taşınabilir SQLite altyapısına çevirdim; indirip çift tıklıyorsunuz ve sunucu anında açılıyor.

---

### 🔥 Pakette Neler Var? (Kısaca Özet)

- **Tak & Çalıştır (Sıfır MySQL Derdi):** Veritabanı dosya tabanlı (SQLite). Kurulum derdi yok, import hatası yok.
- **Akıllı Launcher:** Scriptler kafasına göre açılıp birbirini patlatmasın diye 6 aşamalı sıralı boot motoru yazdım. Çekirdekten arayüze sırayla sorunsuz ayağa kalkıyor.
- **Güvenlik & Anticheat:** Piyasada bilinen remote event açıkları, para bugları ve meşhur GPS spawn açığı kapatıldı. Element data manipülasyonu engelli, loglar temiz.
- **OX-Style CEF Envanter:** FiveM\'deki OX envanter mantığında; sürükle-bırak, ağırlık sistemi ve yere atılan eşyaların 3D dünya modelleri var.
- **FiveM Tarzı Karakter Oluşturucu:** Girişte yüz hatları, saç, sakal, kıyafet seçebildiğiniz sinematik stüdyo ekranı.
- **txAdmin DX (v6.0.2):** Adminler için oyun içi tam kapsamlı yönetim paneli (izleme, dondurma, ışınlanma, araç tamiri vs.).
- **Dolu Dolu Meslekler & Birlikler:**
  - Polis Departmanı (LSPD tablet, ceza/sabıka kaydı, kelepçe)
  - EMS (Sedye, yaralanma/koma çarkı, ilk yardım)
  - Benny\'s Mekanik, Taksi Boss mesleği, Gökdelen Cam Temizleme ve Casino (Blackjack).
- **Dinamik Araç & İstasyon:** Benzinlik işletmeciliği, gerçekçi yakıt tüketimi, vale sistemi, dinamik direksiyon açısı ve NextGen araç sesleri.
- **Cylex Akıllı Telefon:** Rehber, SMS, Twitter, Dark Web, kamera ve fotoğraf sistemi.
- **GTA V Minimap:** Dairesel minimap, blip sistemi ve canlı GPS navigasyonu.

---

### 🎮 Oyun İçi Tuşlar

| Tuş | İşlev | Açıklama |
| :--- | :--- | :--- |
| **F1** | **Akıllı Telefon** | Telefonu açar/kapatır (/telefon) |
| **F2** veya **I** | **Envanter** | OX-Style CEF envanter ekranını açar |
| **Page Up** | **txAdmin** | Yönetici panelini açar (Admin yetkisi gerektirir) |
| **M** | **İmleç (Mouse)** | Fare imlecini açar/kapatır (/cursor) |
| **J** | **Araç Motoru** | Aracın motorunu çalıştırır veya durdurur |
| **X** | **Eller Yukarı** | Teslim olma animasyonunu tetikler |
| **V** veya **Home** | **FPS Kamera** | Birinci şahıs görüş moduna geçer |
| **Sol Alt (LAlt)** | **Telsiz (PTT)** | Telsiz frekansında bas-konuş konuşması başlatır |
| **T** | **Sohbet** | CEF rol chat ekranını açar |

---

### 🚀 Nasıl Kurup Başlatacaksınız?

1. Dosyaları indirin ve bir klasöre çıkartın.
2. Klasörün içindeki **MTA Server64.exe** dosyasına çift tıklayın, launcher sırayla her şeyi açacak:
   `	ext
   [GZL Launcher] Phase 1: Core & Foundation [OK]
   [GZL Launcher] Phase 2: UI & Graphic Engine [OK]
   [GZL Launcher] Phase 3: Auth & Identity Systems [OK]
   [GZL Launcher] Phase 4: Economy, Inventory & World Systems [OK]
   [GZL Launcher] Phase 5: HUD, Radar & Communications [OK]
   [GZL Launcher] Phase 6: Custom & Addon Scripts [OK]
   `
3. Oyuna girip kendinize bir hesap açın (örneğin adınız Ahmet olsun).
4. Açık olan **siyah sunucu konsoluna** şu komutu yazın:
   `cmd
   accountadmin Ahmet 10
   `
   Bunu yazdığınız an hesabınıza direkt **Kurucu (Seviye 10)** yetkisi tanımlanır. Oyuna dönüp Page Up tuşuna basarak txAdmin\'i kullanabilirsiniz.

---

### ⚙️ Ufak Ayarlar (İsteğe Bağlı)
- **Sunucu adını değiştirmek için:** mods/deathmatch/mtaserver.conf dosyasından <servername> kısmını düzenleyin.
- **Telefon fotoğraflarını Discord\'a bağlamak için:** mods/deathmatch/resources/gzl_phone/config.lua dosyasından webhook linkinizi yapıştırın.

---

### 📜 Lisans & Teşekkür
- **Geliştirici:** thommy & GZL Development Team
- **Topluluk & Destek:** Script Dünyam Discord Sunucusu

Paketteki tüm dosyalar temizlendi, gereksiz şişiren çöp dosyalar ayıklandı. İndirip kurcalayın, sunucu açacaklara ya da sistem sökmek isteyenlere şimdiden hayırlı olsun. Sorunuz veya öneriniz olursa yorumlarda belirtin, duruma göre güncelleme atarız! 👑
