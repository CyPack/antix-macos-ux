# Agent Rules — AI asistan için trackpad tuning rehberi

**Amaç:** En "basit" / deterministik AI agent bile bu dosyayı okursa:
1. Kullanıcının ne istediğini **bağlamsal** olarak anlasın.
2. Cihazı **tanısın** (driver, session type, mevcut durum).
3. **Kontrollü** süreçle test → onay → kalıcı yaz yolu izlesin.
4. **Anti-pattern**'leri tanıyıp kendini düzeltsin.

## TRIGGER LIST — Bu dosyayı ne zaman okumalısın

Kullanıcı şu ifadelerden **herhangi birini** kullanırsa:

- "trackpad hızı" / "touchpad hassasiyet" / "mouse hassasiyet"
- "cursor hızı" / "imleç hızı" / "pointer speed"
- "trackpad yavaş" / "trackpad hızlı" / "çok hassas" / "yavaş kalıyor"
- "fare hızı" / "mouse acceleration" / "accel speed"
- "natural scrolling" / "ters scroll" / "macOS scroll"
- "tıkla-dokun" / "tap to click" / "palm rejection" / "yazarken kapat"
- "sol el modu" / "left handed mouse"
- İngilizce: "trackpad sensitivity / speed / acceleration", "touchpad settings", "mouse tuning"

VE aynı zamanda bir Linux laptop / masaüstü context'i varsa → **BU DOSYAYI OKU**, sonra [`GUIDE.md`](./GUIDE.md) ve [`CONTEXTUAL-RESEARCH.md`](./CONTEXTUAL-RESEARCH.md) ile devam et.

## PRE-EXECUTION CHECKLIST

Komut çalıştırmadan **ÖNCE** şunları cevapla:

```
□ 1. Hangi cihazdayım?  (local Fedora, remote ASUS, başka SSH target?)
□ 2. Session type?      (X11 mi Wayland mı?)
□ 3. Hangi driver?      (libinput / synaptics / evdev)
□ 4. Mevcut ayar ne?    (xinput list-props ile oku)
□ 5. Kullanıcının ne?   (geçici test mi, kalıcı mı, revert mi?)
□ 6. Kullanıcı profili? (thumb-on-trackpad / gaming / grafik / yaşlı / genel?)
```

**6 sorudan biri cevapsız** → o zaman kullanıcıya sor **veya** [`CONTEXTUAL-RESEARCH.md § Adım 1-3`](./CONTEXTUAL-RESEARCH.md#araştırma-workflow--yeni-cihaza-karşılaşan-agent-için) adımlarını çalıştır.

## KARAR AĞACI

```
Kullanıcı: "trackpad hızını ayarlayalım"
   │
   ├─ Hangi cihaz?
   │    │
   │    ├─ LOCAL (sen direkt erişiyorsun)
   │    │     → Adım A'dan başla
   │    │
   │    └─ REMOTE (SSH üzerinden)
   │          → SSH erişimi test et (ping, ssh)
   │          → DISPLAY=:0 export edildiğinden emin ol
   │          → Adım A'dan başla
   │
   ├─ Adım A: Cihaz + driver tanıma
   │     DISPLAY=:0 xinput list
   │     DISPLAY=:0 xinput list-props "DEVICE_NAME" | head -30
   │
   ├─ Adım B: Mevcut "Accel Speed" değerini oku
   │     Eğer libinput → libinput Accel Speed
   │     Eğer synaptics → Synaptics MinSpeed / MaxSpeed
   │     Eğer evdev → Device Accel Constant Deceleration
   │
   ├─ Adım C: Kullanıcının hedefi?
   │    │
   │    ├─ "Hızlı / yavaş" demişse → değer tahmini ver (+0.2 adım)
   │    │     ve "deneyelim" diyerek GEÇİCİ uygula (xinput set-prop)
   │    │
   │    ├─ Spesifik değer vermişse (ör. "0.6 yap") → direkt uygula
   │    │
   │    └─ "Kalıcı yap" / "bir daha değiştirmeyelim" demişse
   │          → xorg.conf.d dosyasına yaz
   │          → Backup al önce (cp -n)
   │          → Uyarı ver: "logout-login sonrası etkin"
   │
   ├─ Adım D: Test döngüsü (kullanıcı memnun değilse)
   │     "Nasıl hissediyor?" sor.
   │     İterasyonda 3–4 denemeden sonra **iki yöne de git** — tek yönde bias'ın.
   │     Ör: 0.5 → 0.6 → 0.65 → 0.6 (geri dönmek valid).
   │
   └─ Adım E: Kullanıcı "tamam" dedi → KALICI YAP, DOKÜMANTE ET, GERİ ALMA KOMUTUNU SÖYLE
```

## KOMUT SÖZLÜĞÜ (mekanik referans)

### Cihaz tanıma
```bash
DISPLAY=:0 xinput list                                    # tüm cihazlar
DISPLAY=:0 xinput list-props "Asus TouchPad" | head -30   # properties
```

### Geçici ayar (libinput)
```bash
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Accel Speed" 0.6
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Accel Profile Enabled" 1 0 0  # adaptive
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Accel Profile Enabled" 0 1 0  # flat
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Natural Scrolling Enabled" 1
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Disable While Typing Enabled" 1
```

### Kalıcı ayar (xorg.conf.d)
```bash
# Backup
sudo cp -n /etc/X11/xorg.conf.d/30-touchpad-libinput.conf \
          /etc/X11/xorg.conf.d/30-touchpad-libinput.conf.bak.orig

# Repo'dan canonical config (tercih edilen)
sudo cp trackpad/configs/30-touchpad-libinput.conf /etc/X11/xorg.conf.d/

# Veya inline Option değiştir (sed kullanarak)
sudo sed -i 's/Option "AccelSpeed".*/Option "AccelSpeed" "0.6"/' \
          /etc/X11/xorg.conf.d/30-touchpad-libinput.conf
```

### SSH + sudo dosya yazma (stdin race'den kaçın)
```bash
# ✓ DOĞRU — scp + cp (önerilen)
scp local.conf user@host:/tmp/
ssh user@host 'echo pw | sudo -S true && sudo cp /tmp/local.conf /etc/X11/xorg.conf.d/'

# ✗ YANLIŞ — sudo stdin tüketiyor, heredoc içerik gitmiyor
cat <<EOF | ssh user@host 'echo pw | sudo -S tee /path'
```

### Dogrulama
```bash
# Aktif değeri kontrol et
DISPLAY=:0 xinput list-props "Asus TouchPad" | grep "Accel Speed ("

# Dosya gerçekten yazıldı mı (stdin race saptama)
ssh user@host 'wc -c /etc/X11/xorg.conf.d/30-touchpad-libinput.conf'
# 5 byte ise bozuk ("pw\n"), 400+ byte ise OK
```

## KONTROL NOKTALARI

Agent olarak **her adımda** bu kontrolleri yap:

| Nokta | Sor | Geç |
|-------|-----|-----|
| Driver tespit edildikten sonra | Driver prefix doğrulandı mı? (libinput/Synaptics/Device Accel) | Evet → devam. Hayır → [GUIDE.md § Driver tanıma](./GUIDE.md#driver-tanıma) oku |
| Geçici ayar uygulandıktan sonra | `xinput list-props` çıktısında değer değişti mi? | Evet → kullanıcıya "dene" de. Hayır → yanlış cihaz seçtin, yeniden bak |
| Kalıcı config yazıldıktan sonra | `wc -c` >100 byte mı? | Evet → OK. Hayır → SSH stdin race, yeniden yaz (scp yolu) |
| Session restart sonrası | `xinput list-props` hâlâ istenen değeri gösteriyor mu? | Evet → başarı. Hayır → config dosyası yanlış yerde veya başka dosya ezdi |
| Kullanıcı feedback | "Tamam" / "iyi" / "bu iyi" dedi mi? | Evet → commit/dokümante. Hayır → iterasyon devam |

## ANTI-PATTERN'LER (YASAK)

| # | Anti-pattern | Doğru yol |
|---|--------------|-----------|
| 1 | Cihaz tanımadan "0.5 yaparım" | Önce `xinput list` + `list-props`, sonra teklif |
| 2 | Wayland session'da xinput çalıştırmak | `$XDG_SESSION_TYPE` kontrol, Wayland ise compositor-specific |
| 3 | Kullanıcı onayı olmadan kalıcı yaz | Önce geçici test, "kalıcı yapalım mı?" sor |
| 4 | `cat <<EOF \| ssh 'sudo -S tee'` pattern | scp + sudo cp |
| 5 | Config yazdım demek, doğrulama yapmamak | Yazdıktan sonra `wc -c` + `xinput list-props` |
| 6 | Device ID ile kalıcı komut (USB hot-plug bozar) | Her zaman isimle |
| 7 | Tek yönde iterasyon (hep artırmak, hep azaltmak) | İki yöne git, geri dönmek valid |
| 8 | Backup almadan config değiştirmek | `cp -n foo foo.bak.orig` önce |
| 9 | "0.5 çoğu insan için iyi" diye standart dayatma | Kullanım profili sor (thumb / gamer / tasarım / yaş) |
| 10 | Kullanıcıya "reboot et" der demez durdurmak | "logout-login yeterli" + backup komutunu ver |

## BU REPO'DAKİ DEFAULT — ASUS L200H için

- **AccelSpeed:** `0.6`
- **Profile:** `adaptive`
- **Tapping:** `on` (1-parmak sol tık)
- **DisableWhileTyping:** `on` (başparmak workflow için kritik)
- **Natural scrolling:** `off` (klasik)
- **Horizontal scroll:** `on`

Bu değerler **thumb-on-trackpad typist** profili için seçildi. Farklı profil → [`README.md § Kullanım felsefesi`](./README.md#kullanım-felsefesi-bu-ayarı-neden-06-yaptık) tablosuna bak, başlangıç değerini buradan al.

## SESSION-LOG güncellemesi (agent için)

Bu trackpad/ altında yapılan her müdahaleyi [`SESSION-LOG.md`](./SESSION-LOG.md) sonuna ekle. Format:

```markdown
## YYYY-MM-DD — <cihaz/context>

**Kullanıcı isteği:** "..."

**Tanı:**
- Driver: ...
- Mevcut değer: ...
- Profil: ...

**İterasyon:**
| Değer | Geri bildirim |
|-------|---------------|
| 0.5   | ... |
| 0.6   | ... |

**Final:** `AccelSpeed=X.Y`, kalıcılaştırıldı: evet/hayır.

**Backup:** `/etc/.../30-touchpad-libinput.conf.bak.YYYYMMDD`

**Geri alma:**
\`\`\`
sudo cp .bak.orig orig && logout
\`\`\`
```

Böylece bir sonraki agent da geçmişi okur, aynı hataya düşmez.
