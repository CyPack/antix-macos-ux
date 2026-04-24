# Contextual Research — Farklı cihazlar için nasıl araştırılır

Bu repo ASUS L200H + antiX-26 + libinput senaryosu için ayarlanmış. Ama farklı bir cihaz / distro / driver / workflow ile karşılaşan bir AI agent (veya insan), **dogmatik kopyalama yapmamalı** — önce bağlamı keşfetmeli. Bu dosya o keşif yöntemini tarif eder.

## Keşfin 4 boyutu

Trackpad/mouse tuning **tek boyutlu** bir problem değil. En az 4 boyutu bağlamsal olarak ele almak gerekir:

### 1. Hardware (cihaz)

Aynı AccelSpeed farklı hardware'de çok farklı hisseder. Dikkate al:

| Boyut | Neden önemli |
|-------|--------------|
| **Fiziksel trackpad boyutu** | Küçük trackpad (11" laptop) daha yüksek hız ister; geniş trackpad (MacBook Pro) düşük hız yeter |
| **DPI / resolution** | Trackpad içindeki sensör yoğunluğu. libinput adaptive profile DPI'a duyarlı |
| **Ekran boyutu + resolution** | 4K 27" monitörde aynı `0.6` çok yavaş hissedebilir; 1366×768 11"'de hızlı |
| **External mouse vs built-in touchpad** | Tamamen farklı cihazlar, **farklı config bölümleri** gerekir |

**Keşif komutu:**
```bash
xrandr --current | head -5                   # Ekran boyutu + res
xinput list-props "DEVICE" | grep "Product"  # Cihaz kimliği
```

### 2. Driver stack

| Driver | Tespit | Config yeri |
|--------|--------|-------------|
| **libinput** (modern) | Property'ler `libinput *` ile başlar | `/etc/X11/xorg.conf.d/*.conf` Driver "libinput" |
| **synaptics** (legacy) | Property'ler `Synaptics *` | Driver "synaptics", AccelFactor/MinSpeed/MaxSpeed |
| **evdev** (fallback USB mouse) | `Device Accel Profile`, `Evdev Axis` | Driver "evdev" |
| **wacom** (tablet) | `wacom *` | Driver "wacom" |

**Aynı cihazda 2 driver conf'u varsa**: son yüklenen (yüksek dosya numarası) veya daha spesifik MatchDevicePath kazanır. Çakışma varsa `xinput list-props` prefix'i neyin etkin olduğunu söyler.

### 3. Init system / Session type

| Sistem | Persistence pattern |
|--------|---------------------|
| **X11 + IceWM** | `/etc/X11/xorg.conf.d/` + `~/.icewm/startup` |
| **X11 + systemd + GNOME/KDE** | `dconf` / `kwriteconfig5` (GUI aracı var, yukarıdakini ezebilir) |
| **Wayland** | xinput **işe yaramaz**. `gsettings` (GNOME), `kwriteconfig5` (KDE), `swaymsg input` (Sway) |
| **X11 + runit (antiX)** | `/etc/X11/xorg.conf.d/` + `~/.icewm/startup` (systemd-agnostic) |

`echo $XDG_SESSION_TYPE` → x11 veya wayland.

### 4. Kullanım profili

Bu en subjektif boyut. Optimum AccelSpeed **kişisel motor kontrole** bağlı:

| Profil | Hareket dinamiği | Önerilen band |
|--------|------------------|---------------|
| **Thumb-on-trackpad typist** | Küçük, kısa parmak hareketi, sık | `0.4` – `0.7`, adaptive |
| **Desktop külavyede + external mouse** | Orta, tuş kısayolları baskın | `0.2` – `0.5`, adaptive |
| **Grafik tasarımcı / illüstratör** | Ultra hassas, ince hareket | `-0.2` – `0.0`, **flat** |
| **Gamer (FPS)** | Ultra hızlı sweep + flick | `0.7` – `1.0`, flat veya adaptive |
| **Ileri yaş / motor hassasiyet azalmış** | Kontrol > hız | `-0.5` – `0.0`, adaptive |
| **Sunum / müşteri ziyareti — ortalama** | Dengeli | `0.3` – `0.5` |

**Profil sormak yerine davranışı gözlemle:** Kullanıcı "başparmağımla yazı yazarken kullanıyorum" diyorsa thumb-on-trackpad. "Blender'da model yaptım" diyorsa grafik tasarım.

## Araştırma workflow — yeni cihaza karşılaşan agent için

### Adım 1: Bağlamı topla (önce oku, sonra değiştir)

```bash
# Neredeyim?
uname -a                                   # Kernel + arch
cat /etc/os-release                        # Distro + versiyon
echo $XDG_SESSION_TYPE                     # x11 veya wayland
echo $DESKTOP_SESSION                      # icewm / gnome / kde / xfce / ...
dpkg -l 2>/dev/null | grep -E "libinput|synaptics|evdev" || rpm -qa | grep -E "libinput|synaptics"
```

### Adım 2: Cihazları listele

```bash
DISPLAY=:0 xinput list
```

Pointer device'lar slave pointer olarak görünür. **Touchpad ismi** çoğunlukla "TouchPad" geçer; harici mouse ismi üreticinin verdiği şey olur ("Logitech USB Mouse" vs).

### Adım 3: Driver + property dump

```bash
DISPLAY=:0 xinput list-props "DEVICE_NAME" | head -30
```

Prefix'i kontrol et:
- `libinput *` → [GUIDE.md § Geçici ayarlar (xinput)](./GUIDE.md#geçici-ayarlar-xinput)
- `Synaptics *` → [eski synaptics yolu — ArchWiki](https://wiki.archlinux.org/title/Touchpad_Synaptics)
- `Device Accel *` → evdev, `Device Accel Constant Deceleration`, `Device Accel Velocity Scaling` property'lerini kullan

### Adım 4: Test — iteratif

[GUIDE.md § Test Methodology](./GUIDE.md#test-methodology) bandını uygula:

1. **Başlangıç tahmini** (profile göre yukarıdaki tablodan).
2. **Diagonal sweep test** + **Precision test** + **Comfort test**.
3. 3–4 değer arasında **iki yönlü iterasyon** (yukarı-aşağı, yukarı-aşağı). Bir yönde kaç değer denersen dene, tek yönde iyi sonuç → bias.
4. Kullanıcı "tamam" dediği anda **durdur**. Pencere genişletme.

### Adım 5: Kalıcı yapma — OPT-IN

**Kullanıcı onayı olmadan kalıcı yapma.**

- Geçici xinput komutu → kalıcı olmayan, session'da test ediliyor.
- Kullanıcı "beğendim kalıcı yap" der → o zaman xorg.conf.d'a yaz.
- Kalıcı yapmadan önce **mevcut dosyayı backup'la** (`cp -n foo foo.bak.orig`).

### Adım 6: Dokümante et

Yapılanları işareti bırak:

- Config dosyasına **comment** ile tarih + nedense (ör. "Tuned 2026-04-24 for thumb-on-trackpad typing").
- Repo'ya **SESSION-LOG.md** entry'si ekle.
- Kullanıcıya **geri alma komutunu** söyle.

## Dikkat edilecek anti-pattern'ler

### 1. Keşif olmadan "standart" değer uygulama

`0.5` her cihazda çalışmaz. 4K monitörde `0.5` yavaştır, küçük trackpad + 1080p'de hızlı olabilir. **Önce cihazı tanı**.

### 2. Wayland ortamında xinput kullanmaya çalışma

Wayland'de xinput'un hiçbir etkisi yok. `echo $XDG_SESSION_TYPE` kontrol et. `wayland` ise compositor-specific tool kullan (`swaymsg input`, `gsettings`, `kwriteconfig5`).

### 3. Cihazı ID ile referans verme (USB mouse)

USB hot-plug ile id değişir. Her session'da farklı olur. **İsimle referans** ver:

```bash
xinput set-prop "Logitech USB Mouse" ...   # ✓ stabil
xinput set-prop 15 ...                      # ✗ kırılgan
```

### 4. Çakışan config dosyaları

`/etc/X11/xorg.conf.d/30-touchpad-libinput.conf` + `/etc/X11/xorg.conf.d/synaptics.conf` birlikte → karışıklık. Driver yüklü olanı (libinput) kazanır ama dokümantasyon için temiz tut:

```bash
# Eski synaptics config'i ortadan kaldırmak istersen
sudo mv /etc/X11/xorg.conf.d/synaptics.conf /etc/X11/xorg.conf.d/synaptics.conf.disabled
```

### 5. SSH stdin race (gerçek session hatası)

```bash
cat <<EOF | ssh host 'echo pw | sudo -S tee /path'
...
EOF
```

Sudo prompt stdin'i tüketir → heredoc içeriği `/path`'e gitmez, "pw\n" kalır (5 byte). [GUIDE.md § SSH üzerinden sudo + dosya yazma — DİKKAT](./GUIDE.md#ssh-üzerinden-sudo--dosya-yazma--dİkkat).

### 6. "Reboot et, çalışıyor" demeden doğrulama yapmama

Config yazdın → `DISPLAY=:0 xinput list-props DEVICE | grep "Accel Speed"` ile **aktif değeri** gör. Dosya yazıldı demek henüz trackpad driver'ın onu okuduğu anlamına gelmez (logout-login gerekir).

## Referanslar

- [libinput pointer acceleration docs](https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html) — profil matematiği
- [ArchWiki — Mouse acceleration](https://wiki.archlinux.org/title/Mouse_acceleration)
- [ArchWiki — Libinput](https://wiki.archlinux.org/title/Libinput)
- [ArchWiki — Touchpad Synaptics](https://wiki.archlinux.org/title/Touchpad_Synaptics) — legacy driver (karşılaştırma)
