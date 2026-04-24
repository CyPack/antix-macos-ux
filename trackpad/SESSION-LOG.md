# Session Log — Trackpad tuning oturumları

Bu dosya trackpad ayarında yapılan her önemli müdahaleyi kronolojik olarak tutar. Yeni agent/insan buraya bakar → geçmiş iterasyonlardan öğrenir → aynı hataya düşmez.

---

## 2026-04-24 — ASUS L200H (antiX-26) ilk kalıcı tuning

### Kullanıcı isteği

> "asus antixlinuxa baglansana orda mouse/trackpad hassasiyetini yani hizini ayarlama yeri var mi acaba bir arastirma yapmani istiyorum. ayrica internetten de arastir bakalim bu konuda bir ayar var mi ogrenelim"

Ardından iteratif test:

> "%50 hizlandir bi deneyelim bakalim gecici testler yapalim optimize hizi ayarlamak icin" → 0.5
> "0.6 yapar misin" → 0.6
> "0.65 yapar misin" → 0.65
> "0.60 a dusur" → 0.6
> "tamam simdi bunu kalici hale getir..."

### Kullanıcının trackpad felsefesi (kanonik referans)

> "Benim trackpad kullanım felsefem: elimi klavyeden kaldırmadan başparmağımla trackpad'i kullanabilmek.
> Hız optimizasyon ayarım genelde:
>  - İlk hareket: ekran köşesinden ortaya yakın mesafeye.
>  - İkinci hareket: karşı çapraz köşeye yaklaşması.
> Ayrıca dikkat ettiğim şey: birbirine yakın seçenekler arasında zorlanmadan, yani mouse fırlama yapmadan rahatça kullanabildiğim bir hassasiyet ortalaması.
> Bu cihazda o yüzden deneyerek 0.6'yı uygun gördüm."

### Tanı

| | |
|---|---|
| **Cihaz** | ASUS L200H (hostname: asus-l200h) |
| **Erişim** | Tailscale: `asus@<TAILSCALE_IP>` (LAN <HOST_LAN_IP> bu session'da erişilemezdi — uzakta) |
| **OS** | antiX-26 (Debian trixie base), kernel 6.6.119-antix, IceWM 4.0.0 |
| **Session** | X11 (`$XDG_SESSION_TYPE=x11` implied) |
| **Trackpad device** | "Asus TouchPad" id=12 (`/dev/input/event0`, product 2821:257) |
| **Driver** | **libinput** 1.28.1-1 (+ `xserver-xorg-input-libinput 1.5.0`) |
| **Synaptics paketi** | **YÜKLÜ DEĞİL** — `/etc/X11/xorg.conf.d/synaptics.conf` dosyası var ama driver yüklü olmadığı için ignore ediliyor |
| **Başlangıç Accel Speed** | `0.000000` (default, kustomize edilmemiş) |
| **Profile** | adaptive (1,0,0 default) |
| **GUI tool** | YOK (antiX 23+ `gpointing-device-settings`'i kaldırdı) |

### İterasyon

| Değer | Kullanıcı geri bildirimi |
|-------|--------------------------|
| `0.5` | Denedi — "0.6 yapar mısın" (daha hızlı iste) |
| `0.6` | İyi hissetti — "0.65 yapar mısın" (hafif daha) |
| `0.65` | Fazla geldi — "0.60 a düşür" |
| `0.6` | **Final** — "tamam simdi bunu kalici hale getir" |

Bu 4-adımlık geri-dönüşlü iterasyon, [`GUIDE.md § Test Methodology`](./GUIDE.md#test-methodology) "iki yöne git" kuralının **pratik örneği** oldu.

### Yapılan işlemler

**1. Geçici test (xinput) — session üzerinde canlı:**

```bash
DISPLAY=:0 xinput set-prop 12 "libinput Accel Speed" 0.5
DISPLAY=:0 xinput set-prop 12 "libinput Accel Speed" 0.6
DISPLAY=:0 xinput set-prop 12 "libinput Accel Speed" 0.65
DISPLAY=:0 xinput set-prop 12 "libinput Accel Speed" 0.60
```

**2. Backup:**

```bash
sudo cp -n /etc/X11/xorg.conf.d/30-touchpad-libinput.conf \
          /etc/X11/xorg.conf.d/30-touchpad-libinput.conf.bak.orig
# 119 byte, original 5-satırlık minimal config (sadece Tapping=on)
```

**3. Kalıcı config yazma — ilk deneme BAŞARISIZ:**

```bash
# YANLIŞ pattern (sudo stdin race)
cat <<CFG | sshpass -p <PASSWORD> ssh asus@host 'echo <PASSWORD> | sudo -S tee /etc/X11/xorg.conf.d/30-touchpad-libinput.conf >/dev/null'
Section "InputClass"
...
EndSection
CFG
```

Sonuç: dosya **5 byte**, içerik `asus\n` (sudo password). heredoc içeriği stdin'de kayboldu.

**4. Kurtarma + doğru yaklaşım — scp + sudo cp:**

```bash
# Local'de dosyayı hazırla
cat > /tmp/30-touchpad-libinput.conf <<'CFG'
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
CFG

# scp ile gönder
sshpass -p '<PASSWORD>' scp /tmp/30-touchpad-libinput.conf asus@<TAILSCALE_IP>:/tmp/new-touchpad.conf

# sudo cache'le, sonra cp (stdin race yok)
sshpass -p '<PASSWORD>' ssh asus@<TAILSCALE_IP> \
  'echo <PASSWORD> | sudo -S true && \
   sudo cp /tmp/new-touchpad.conf /etc/X11/xorg.conf.d/30-touchpad-libinput.conf && \
   sudo chmod 644 /etc/X11/xorg.conf.d/30-touchpad-libinput.conf'
```

**5. Doğrulama:**

```bash
DISPLAY=:0 xinput list-props 12 | grep -E "Accel Speed \(|Tapping Enabled \(|Natural Scrolling Enabled \(|Disable While Typing"
# libinput Tapping Enabled (311):         1
# libinput Natural Scrolling Enabled (319): 0
# libinput Disable While Typing Enabled (321): 1
# libinput Accel Speed (333):             0.600000   ← istenen
```

### Final state

| Property | Değer | Kaynak |
|----------|-------|--------|
| `libinput Accel Speed` | `0.6` | xorg.conf.d + live session |
| `libinput Accel Profile Enabled` | `adaptive` (1,0,0) | xorg.conf.d |
| `libinput Tapping Enabled` | `on` | xorg.conf.d |
| `libinput Disable While Typing` | `on` | xorg.conf.d |
| `libinput Natural Scrolling` | `off` | xorg.conf.d |
| `libinput Horizontal Scroll` | `on` | xorg.conf.d |
| `libinput Tapping Button Map` | `lrm` (1p=left, 2p=right, 3p=middle) | xorg.conf.d |

Config dosyası: `/etc/X11/xorg.conf.d/30-touchpad-libinput.conf` (repo'daki `trackpad/configs/30-touchpad-libinput.conf` ile **identical**).
Backup: `/etc/X11/xorg.conf.d/30-touchpad-libinput.conf.bak.orig` (orijinal 119-byte minimal conf).

### Geri alma komutu (gelecek referans için)

```bash
# A) Orijinal antiX default'una dön
sshpass -p '<PASSWORD>' ssh asus@<TAILSCALE_IP> \
  'echo <PASSWORD> | sudo -S cp /etc/X11/xorg.conf.d/30-touchpad-libinput.conf.bak.orig \
                          /etc/X11/xorg.conf.d/30-touchpad-libinput.conf'

# B) Sadece Accel Speed'i 0'a çek (diğer ayarlar korunsun)
sshpass -p '<PASSWORD>' ssh asus@<TAILSCALE_IP> \
  'echo <PASSWORD> | sudo -S sed -i "s/AccelSpeed.*/AccelSpeed\" \"0.0\"/" \
               /etc/X11/xorg.conf.d/30-touchpad-libinput.conf'

# Logout-login (veya reboot) → aktif
```

### Öğrenilen dersler

1. **SSH stdin race** — `sudo -S tee` pattern heredoc ile çalışmaz. scp + sudo cp kullan. [`GUIDE.md § SSH üzerinden sudo + dosya yazma — DİKKAT`](./GUIDE.md#ssh-üzerinden-sudo--dosya-yazma--dİkkat) (kalıcı kaydedildi).

2. **antiX 23+'da synaptics gitti** — eski `synaptics.conf` dosyası duruyor ama etki etmiyor. Dokümante ettim ([`GUIDE.md § Arka plan`](./GUIDE.md#arka-plan)).

3. **İki-yönlü iterasyon çalışıyor** — 0.5 → 0.6 → 0.65 → 0.6 (geri dönüş). Tek yönde test → bias riski.

4. **Kullanıcı felsefesi >>> standart default** — "thumb-on-trackpad typist" profili için `0.6 + adaptive` tatlı nokta oldu. Başkası için `0.3` veya `0.8` olabilir.

---

<!-- Yeni session'lar bu satırın ÜSTÜNE eklenir, en yeni üstte -->
