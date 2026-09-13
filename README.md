# 🏙️ GZL Roleplay v1.0 — Tam Taşınabilir MTA:SA Altyapısı

![MTA:SA](https://img.shields.io/badge/MTA%3ASA-1.6+-blue.svg)
![Database](https://img.shields.io/badge/Database-SQLite%20(Zero--Config)-success.svg)
![Security](https://img.shields.io/badge/Anticheat-GZL%20AC%20v2-green.svg)
![License](https://img.shields.io/badge/License-MIT-orange.svg)

> **Script Dünyam & MTA Topluluğu İçin Özel Olarak Hazırlanmıştır.**  
> MySQL/XAMPP kurulumuna ihtiyaç duymadan, **tek tıkla çalıştırabileceğiniz**, 40+ optimize edilmiş resource içeren eksiksiz Türk Rol Sunucusu paketi.

---

## 🌟 Öne Çıkan Özellikler

- 🚀 **Zero-Config (Tak & Çalıştır SQLite)**: Harici MySQL, Apache veya XAMPP kurmanıza gerek yoktur. Tüm hesap, karakter, araç, envanter ve birlik veritabanları taşınabilir SQLite ile çalışır.
- ⚡ **GZL Launcher (Akıllı Sıralı Boot)**: Sunucu açıldığında resource'lar rastgele değil, 6 mantıksal aşamada (Çekirdek -> UI -> Giriş/Karakter -> Ekonomi/Envanter -> HUD/Radar -> Yan Sistemler) dependency sırasıyla başlatılır.
- 🛡️ **GZL Anticheat v2 & Sıkılaştırılmış ACL**: Remote event spam koruması, yetkisiz payload filtreleme, korumalı element-data kilidi, mermi/patlayıcı taşkın koruması ve güvenli GPS rota motoru.
- 🎒 **OX-Style CEF Envanter**: FiveM OX Inventory standartlarında sürükle-bırak eşya, ağırlık hesabı, silah durability/mermi yönetimi ve yere atılan eşyaların 3D dünya modelleri.
- 👤 **FiveM Style Karakter Oluşturucu**: Yüz hatları, saç, sakal, göz rengi, dövmeler, kıyafet varyasyonları ve sinematik giriş ekranı.
- 🛠️ **txAdmin DX (v6.0.2)**: Sunucu içi oyuncu izleme, dondurma, ışınlanma, araç tamiri, eşya verme ve godmode içeren modern arayüz.
- 🚓 **Meslekler & Birlikler**:
  - **LSPD**: Polis tableti, arama kaydı, sabıka, ceza kesme ve kelepçe sistemi.
  - **EMS**: Sedye, koma/yaralanma çarkı, nabız ölçümü ve ilk yardım.
  - **Mekanik (Benny's)**: Araç parça modifikasyonu, tamir ve bakım.
  - **Taksi Boss**: Dinamik müşteri taşıma ve taksimetre.
  - **Gökdelen Cam Temizleme**: Ekip tabanlı mini meslek oyunu.
  - **Blackjack**: Gerçekçi casino masaları ve krupiye animasyonları.
- ⛽ **Dinamik Yakıt & Araç Yönetimi**: İstasyon sahipliği, benzin pompası, vale sistemi, araç kilidi/motor fiziği, dinamik direksiyon açısı ve NextGen araç ses efektleri.
- 📱 **Akıllı Telefon (Cylex Style)**: Rehber, SMS, Twitter, Dark Web, Vale, Banka transferi, Flaş ve Kamera.
- 🗺️ **GTA V Minimap & Pause Menu**: Dairesel blip radarı, harita üzerinden rota çizimi ve anlık GPS navigasyonu.

---

## 🎮 Tuş Kombinasyonları Tablosu

| Tuş | İşlev | Açıklama |
| :--- | :--- | :--- |
| **`F1`** | **Akıllı Telefon** | Telefonu açar/kapatır (`/telefon`) |
| **`F2`** / **`I`** | **Envanter** | OX-Style CEF envanter ekranını açar |
| **`Page Up`** | **txAdmin** | Yönetici panelini açar (Admin yetkisi gerektirir) |
| **`M`** | **İmleç (Mouse)** | Fare imlecini açar/kapatır (`/cursor`) |
| **`J`** | **Araç Motoru** | Aracın motorunu çalıştırır veya durdurur |
| **`X`** | **Eller Yukarı** | Teslim olma animasyonunu tetikler |
| **`V`** / **`Home`** | **FPS Kamera** | Birinci şahıs görüş moduna geçer |
| **`Sol Alt (LAlt)`** | **Telsiz (PTT)** | Telsiz frekansında bas-konuş konuşması başlatır |
| **`T`** | **Sohbet** | CEF rol chat ekranını açar |

---

## ⚙️ Kurulum ve Sunucuyu Başlatma

### 1. Dosyaları İndirin
Paketi bilgisayarınızda veya VDS/Sunucunuzda dilediğiniz bir klasöre çıkarın (Örn: `C:\MTA-GZL`).

### 2. Sunucuyu Başlatın
Klasör içerisindeki **`MTA Server64.exe`** dosyasına çift tıklayarak çalıştırın.  
Konsol penceresi açılacak ve `gzl_launcher` otomatik olarak tüm modülleri sırasıyla yükleyecektir:
```text
[GZL Launcher] Phase 1: Core & Foundation [OK]
[GZL Launcher] Phase 2: UI & Graphic Engine [OK]
[GZL Launcher] Phase 3: Auth & Identity Systems [OK]
[GZL Launcher] Phase 4: Economy, Inventory & World Systems [OK]
[GZL Launcher] Phase 5: HUD, Radar & Communications [OK]
[GZL Launcher] Phase 6: Custom & Addon Scripts [OK]
```

### 3. Oyuna Bağlanın ve Adminlik Alın
1. MTA:SA istemcinizi açın ve `localhost` veya sunucu IP'nize bağlanın.
2. Giriş ekranından bir hesap ve karakter oluşturun (Örn: `Ahmet`).
3. **MTA Server konsoluna** gelerek şu komutu girin:
```cmd
accountadmin KullaniciAdiniz 10
```
*(Örn: `accountadmin Ahmet 10`)*  
Bu komut hesabınıza anında **Kurucu (Seviye 10)** yetkisi tanımlar. Artık oyunda `Page Up` tuşuna basarak **txAdmin** panelini kullanabilirsiniz!

---

## 🔧 İsteğe Bağlı Yapılandırmalar

- **Sunucu Adı Değiştirme**:  
  `mods/deathmatch/mtaserver.conf` dosyasını Not Defteri ile açın ve `<servername>` etiketini düzenleyin:
  ```xml
  <servername>Sunucunuzun Adı Roleplay | v1.0</servername>
  ```

- **Telefon Fotoğraf Webhook'u (Discord Entegrasyonu)**:  
  Oyuncuların oyun içi telefonla çektiği fotoğrafların Discord sunucunuza düşmesini istiyorsanız, `mods/deathmatch/resources/gzl_phone/config.lua` dosyasını açın:
  ```lua
  Config.DiscordWebhook = "https://discord.com/api/webhooks/..."
  ```

---

## 📁 Proje Dizin Yapısı

```
GZL/
├── MTA Server64.exe           # 64-bit Sunucu Çalıştırılabilir Dosyası
├── x64/                       # 64-bit Bağımlılık Kütüphaneleri & DLL'ler
└── mods/
    └── deathmatch/
        ├── mtaserver.conf     # Sunucu Ana Yapılandırma Dosyası
        ├── acl.xml            # Erişim Kontrol Listesi (ACL Yetkileri)
        ├── databases/         # Global SQLite Veritabanı
        └── resources/         # 40+ Özel Optimize Edilmiş GZL Scriptleri
            ├── gzl_launcher/  # Sıralı Fazlı Boot Motoru
            ├── gzl_anticheat/ # AC v2 Güvenlik Modülü
            ├── gzl_auth/      # Giriş & Kayıt Sistemi
            ├── gzl_creator/   # FiveM Tarzı Karakter Oluşturucu
            ├── gzl_inventory/ # OX CEF Envanter Motoru
            ├── gzl_txadmin/   # Modern DX Yönetici Paneli
            ├── gzl_phone/     # Cylex Akıllı Telefon
            └── ...
```

---

## 📜 Lisans & Emeği Geçenler

- **GZL Geliştirici Ekibi & thommy**
- **MTA:SA Açık Kaynak Topluluğu**
- Paylaşım & Destek: **Script Dünyam Discord Sunucusu**

*Keyifli roller ve bol oyuncular dileriz!*
