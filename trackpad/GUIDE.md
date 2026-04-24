# Trackpad Tuning — Full Guide

antiX-26 (Debian trixie + libinput 1.28) üzerinde touchpad / mouse hızını ve davranışını ayarlamanın uçtan uca rehberi.

## İçindekiler

1. [Arka plan — antiX 23+ ve libinput geçişi](#arka-plan)
2. [Cihaz tespiti](#cihaz-tespiti)
3. [Driver tanıma](#driver-tanıma)
4. [Property envanteri](#property-envanteri)
5. [Geçici ayarlar (xinput)](#geçici-ayarlar-xinput)
6. [Test metodolojisi](#test-methodology)
7. [Kalıcı config (xorg.conf.d)](#kalıcı-config)
8. [Alternatif persistence yolları](#alternatif-persistence)
9. [Geri alma / revert](#geri-alma)
10. [Troubleshooting](#troubleshooting)
11. [Referanslar](#referanslar)

---

## Arka plan

antiX 22 ve öncesinde trackpad config'i **synaptics** driver + **Control Centre → Mouse** GUI aracılığıyla yapılıyordu. antiX 23+ (2026 itibarıyla güncel dal) bu yolu bıraktı:

- Default driver artık **libinput** (`xserver-xorg-input-libinput` paketi).
- Synaptics paketi (`xserver-xorg-input-synaptics`) default kurulumda **yok**.
- `/etc/X11/xorg.conf.d/synaptics.conf` dosyası hâlâ durabilir ama driver yüklü olmadığı için **ignore edilir** (kafa karıştırıcı ama zararsız).
- GUI mouse config aracı **güncellenmedi** — Control Centre'daki ilgili modül 23+'da çalışmıyor ([antiX forum #reimplementing-gui-mouse-config](https://www.antixforum.com/forums/topic/reimplementing-a-gui-mouse-configuration-tool-in-antix-23/)).

Sonuç: Trackpad ayarı **sadece CLI** (`xinput`) veya **xorg.conf.d dosyası** ile yapılabilir.

---

## Cihaz tespiti

```bash
DISPLAY=:0 xinput list
```

Beklenen çıktı benzeri (ASUS L200H örneği):

```
⎡ Virtual core pointer                    id=2   [master pointer  (3)]
⎜   ↳ Virtual core XTEST pointer          id=4   [slave  pointer  (2)]
⎜   ↳ Asus TouchPad                       id=12  [slave  pointer  (2)]   ← budur
⎣ Virtual core keyboard                   id=3   [master keyboard (2)]
```

Her cihazın **id** numarası veya ismi ile bağlanabilirsin. İsim daha stabildir (USB cihazlarında id değişebilir).

**SSH üzerinden çalışırken `DISPLAY=:0` zorunlu** — aksi halde xinput "Unable to connect to X server" hatası verir.

---

## Driver tanıma

Cihaz property listesindeki prefix driver'ı ele verir:

| Property prefix | Driver | Ne anlama gelir |
|------------------|--------|-----------------|
| `libinput *` | **libinput** | Modern default (antiX 23+, çoğu Debian trixie sistemi) |
| `Synaptics *` | **synaptics** | Eski trackpad driver, antiX 22'den önce |
| `Device Accel *`, `Evdev *` | **evdev** | Generic fallback, harici USB mouse |
| `wacom *` | **wacom** | Grafik tablet/kalem |

```bash
DISPLAY=:0 xinput list-props 12 | head -5
# libinput * → libinput driver
# Synaptics * → synaptics driver
```

**ASUS L200H'de doğrulandı:** libinput 1.28.1 + `xserver-xorg-input-libinput 1.5.0`.

---

## Property envanteri

```bash
DISPLAY=:0 xinput list-props "Asus TouchPad"
```

Önemli property'ler (libinput):

| Property | Range | Varsayılan | Ne yapar |
|----------|-------|-----------|----------|
| `libinput Accel Speed` | `-1.0` … `1.0` | `0.0` | **Ana hız ayarı.** + hızlandırır, − yavaşlatır |
| `libinput Accel Profile Enabled` | `a, b, c` | `1, 0, 0` | `1 0 0`=adaptive, `0 1 0`=flat, `0 0 1`=custom |
| `libinput Tapping Enabled` | 0/1 | 0 (çoğu distro 1) | Tıkla-dokun |
| `libinput Tapping Button Mapping` | `1,0` veya `0,1` | `1,0` | `1,0`=LRM (1p=sol, 2p=sağ, 3p=orta) — önerilen |
| `libinput Natural Scrolling Enabled` | 0/1 | 0 | macOS tarzı ters scroll |
| `libinput Disable While Typing Enabled` | 0/1 | 1 | Yazarken palm-reject (başparmak workflow için kritik) |
| `libinput Scrolling Pixel Distance` | pixel | 15 | Scroll bir tık uzaklığı |
| `libinput Horizontal Scroll Enabled` | 0/1 | 1 | 2-parmak yatay scroll |
| `libinput Left Handed Enabled` | 0/1 | 0 | Sol/sağ butonları swap'la |

Property'lerin sonundaki `Default` kolonu **referans fallback** — ona yazma (xinput hata verir).

---

## Geçici ayarlar (xinput)

```bash
# Hız
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Accel Speed" 0.6

# Adaptive profile (default)
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Accel Profile Enabled" 1 0 0

# Flat profile (ivmesiz, 1:1 — grafik tasarım için)
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Accel Profile Enabled" 0 1 0

# Natural scroll aç/kapat
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Natural Scrolling Enabled" 1

# Yazarken disable
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Disable While Typing Enabled" 1
```

**Önemli:** xinput değişiklikleri **X server session'ına bağlı** — logout/reboot'ta sıfırlanır. Kalıcı yapmak için [aşağı](#kalıcı-config).

---

## Test Methodology

Hızı rastgele değiştirmek yerine **yapısal test** uygulanır. Üç kriter:

### 1. Diagonal Sweep Test (büyük hareket kontrolü)

- **İlk hareket**: Trackpad'in bir köşesinden karşı yöne sweep. İmleç nerede duruyor?
  - **Hedef**: Ekranın **yaklaşık ortasına** (%40–60 mesafe) ulaşsın.
  - **Çok az mesafe** (%20) → hız düşük, artır.
  - **Karşıya fırladı** (%90+) → hız yüksek, düşür.
- **İkinci hareket**: Ortadan karşı çapraz köşeye sweep.
  - **Hedef**: Karşı köşeye yaklaşsın (**%85–100** ulaşmak).

Bu iki sweep **aynı hızda**, **aynı mesafe parmak hareketi** ile yapılır. Hedef: trackpad'in fiziksel yarı alanını kullanarak ekranı eksiksiz kat edebilmek.

### 2. Precision Test (yakın hedefler)

Birbirine yakın iki UI elemanı seç (ör. tarayıcıda "close tab" ve "new tab" ikonları). Aralarında **tek dokunuşla** yalpalamadan geçebiliyor musun?

- **Evet** → hız kabul edilebilir.
- **Hayır, biri diğerinin üstünden uçup geçiyorum** → adaptive profile'da ivme abartılı, hızı düşür veya flat profile dene.

### 3. Comfort Test (süre)

5–10 dakika normal iş (tarayıcı + editör + dosya yönetici) yap. Bilek/başparmak kasında yorulma var mı?

- **Yorulma** → hız çok düşük, daha fazla parmak hareketi istiyor. Artır.
- **Kontrol kaybı** → hız çok yüksek. Azalt.

### Örnek iterasyon (ASUS L200H session, 2026-04-24)

```
0.5  → diagonal test: ilk hareket %50 geldi, ikinci hareket %90 geldi. İyi. Ama precision'da hafif "fırlıyor".
0.6  → diagonal test: ilk hareket %55, ikinci hareket %95. Precision daha rahat.
0.65 → diagonal test: ilk hareket %60, ama precision'da tekrar fırlıyor.
0.60 → final. Diagonal iyi + precision rahat.
```

**Anahtar:** 3–4 değer arasında **geri dön** (0.5 → 0.6 → 0.65 → 0.6). Bir yönde iterasyon sana optimum'u göstermez — iki yanına gitmelisin.

---

## Kalıcı config

**Dosya:** `/etc/X11/xorg.conf.d/30-touchpad-libinput.conf`

**Canonical içerik:** [`configs/30-touchpad-libinput.conf`](./configs/30-touchpad-libinput.conf)

```ini
Section "InputClass"
    Identifier          "touchpad"
    Driver              "libinput"
    MatchIsTouchpad     "on"
    Option "Tapping"              "on"
    Option "AccelSpeed"           "0.6"
    Option "AccelProfile"         "adaptive"
    Option "DisableWhileTyping"   "on"
    Option "NaturalScrolling"     "off"
    Option "HorizontalScrolling"  "on"
    Option "TappingButtonMap"     "lrm"
EndSection
```

Kurulum:

```bash
# Backup al (yoksa)
sudo cp -n /etc/X11/xorg.conf.d/30-touchpad-libinput.conf \
          /etc/X11/xorg.conf.d/30-touchpad-libinput.conf.bak.orig

# Yeni config'i yerleştir (REPO'DAN)
sudo cp configs/30-touchpad-libinput.conf /etc/X11/xorg.conf.d/
sudo chmod 644 /etc/X11/xorg.conf.d/30-touchpad-libinput.conf

# X session restart gerekir — en temizi logout → login
# Veya IceWM'i HUP'la (soft, bazen yetmez):
killall -HUP icewm
```

**Dosya ismi neden `30-`?** xorg.conf.d dosyaları **numerik sıra** ile yüklenir. `10-` default, `30-` user-tuning, `99-` override. Düşük numara = önce okunur, yüksek numara = sonradan override eder. `30-` tutarlı bir mid-level tuning yeri.

### SSH üzerinden sudo + dosya yazma — DİKKAT

> Bu session'da yaşadığımız hata (SESSION-LOG.md'ye de kaydedildi):

**Hatalı pattern (stdin race condition):**
```bash
cat <<EOF | sshpass -p X ssh user@host 'echo X | sudo -S tee /path/file'
...
EOF
```
Sudo prompt heredoc stdin'ini tüketir → dosya "X\n" (5 byte) kalır, bozulur.

**Doğru pattern:**
```bash
# A) scp + sudo cp (önerilen)
scp local.conf user@host:/tmp/new.conf
ssh user@host 'echo X | sudo -S true && sudo cp /tmp/new.conf /etc/X11/xorg.conf.d/'

# B) sudo cache'le, sonra yaz
ssh user@host 'echo X | sudo -S true && cat > /tmp/new.conf <<EOF
...
EOF
sudo mv /tmp/new.conf /etc/X11/xorg.conf.d/'
```

---

## Alternatif persistence

### A) xorg.conf.d (önerilen, system-wide, reboot-proof)

Yukarıdaki yol. Tüm kullanıcılara uygulanır, login manager + X server restart ile aktif.

### B) ~/.icewm/startup (per-user, hızlı iterasyon)

IceWM startup'a `xinput` komutunu eklemek. GUI session her başlarken çalıştırır.

```bash
# ~/.icewm/startup
sleep 2 && xinput set-prop "Asus TouchPad" "libinput Accel Speed" 0.6 &
```

**`sleep 2`** neden? IceWM startup, xorg'un tüm input cihazlarını probe etmesinden önce çalışabilir → xinput "device not found" hatası verir. 2 saniye yeterli.

**Dezavantaj:** session başına bir kez. Hot-plug USB mouse'u taksan etkilenmez (onun için xorg.conf.d gerekir).

### C) Desktop environment GUI (antiX 23+'da YOK)

antiX 22'de `gpointing-device-settings` vardı, 23+'da paket kaldırıldı. [Reimplementation forum tartışması](https://www.antixforum.com/forums/topic/reimplementing-a-gui-mouse-configuration-tool-in-antix-23/) hâlâ açık, topluluk henüz alternatif üretmedi.

---

## Geri alma

```bash
# Backup'tan restore
sudo cp /etc/X11/xorg.conf.d/30-touchpad-libinput.conf.bak.orig \
       /etc/X11/xorg.conf.d/30-touchpad-libinput.conf

# Veya repo'dan "minimal" versiyona dön
sudo cp configs/30-touchpad-libinput.minimal.conf /etc/X11/xorg.conf.d/30-touchpad-libinput.conf

# X restart / logout-login
```

Geçici xinput değişikliklerini anında sıfırlamak:

```bash
# Default Accel Speed = 0
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Accel Speed" 0.0
```

---

## Troubleshooting

### "Unable to connect to X server" — xinput SSH'ten çalışmıyor

```bash
DISPLAY=:0 xinput list    # :0 şart
# Hâlâ çalışmazsa:
xhost +local:$USER        # (X server tarafında, user session'da bir kez)
```

### xinput değiştirdim ama hiç etki yok

1. **Yanlış cihaz ID**'ye yazıyor olabilirsin — USB cihazlar hot-plug ile id değiştirir. **İsimle** yaz (`"Asus TouchPad"`), id ile değil.
2. xorg.conf.d dosyası **yanlış Identifier** ile libinput driver'i ezip synaptics'i zorluyor olabilir — `xinput list-props` ile prefix'e bak, hâlâ `libinput *` mi?
3. X session yeniden başlatmadın — `killall -HUP icewm` yetmez bazen, logout-login gerekir.

### Cursor zıplıyor / atlıyor

- **Palm rejection agresif**: `DisableWhileTyping` + kısa tap time. `libinput Disable While Typing Enabled 0` yaparak test et.
- **Interrupt/IRQ soruna**: `/proc/interrupts` bakarak IRQ migration yap. Atom CPU'larda X IRQ'su 0'a aşırı yüklenir. Session log'daki "IRQ 29 → CPU1" fix'ine benzer yaklaşım.

### Config yazıldı ama reboot sonrası kayboldu

1. Dosya gerçekten yazılmış mı? `ls -la /etc/X11/xorg.conf.d/` ve `wc -c` — 5 byte "asus\n" ise SSH stdin bug (yukarıda çözüm).
2. Başka bir `.conf` dosyası aynı Identifier'la ezme yapıyor olabilir — `grep -r "Identifier.*touchpad" /etc/X11/xorg.conf.d/ /usr/share/X11/xorg.conf.d/`.

### Config yazdım, trackpad hiç çalışmıyor oldu

Syntax hatası. Xorg log bak:

```bash
grep -E "libinput|touchpad|EE" /var/log/Xorg.0.log | tail -20
```

Backup'tan restore et (`sudo cp .bak.orig orig`).

---

## Referanslar

- [antiX forum — Reimplementing GUI Mouse config in antiX 23](https://www.antixforum.com/forums/topic/reimplementing-a-gui-mouse-configuration-tool-in-antix-23/) — antiX 23+'ın neden CLI-only olduğu
- [antiX forum — Touchpad sensitivity adjustments](https://www.antixforum.com/forums/topic/touchpad-sensitivity-adjustments/) — topluluk metodolojisi
- [antiX forum — Trackpad sensitivity](https://www.antixforum.com/forums/topic/trackpad-sensitivity/) — user reports
- [ArchWiki — Mouse acceleration](https://wiki.archlinux.org/title/Mouse_acceleration) — Accel Profile matematiği (adaptive vs flat vs custom)
- [ArchWiki — Libinput](https://wiki.archlinux.org/title/Libinput) — xorg.conf.d örnekleri
- [libinput documentation — Pointer acceleration](https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html) — resmi algorithmic explanation
- [Baeldung — Linux mouse sensitivity via CLI](https://www.baeldung.com/linux/mouse-sensitivity-control-cli) — giriş seviyesi rehber
- [Medium / Daniel Jordan Osborn — Linux Trackpad Settings](https://djorborn.medium.com/linux-trackpad-settings-sensitivity-and-more-f85d8882e5d3) — end-user perspective
- [Linux Hint — Xinput mouse/touchpad settings](https://linuxhint.com/change_mouse_touchpad_settings_xinput_linux/) — command cookbook
- [MX Linux forum — Overly sensitive touchpad](https://forum.mxlinux.org/viewtopic.php?f=104&t=48844&p=665723) — MX/antiX ortak driver zemini
- [Arch BBS — touchpad sensitivity + tapping](https://bbs.archlinux.org/viewtopic.php?id=234208) — eski synaptics referansı (karşılaştırma için)
