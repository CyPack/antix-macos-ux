# Trackpad / Mouse Tuning

antiX-26 (libinput) üzerinde trackpad/mouse hassasiyet (Accel Speed) ayarı, kalıcılaştırma ve cihaza göre keşif metodolojisi.

## Bu klasörde ne var?

| Dosya | Ne işe yarar |
|-------|--------------|
| [`GUIDE.md`](./GUIDE.md) | **Tam teknik rehber** — driver tespiti, property keşfi, test metodolojisi, kalıcı yapma, geri alma, troubleshooting |
| [`CONTEXTUAL-RESEARCH.md`](./CONTEXTUAL-RESEARCH.md) | Farklı cihaz / driver / kullanım profiline göre nasıl araştırılır (libinput vs synaptics vs evdev, touchpad vs harici mouse vs trackball) |
| [`AGENT-RULES.md`](./AGENT-RULES.md) | AI agent'ların bu işi tek başına yapabilmesi için tetikleyiciler, karar ağacı, anti-pattern'ler ve kontrollü workflow |
| [`SESSION-LOG.md`](./SESSION-LOG.md) | 2026-04-24 ASUS L200H için yapılan optimizasyon session'unun tam transcript özeti |
| [`configs/30-touchpad-libinput.conf`](./configs/30-touchpad-libinput.conf) | Canonical kalıcı config — `/etc/X11/xorg.conf.d/` altına kopyalanır |
| [`scripts/inspect.sh`](./scripts/inspect.sh) | Mevcut trackpad driver + property dump (tanı aracı) |
| [`scripts/test-speed.sh`](./scripts/test-speed.sh) | Geçici hız testi — `./test-speed.sh 0.5` |
| [`scripts/apply.sh`](./scripts/apply.sh) | Kalıcı yaz — `sudo ./apply.sh 0.6` (`/etc/X11/xorg.conf.d/` dokunur) |
| [`scripts/restore.sh`](./scripts/restore.sh) | Orijinal backup'tan config geri yükle |

## TL;DR — Benim için çalışacak komut ne?

ASUS L200H + antiX-26 ile aynı donanım/workflow'u paylaşıyorsan:

```bash
# 1. Hemen dene (geçici)
DISPLAY=:0 xinput set-prop "Asus TouchPad" "libinput Accel Speed" 0.6

# 2. Beğendinse kalıcı yap
sudo cp configs/30-touchpad-libinput.conf /etc/X11/xorg.conf.d/30-touchpad-libinput.conf
# Sonraki login/reboot'tan itibaren geçerli.
```

Farklı donanım (yabancı laptop, Thinkpad, harici mouse, vb.) → [`GUIDE.md`](./GUIDE.md) oku, `scripts/inspect.sh` çalıştır, kendi cihazını tanı.

## Kullanım felsefesi (bu ayarı neden 0.6 yaptık)

> "Elimi klavyeden kaldırmadan başparmağımla trackpad'i kullanabilmek. Optimum hız ayarım:
> **İlk hareket** ile ekran köşesinden ortaya yakın bir mesafeye gelebilmek,
> **ikinci hareket** ile karşı çapraz köşeye ulaşabilmek.
> Ve birbirine yakın seçenekler arasında mouse fırlatma yapmadan rahat seçim yapabilmek."

Bu felsefe → **orta-yüksek hız** (`0.5` – `0.7` band) + **adaptive profile** (yavaş hareket → hassas, hızlı hareket → ivme). ASUS L200H'de `0.6` bu bandın tatlı noktası oldu (detaylı gerekçe: [`SESSION-LOG.md`](./SESSION-LOG.md)).

Senin alışkanlığın farklıysa:

| Profil | Tavsiye | Neden |
|--------|---------|-------|
| "Trackpad'i iki elle kullanırım, hassas grafik tasarım" | `AccelSpeed=0.0` + `AccelProfile=flat` | 1:1 hareket, abartı ivme yok |
| "Oyun/FPS, çok hızlı refleks" | `0.8` – `1.0` + `adaptive` | Hızlı sweep |
| "Yaşlı gözler, stabil hareket istiyorum" | `-0.3` – `0.0` + `adaptive` | Yavaş/ölçülü |
| "Klavye ortalama, ara ara trackpad" | `0.3` – `0.5` | Dengeli |
| **"Başparmak-on-trackpad, yazarken kısa dokunuş"** | **`0.5` – `0.7`** | **Bu repo'nun default'u** |

İterasyon yöntemi için → [`GUIDE.md § Test Methodology`](./GUIDE.md#test-methodology).
