ItemsList = {
    ['cash'] = {
        name = 'cash',
        label = 'Nakit Para',
        weight = 0,
        stack = true,
        close = false,
        description = 'Kişisel cüzdanınızdaki nakit para.',
        client = {
            image = 'cash.png'
        }
    },
    ['black_money'] = {
        name = 'black_money',
        label = 'Kara Para',
        weight = 0,
        stack = true,
        close = false,
        description = 'Kayıt dışı yasadışı nakit para.',
        client = {
            image = 'black_money.png'
        }
    },
    ['id_card'] = {
        name = 'id_card',
        label = 'Kimlik Kartı',
        weight = 50,
        stack = false,
        close = true,
        description = 'Resmi vatandaşlık ve kimlik belgeniz.',
        client = {
            image = 'id_card.png'
        }
    },
    ['driving_license'] = {
        name = 'driving_license',
        label = 'Sürücü Belgesi',
        weight = 50,
        stack = false,
        close = true,
        description = 'Resmi motorlu araç kullanma ehliyeti.',
        client = {
            image = 'certificate.png'
        }
    },
    ['carkey'] = {
        name = 'carkey',
        label = 'Araç Anahtarı',
        weight = 80,
        stack = false,
        close = true,
        description = 'Kişisel aracınıza ait uzaktan kumandalı kontak anahtarı.',
        client = {
            image = 'carkey.png'
        }
    },
    ['phone'] = {
        name = 'phone',
        label = 'Akıllı Telefon',
        weight = 190,
        stack = false,
        close = true,
        description = 'İletişim ve bankacılık işlemleri için akıllı cihaz.',
        client = {
            image = 'phone.png'
        }
    },
    ['radio'] = {
        name = 'radio',
        label = 'Telsiz',
        weight = 250,
        stack = false,
        close = true,
        description = 'Frekans üzerinden anlık sesli iletişim cihazı.',
        client = {
            image = 'radio.png'
        }
    },
    ['water'] = {
        name = 'water',
        label = 'Su',
        weight = 350,
        stack = true,
        close = true,
        description = 'Ferahlatıcı doğal kaynak suyu (%40 Susuzluk giderir).',
        client = {
            image = 'water.png',
            status = { thirst = 40 },
            usetime = 2000
        }
    },
    ['cola'] = {
        name = 'cola',
        label = 'Kola',
        weight = 330,
        stack = true,
        close = true,
        description = 'Soğuk gazlı içecek (%35 Susuzluk giderir).',
        client = {
            image = 'cola.png',
            status = { thirst = 35 },
            usetime = 2000
        }
    },
    ['sprunk'] = {
        name = 'sprunk',
        label = 'Sprunk',
        weight = 330,
        stack = true,
        close = true,
        description = 'Limon aromalı ferahlatıcı gazoz (%35 Susuzluk giderir).',
        client = {
            image = 'sprunk.png',
            status = { thirst = 35 },
            usetime = 2000
        }
    },
    ['coffee'] = {
        name = 'coffee',
        label = 'Sıcak Kahve',
        weight = 250,
        stack = true,
        close = true,
        description = 'Taze çekilmiş sıcak filtre kahve (%25 Susuzluk, %15 Enerji).',
        client = {
            image = 'coffee.png',
            status = { thirst = 25 },
            usetime = 2000
        }
    },
    ['burger'] = {
        name = 'burger',
        label = 'Hamburger',
        weight = 250,
        stack = true,
        close = true,
        description = 'Doyurucu çift köfteli hamburger (%45 Açlık giderir).',
        client = {
            image = 'burger.png',
            status = { hunger = 45 },
            usetime = 2500
        }
    },
    ['sandwich'] = {
        name = 'sandwich',
        label = 'Sandviç',
        weight = 200,
        stack = true,
        close = true,
        description = 'Taze kaşarlı ve jambonlu sandviç (%35 Açlık giderir).',
        client = {
            image = 'sandwich.png',
            status = { hunger = 35 },
            usetime = 2500
        }
    },
    ['pizza'] = {
        name = 'pizza',
        label = 'Pizza Dilimi',
        weight = 220,
        stack = true,
        close = true,
        description = 'Sıcak peynirli İtalyan pizzası (%40 Açlık giderir).',
        client = {
            image = 'pizza.png',
            status = { hunger = 40 },
            usetime = 2500
        }
    },
    ['donut'] = {
        name = 'donut',
        label = 'Donut',
        weight = 120,
        stack = true,
        close = true,
        description = 'Çikolata kaplı tatlı çörek (%20 Açlık giderir).',
        client = {
            image = 'donut.png',
            status = { hunger = 20 },
            usetime = 2000
        }
    },
    ['bandage'] = {
        name = 'bandage',
        label = 'Sargı Bezi',
        weight = 100,
        stack = true,
        close = true,
        description = 'Hafif yaralanmaları tedavi etmek için kullanılır (+25 Can).',
        client = {
            image = 'bandage.png',
            usetime = 2500
        }
    },
    ['medikit'] = {
        name = 'medikit',
        label = 'İlk Yardım Kiti',
        weight = 800,
        stack = true,
        close = true,
        description = 'Kapsamlı medikal acil müdahale çantası (+75 Can).',
        client = {
            image = 'medikit.png',
            usetime = 4000
        }
    },
    ['armour'] = {
        name = 'armour',
        label = 'Çelik Yelek',
        weight = 3000,
        stack = false,
        close = true,
        description = 'Vücudu mermilere karşı koruyan kurşungeçirmez zırh (+100 Zırh).',
        client = {
            image = 'armour.png',
            usetime = 3500
        }
    },
    ['repairkit'] = {
        name = 'repairkit',
        label = 'Tamir Kiti',
        weight = 2500,
        stack = true,
        close = true,
        description = 'Hasarlı araçları onarmak için yedek parça ve alet çantası.',
        client = {
            image = 'repairkit.png',
            usetime = 5000
        }
    },
    ['lockpick'] = {
        name = 'lockpick',
        label = 'Maymuncuk',
        weight = 150,
        stack = true,
        close = true,
        description = 'Mekanik kilitleri açmak için kullanılan hassas tel alet.',
        client = {
            image = 'lockpick.png',
            usetime = 3000
        }
    },
    ['flashlight'] = {
        name = 'flashlight',
        label = 'El Feneri',
        weight = 400,
        stack = false,
        close = true,
        description = 'Karanlık alanları aydınlatmak için yüksek lümenli fener.',
        client = {
            image = 'flashlight.png'
        }
    },
    ['backpack'] = {
        name = 'backpack',
        label = 'Sırt Çantası',
        weight = 1000,
        stack = false,
        close = true,
        description = 'Ekstra taşıma kapasitesi sağlayan dayanıklı seyahat çantası.',
        client = {
            image = 'bag.png'
        }
    },
    ['cigaret'] = {
        name = 'cigaret',
        label = 'Sigara',
        weight = 10,
        stack = true,
        close = true,
        description = 'Tütün sigarası (Stres azaltır).',
        client = {
            image = 'cigaret.png',
            usetime = 3000
        }
    },
    ['lighter'] = {
        name = 'lighter',
        label = 'Çakmak',
        weight = 30,
        stack = true,
        close = false,
        description = 'Gazlı cep çakmağı.',
        client = {
            image = 'lighter.png'
        }
    },

    ['weapon_glock'] = {
        name = 'weapon_glock',
        label = 'Glock-17',
        weight = 900,
        stack = false,
        close = true,
        weaponId = 22,
        ammoType = 'ammo_pistol',
        description = 'Kompakt ve güvenilir 9mm Glock tabanca.',
        client = {
            image = 'weapon_glock.png'
        }
    },
    ['WEAPON_GLOCK'] = {
        name = 'WEAPON_GLOCK',
        label = 'Glock-17',
        weight = 900,
        stack = false,
        close = true,
        weaponId = 22,
        ammoType = 'ammo_pistol',
        description = 'Kompakt ve güvenilir 9mm Glock tabanca.',
        client = {
            image = 'weapon_glock.png'
        }
    },
    ['weapon_colt45'] = {
        name = 'weapon_colt45',
        label = 'Colt .45',
        weight = 1100,
        stack = false,
        close = true,
        weaponId = 22,
        ammoType = 'ammo_pistol',
        description = 'Klasik yarı otomatik hafif tabanca.',
        client = {
            image = 'WEAPON_PISTOL.png'
        }
    },
    ['weapon_silenced'] = {
        name = 'weapon_silenced',
        label = 'Susturuculu Tabanca',
        weight = 1300,
        stack = false,
        close = true,
        weaponId = 23,
        ammoType = 'ammo_pistol',
        description = 'Gizli operasyonlar için susturuculu 9mm tabanca.',
        client = {
            image = 'WEAPON_COMBATPISTOL.png'
        }
    },
    ['weapon_deagle'] = {
        name = 'weapon_deagle',
        label = 'Desert Eagle',
        weight = 1900,
        stack = false,
        close = true,
        weaponId = 24,
        ammoType = 'ammo_pistol',
        description = 'Yüksek tahribat gücüne sahip .50 kalibre ağır tabanca.',
        client = {
            image = 'WEAPON_HEAVYPISTOL.png'
        }
    },
    ['weapon_shotgun'] = {
        name = 'weapon_shotgun',
        label = 'Pompalı Tüfek',
        weight = 3400,
        stack = false,
        close = true,
        weaponId = 25,
        ammoType = 'ammo_shotgun',
        description = 'Yakın mesafede etkili 12 kalibre pompalı tüfek.',
        client = {
            image = 'WEAPON_PUMPSHOTGUN.png'
        }
    },
    ['weapon_sawnoff'] = {
        name = 'weapon_sawnoff',
        label = 'Çifte (Sawnoff)',
        weight = 2200,
        stack = false,
        close = true,
        weaponId = 26,
        ammoType = 'ammo_shotgun',
        description = 'Namlu ve dipçiği kesilmiş taşınabilir çifte.',
        client = {
            image = 'WEAPON_SAWNOFFSHOTGUN.png'
        }
    },
    ['weapon_spas12'] = {
        name = 'weapon_spas12',
        label = 'S.P.A.S-12',
        weight = 4200,
        stack = false,
        close = true,
        weaponId = 27,
        ammoType = 'ammo_shotgun',
        description = 'Yarı otomatik taktiksel av tüfeği.',
        client = {
            image = 'WEAPON_COMBATSHOTGUN.png'
        }
    },
    ['weapon_uzi'] = {
        name = 'weapon_uzi',
        label = 'Micro UZI',
        weight = 2700,
        stack = false,
        close = true,
        weaponId = 28,
        ammoType = 'ammo_smg',
        description = 'Yüksek atış hızına sahip hafif makineli tabanca.',
        client = {
            image = 'WEAPON_MICROSMG.png'
        }
    },
    ['weapon_mp5'] = {
        name = 'weapon_mp5',
        label = 'MP5',
        weight = 3100,
        stack = false,
        close = true,
        weaponId = 29,
        ammoType = 'ammo_smg',
        description = 'Hassas ve dengeli 9mm hafif makineli tüfek.',
        client = {
            image = 'WEAPON_SMG.png'
        }
    },
    ['weapon_ak47'] = {
        name = 'weapon_ak47',
        label = 'AK-47',
        weight = 4300,
        stack = false,
        close = true,
        weaponId = 30,
        ammoType = 'ammo_rifle',
        description = 'Dayanıklı 7.62mm Sovyet taarruz tüfeği.',
        client = {
            image = 'WEAPON_AK47.png'
        }
    },
    ['weapon_m4'] = {
        name = 'weapon_m4',
        label = 'M4A1',
        weight = 3600,
        stack = false,
        close = true,
        weaponId = 31,
        ammoType = 'ammo_rifle',
        description = 'Yüksek isabetli 5.56mm NATO standart taarruz tüfeği.',
        client = {
            image = 'WEAPON_CARBINERIFLE.png'
        }
    },
    ['weapon_tec9'] = {
        name = 'weapon_tec9',
        label = 'TEC-9',
        weight = 1400,
        stack = false,
        close = true,
        weaponId = 32,
        ammoType = 'ammo_smg',
        description = 'Kompakt boyutlu otomatik tabanca.',
        client = {
            image = 'WEAPON_TEC9.png'
        }
    },
    ['weapon_rifle'] = {
        name = 'weapon_rifle',
        label = 'Country Rifle',
        weight = 3800,
        stack = false,
        close = true,
        weaponId = 33,
        ammoType = 'ammo_rifle',
        description = 'Uzun menzilli kurmalı av tüfeği.',
        client = {
            image = 'WEAPON_MUSKET.png'
        }
    },
    ['weapon_sniper'] = {
        name = 'weapon_sniper',
        label = 'Sniper Rifle',
        weight = 5200,
        stack = false,
        close = true,
        weaponId = 34,
        ammoType = 'ammo_sniper',
        description = 'Dürbünlü yüksek güçlü keskin nişancı tüfeği.',
        client = {
            image = 'WEAPON_SNIPERRIFLE.png'
        }
    },
    ['weapon_bat'] = {
        name = 'weapon_bat',
        label = 'Beyzbol Sopası',
        weight = 900,
        stack = false,
        close = true,
        weaponId = 5,
        description = 'Ahşap spor sopası.',
        client = {
            image = 'WEAPON_BAT.png'
        }
    },
    ['weapon_knife'] = {
        name = 'weapon_knife',
        label = 'Av Bıçağı',
        weight = 300,
        stack = false,
        close = true,
        weaponId = 4,
        description = 'Keskin çelik avcı bıçağı.',
        client = {
            image = 'WEAPON_KNIFE.png'
        }
    },
    ['weapon_katana'] = {
        name = 'weapon_katana',
        label = 'Katana',
        weight = 1200,
        stack = false,
        close = true,
        weaponId = 8,
        description = 'Geleneksel Japon kılıcı.',
        client = {
            image = 'WEAPON_KATANAS.png'
        }
    },

    ['ammo_pistol'] = {
        name = 'ammo_pistol',
        label = 'Tabanca Mermisi',
        weight = 20,
        stack = true,
        close = false,
        description = '9mm / .45 kalibre tabanca mermisi.',
        client = {
            image = 'ammo-9.png'
        }
    },
    ['ammo_shotgun'] = {
        name = 'ammo_shotgun',
        label = 'Pompalı Fişeği',
        weight = 40,
        stack = true,
        close = false,
        description = '12 kalibre saçma fişeği.',
        client = {
            image = 'ammo-shotgun.png'
        }
    },
    ['ammo_smg'] = {
        name = 'ammo_smg',
        label = 'SMG Mermisi',
        weight = 25,
        stack = true,
        close = false,
        description = '9mm hafif makineli mermisi.',
        client = {
            image = 'ammo-smg.png'
        }
    },
    ['ammo_rifle'] = {
        name = 'ammo_rifle',
        label = 'Tüfek Mermisi',
        weight = 35,
        stack = true,
        close = false,
        description = '5.56mm / 7.62mm taarruz tüfeği mermisi.',
        client = {
            image = 'ammo-rifle.png'
        }
    },
    ['ammo_sniper'] = {
        name = 'ammo_sniper',
        label = 'Sniper Mermisi',
        weight = 60,
        stack = true,
        close = false,
        description = '.308 / .50 kalibre keskin nişancı mermisi.',
        client = {
            image = 'ammo-sniper.png'
        }
    },

    ['bread'] = {
        name = 'bread',
        label = 'Taze Ekmek',
        weight = 200,
        stack = true,
        close = true,
        description = 'Taze fırından çıkmış somun ekmek (%30 Açlık giderir).',
        client = {
            image = 'ekmek.png',
            status = { hunger = 30 },
            usetime = 2000
        }
    },
    ['hamburger'] = {
        name = 'hamburger',
        label = 'Hamburger',
        weight = 280,
        stack = true,
        close = true,
        description = 'Nefis çift köfteli hamburger (%45 Açlık giderir).',
        client = {
            image = 'hamburger.png',
            status = { hunger = 45 },
            usetime = 2500
        }
    },
    ['taco'] = {
        name = 'taco',
        label = 'Taco',
        weight = 220,
        stack = true,
        close = true,
        description = 'Baharatlı çıtır Meksika tacosu (%35 Açlık giderir).',
        client = {
            image = 'buritto.png',
            status = { hunger = 35 },
            usetime = 2500
        }
    },
    ['fries'] = {
        name = 'fries',
        label = 'Patates Kızartması',
        weight = 180,
        stack = true,
        close = true,
        description = 'Tuzlu altın sarısı patates kızartması (%25 Açlık giderir).',
        client = {
            image = 'fries.png',
            status = { hunger = 25 },
            usetime = 2000
        }
    },
    ['chocolate'] = {
        name = 'chocolate',
        label = 'Çikolata',
        weight = 100,
        stack = true,
        close = true,
        description = 'Sütlü enerji çikolatası (%20 Açlık, %15 Enerji).',
        client = {
            image = 'chocolate.png',
            status = { hunger = 20 },
            usetime = 1800
        }
    },
    ['sprite'] = {
        name = 'sprite',
        label = 'Sprite Gazoz',
        weight = 330,
        stack = true,
        close = true,
        description = 'Limon aromalı soğuk kutu gazoz (%35 Susuzluk giderir).',
        client = {
            image = 'sprite.png',
            status = { thirst = 35 },
            usetime = 2000
        }
    },
    ['orange_juice'] = {
        name = 'orange_juice',
        label = 'Portakal Suyu',
        weight = 300,
        stack = true,
        close = true,
        description = 'Taze sıkılmış C vitamini deposu portakal suyu (%40 Susuzluk giderir).',
        client = {
            image = 'orange_juice.png',
            status = { thirst = 40 },
            usetime = 2000
        }
    },
    ['milkshake'] = {
        name = 'milkshake',
        label = 'Milkshake',
        weight = 350,
        stack = true,
        close = true,
        description = 'Çilekli buzlu milkshake (%35 Susuzluk, %20 Açlık).',
        client = {
            image = 'milkshake.png',
            status = { thirst = 35, hunger = 20 },
            usetime = 2500
        }
    },
    ['icetea'] = {
        name = 'icetea',
        label = 'Soğuk Çay',
        weight = 330,
        stack = true,
        close = true,
        description = 'Şeftali aromalı serinletici buzlu çay (%35 Susuzluk giderir).',
        client = {
            image = 'icetea.png',
            status = { thirst = 35 },
            usetime = 2000
        }
    },
    ['energy_drink'] = {
        name = 'energy_drink',
        label = 'Enerji İçeceği',
        weight = 250,
        stack = true,
        close = true,
        description = 'Yoğun tempolu günler için yüksek kafeinli enerji içeceği (%30 Susuzluk, +Hız).',
        client = {
            image = 'enerji_icecegi.png',
            status = { thirst = 30 },
            usetime = 2000
        }
    },
    ['coconut_drink'] = {
        name = 'coconut_drink',
        label = 'Hindistan Cevizi Suyu',
        weight = 400,
        stack = true,
        close = true,
        description = 'Doğal hindistan cevizi kabuğunda tropikal ferahlık (%45 Susuzluk giderir).',
        client = {
            image = 'irishpub_coconut_drink.png',
            status = { thirst = 45 },
            usetime = 2200
        }
    },
    ['lemonade'] = {
        name = 'lemonade',
        label = 'Taze Limonata',
        weight = 300,
        stack = true,
        close = true,
        description = 'Nane yapraklı ev yapımı soğuk limonata (%40 Susuzluk giderir).',
        client = {
            image = 'limonata.png',
            status = { thirst = 40 },
            usetime = 2000
        }
    },
    ['beer'] = {
        name = 'beer',
        label = 'Bira',
        weight = 400,
        stack = true,
        close = true,
        description = 'Soğuk şişe arpa birası (%25 Susuzluk).',
        client = {
            image = 'beer.png',
            status = { thirst = 25 },
            usetime = 2500
        }
    },
    ['wine'] = {
        name = 'wine',
        label = 'Şarap',
        weight = 500,
        stack = true,
        close = true,
        description = 'Kaliteli yıllanmış kırmızı şarap (%25 Susuzluk).',
        client = {
            image = 'wine.png',
            status = { thirst = 25 },
            usetime = 2500
        }
    },

    ['drill'] = {
        name = 'drill',
        label = 'El Matkabı',
        weight = 2000,
        stack = false,
        close = true,
        description = 'Şarjlı taşınabilir profesyonel montaj matkabı.',
        client = {
            image = 'drill.png'
        }
    },
    ['cutter'] = {
        name = 'cutter',
        label = 'Kablo Kesici',
        weight = 450,
        stack = false,
        close = true,
        description = 'Ağır hizmet tipi çelik tel ve kilit kesici pense.',
        client = {
            image = 'cutter.png'
        }
    },
    ['laptop'] = {
        name = 'laptop',
        label = 'Dizüstü Bilgisayar',
        weight = 1800,
        stack = false,
        close = true,
        description = 'Yüksek performanslı taşınabilir bilgisayar.',
        client = {
            image = 'laptop.png'
        }
    },
    ['tablet'] = {
        name = 'tablet',
        label = 'Tablet',
        weight = 600,
        stack = false,
        close = true,
        description = 'Dokunmatik ekranlı mobil tablet cihazı.',
        client = {
            image = 'tablet.png'
        }
    },
    ['camera'] = {
        name = 'camera',
        label = 'Fotoğraf Makinesi',
        weight = 500,
        stack = false,
        close = true,
        description = 'Yüksek çözünürlüklü dijital fotoğraf makinesi.',
        client = {
            image = 'camera.png'
        }
    },
    ['headphones'] = {
        name = 'headphones',
        label = 'Kulaklık',
        weight = 350,
        stack = false,
        close = true,
        description = 'Mikrofonlu gürültü önleyici kafaüstü kulaklık.',
        client = {
            image = 'headset.png'
        }
    },
    ['cable'] = {
        name = 'cable',
        label = 'Şarj Kablosu',
        weight = 100,
        stack = true,
        close = false,
        description = 'Evrensel hızlı veri ve şarj aktarım kablosu.',
        client = {
            image = 'cable_3d.svg'
        }
    },
    ['usb_drive'] = {
        name = 'usb_drive',
        label = 'USB Bellek',
        weight = 50,
        stack = true,
        close = false,
        description = 'Yüksek hızlı taşınabilir USB depolama birimi.',
        client = {
            image = 'usb_device.png'
        }
    },
    ['needle'] = {
        name = 'needle',
        label = 'Dikiş İğnesi',
        weight = 10,
        stack = true,
        close = false,
        description = 'Hassas metal dikiş ve terzi iğnesi.',
        client = {
            image = 'item_needle.png'
        }
    },
    ['wrist_watch'] = {
        name = 'wrist_watch',
        label = 'Kol Saati',
        weight = 120,
        stack = false,
        close = false,
        description = 'Şık analog metal kordonlu kol saati.',
        client = {
            image = 'saat.png'
        }
    },
    ['newspaper'] = {
        name = 'newspaper',
        label = 'Gazete',
        weight = 150,
        stack = true,
        close = false,
        description = 'Günlük Los Santos yerel haber gazetesi.',
        client = {
            image = 'item_newspaper.png'
        }
    },
    ['bag'] = {
        name = 'bag',
        label = 'Spor Çanta',
        weight = 400,
        stack = false,
        close = true,
        description = 'Geniş hacimli fermuarlı omuz çantası.',
        client = {
            image = 'bag.png'
        }
    },
    ['belt'] = {
        name = 'belt',
        label = 'Deri Kemer',
        weight = 200,
        stack = false,
        close = false,
        description = 'Klasik tokalı hakiki siyah deri kemer.',
        client = {
            image = 'cat_fashion.png'
        }
    },
    ['sunglasses'] = {
        name = 'sunglasses',
        label = 'Güneş Gözlüğü',
        weight = 80,
        stack = false,
        close = false,
        description = 'UV filtreli polarize şık güneş gözlüğü.',
        client = {
            image = 'gozluk.png'
        }
    },
    ['sneakers'] = {
        name = 'sneakers',
        label = 'Spor Ayakkabı',
        weight = 600,
        stack = false,
        close = false,
        description = 'Hafif ve kaymaz tabanlı koşu ayakkabısı.',
        client = {
            image = 'ayakkabi.png'
        }
    },
    ['pearl_necklace'] = {
        name = 'pearl_necklace',
        label = 'İnci Kolye',
        weight = 100,
        stack = false,
        close = false,
        description = 'Özel işçilikli doğal beyaz inci kolye.',
        client = {
            image = 'incikolye.png'
        }
    },
    ['postcards'] = {
        name = 'postcards',
        label = 'Kartpostal Seti',
        weight = 50,
        stack = true,
        close = false,
        description = 'Los Santos manzaralı hatıra kartpostalları.',
        client = {
            image = 'cat_souvenirs.png'
        }
    },
    ['seashell'] = {
        name = 'seashell',
        label = 'Deniz Kabuğu',
        weight = 150,
        stack = true,
        close = false,
        description = 'Okyanus sahilinden toplanmış dekoratif kabuk.',
        client = {
            image = 'anemone.png'
        }
    },
    ['city_mug'] = {
        name = 'city_mug',
        label = 'Kupa Bardak',
        weight = 300,
        stack = false,
        close = false,
        description = 'Porselen seramik kahve kupası.',
        client = {
            image = 'coffee.png'
        }
    },
    ['notebook'] = {
        name = 'notebook',
        label = 'Not Defteri',
        weight = 250,
        stack = false,
        close = false,
        description = 'Çizgili sert kapaklı günlük kayıt defteri.',
        client = {
            image = 'cat_office.png'
        }
    },
    ['briefcase'] = {
        name = 'briefcase',
        label = 'Evrak Çantası',
        weight = 1500,
        stack = false,
        close = true,
        description = 'Şifreli kilitli deri yönetici evrak çantası.',
        client = {
            image = 'WEAPON_BRIEFCASE.PNG'
        }
    },
    ['digiscanner'] = {
        name = 'digiscanner',
        label = 'Dijital Tarayıcı',
        weight = 400,
        stack = false,
        close = true,
        description = 'Optik el tarama ve doküman cihazı.',
        client = {
            image = 'WEAPON_DIGISCANNER.png'
        }
    }
}

function getItemsList()
    return ItemsList
end