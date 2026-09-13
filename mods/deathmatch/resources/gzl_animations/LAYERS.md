Kemik animasyon katmanları
=========================

Bu istemci API'si seçilen kemikleri normal yürüyüşün üzerine uygular. IFP dosyalarını değiştirmez. Telefon entegrasyonu sağ kol, el ve boynu kullanır; bacaklara dokunmaz.

```lua
exports.gzl_animations:setPedAnimationLayer(localPlayer, "my_resource:pose", {
    bones = {
        [22] = { -28.11, -50.04, -0.58 },
        [23] = { -104.52, -13.94, -0.19 }
    },
    blendTime = 350,
    priority = 30,
    weight = 1
})

exports.gzl_animations:clearPedAnimationLayer(localPlayer, "my_resource:pose", 220)
```

Açılar derece cinsinden yaw, pitch, roll sırasındadır. Büyük priority değeri aynı kemiğe en son uygulanır. Katmanlar çağıran resource'a aittir; başka bir resource aynı isimle katmanı silemez.

Araç, ölüm, su ve setPedAnimation ile başlatılmış tam vücut animasyonlarında katman uygulanmaz. Stream dışına çıkışta ve sahibi resource durduğunda temizlenir. Stream içine giren oyunculara çağıran resource tekrar uygulamalıdır. Hiç katman yokken kare başına çalışan işleyici kaldırılır.

API istemcide çalışır. Diğer oyuncuların görmesi için yalnızca poz seçimi/açık-kapalı durumu sunucudan senkronize edilmelidir; kemik açıları her karede ağ üzerinden gönderilmemelidir. Cylex entegrasyonu mevcut cylex_phone:holding verisini kullanır.

Bu katman bir tam vücut IFP animasyonunu otomatik olarak yürünebilir hâle getirmez. Yeni hareketler için ilgili kemik maskesi ve poz açıları tanımlanmalıdır.
