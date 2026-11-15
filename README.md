# EurKEY Keyboard Layouts

A fork of [calin-darie/extra-keyboard-layouts][upstream] (MIT) that keeps all
160 bundled Android physical-keyboard layouts and stays installable on current
Android. Originally written because I wanted [EurKEY][eurkey] on a tablet.

[upstream]: https://github.com/calin-darie/extra-keyboard-layouts
[eurkey]: https://eurkey.steffen.bruentjen.eu/

Adds choices to the layout list Android offers when a physical keyboard is
connected over OTG or Bluetooth. Upstream stops at `targetSdk 33`, so Google
Play refuses new installs; this fork builds against API 35 and ships its own
signed APK.

## Why this fork exists

The upstream app was last updated in 2023 and targets Android 13 (API 33).
Play rejects installs from apps that do not target API 34 or newer, so the app
is no longer installable on current devices even though the layouts work fine.
EurKEY is also only in the upstream Play build (v1.29), not in the GitHub
release.

This fork changes exactly that and nothing else:

- `compileSdk` / `targetSdk` 35, AGP 8.7.3, Gradle 8.9
- own `applicationId` (`name.bastkowski.eurkeylayouts`) and release signing
- manifest `package` attribute replaced by the Gradle `namespace`
- all 160 layouts kept byte-for-byte, including `keyboard_layout_eu_eurkey`

## Install

Download the APK from the releases page and open it on the device, or:

```
adb install eurkey-layouts-1.0.apk
```

The app has no launcher icon and needs no permissions. After installing,
connect the keyboard and pick the layout:

Settings → General management → Keyboard and input → Physical keyboard →
*your keyboard* → Keyboard layouts → **EU (EurKEY)**

Keep only that one layout enabled, otherwise Ctrl+Space cycles through the
others while you type. Use the **right** Alt for level 3: Android treats the
left Alt as a shortcut modifier.

## EurKEY at a glance

| Keys | Result |
| --- | --- |
| RightAlt + a / o / u | ä / ö / ü |
| RightAlt + s | ß |
| RightAlt + 5 | € |
| RightAlt + ` / 6 | dead key for accents, followed by the base letter |
| RightAlt + q / w / y | æ / å / ø |
| RightAlt + Shift + 7 | Umlaut dead key |

Full mapping: `app/src/main/res/raw/keyboard_layout_eu_eurkey.kcm`.

## Notes for Samsung / One UI

- Installing a layout provider does not refresh the keymap of an already
  connected keyboard; unplug and replug it, or reboot.
- If RightAlt is swallowed as a system shortcut, Ctrl+Alt combinations are the
  reliable fallback on One UI. Ask for a patched `.kcm` if you need that.
- The keyboard's own Mac/Win switch changes what the right Alt key sends.

## Build

```
./gradlew assembleRelease
```

Output: `app/build/outputs/apk/release/app-release.apk`.

Release signing reads `keystore.properties` from the repo root when present and
falls back to an unsigned build otherwise. That file is gitignored on purpose —
keep the keystore out of the repo:

```
storeFile=/absolute/path/to/release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

### Building on ARM64 (aarch64)

Google ships `aapt2` for x86_64 only, and AGP invokes `jlink`, so a headless JRE
is not enough either. `build-aarch64.sh` handles both: it bootstraps everything
it needs into `$TOOLCHAIN` (default `~/android-toolchain`) on first run and
reuses it afterwards.

```
./build-aarch64.sh                    # first run downloads ~200 MB
./build-aarch64.sh --offline          # later runs, extra args go to gradlew
```

What it sets up, and why:

| Piece | Purpose |
|---|---|
| Temurin JDK 17 | AGP calls `jlink`; runtime-only JREs fail |
| `aapt2dir/aapt2` + `x86root/` | x86_64 `aapt2` from the AGP maven artifact, plus a minimal x86_64 glibc (`libc6`, `libgcc-s1`) unpacked from Debian, since an ARM host has no x86_64 libs |
| `aapt2wrap/aapt2` | shim running the two above under `qemu-x86_64-static`, passed to AGP as `android.aapt2FromMavenOverride` |
| `$ANDROID_HOME` | platform 35 + build-tools, installed via `sdkmanager` when `platforms/android-35` is absent |

Requires `qemu-user-static` (`apt-get install qemu-user-static`), `curl`,
`unzip`, `ar`. Override paths with `TOOLCHAIN=`, `ANDROID_HOME=`, `JAVA_HOME=`,
or point `DEBIAN_MIRROR=` at a closer mirror. Debian package versions are
resolved from the pool listing at run time, so point releases do not break it.


## Layouts

Tested layouts:
* Albanian
* Armenian Phonetic
* Armenian Typewriter
* Azeri Cyrillic
* Bangla Jatiya [<sup id="a1">1</sup>](#note1)
* Bashkir
* Belarusian
* Belgian (Comma)
* Belgian (Period)
* Bosnian (Cyrillic)
* Bulgarian (Phonetic Traditional)
* Bulgarian (Phonetic)
* Canadian French
* Colemak
* Czech (QWERTZ)
* Divehi Phonetic
* Dutch
* EurKEY
* Halmak
* Hindi Traditional INSCRIPT [<sup>1</sup>](#note1)
* Jawi Phonetic QWERTY
* Nias
* Polish (Programmers)
* Portuguese (Magic keyboard)
* Romanian Programmers
* Romanian Standard
* Swedish Dvorak (Svorak A1)
* Thai Kedmanee +/- Writer, +/- Shiftlock
* Thai Manoonchai +/- Writer +/- Shiftlock
* Thai Pattachote +/- Writer +/- Shiftlock
* Thai TIS 820-2538
* Urdu (Phonetic)

Experimental - not tested:
* ABC - Latin alphabetical order
* Azeri Latin
* Arabic 102 AZERTY [<sup>1</sup>](#note1)
* Assamese INSCRIPT [<sup>1</sup>](#note1)
* Bengali [<sup>1</sup>](#note1)
* Bengali INSCRIPT [<sup>1</sup>](#note1)
* Bulgarian Typewriter
* Canadian Multilingual Standard
* Cherokee nation [<sup>1</sup>](#note1)
* Czech (QWERTY)
* Czech Programmers
* Divehi Typewriter
* English (India)
* Faeroese
* Finnish with Sami
* Georgian (Ergonomic)
* Georgian (MES)
* Georgian (QWERTY)
* German (IBM)
* Greek (220)
* Greek (220) Latin
* Greek (319) Latin
* Greek Latin
* Greenlandic
* Gujarati [<sup>1</sup>](#note1)
* Hausa
* Hawaiian
* Hebrew (Standard)
* Hungarian 101 QWERTY
* Inuktitut Latin
* Irish
* Italian (142)
* Jawi SIRIM [<sup>1</sup>](#note1)
* Kannada [<sup>1</sup>](#note1)
* Kazakh
* Khmer [<sup>1</sup>](#note1)
* Khmer Nida [<sup>1</sup>](#note1)
* Korean
* Kyrgyz Cyrillic
* Kurdish Hejar https://klpp.github.io/hejar.html [<sup>1</sup>](#note1)
* Kurdish KRG http://unicode.ekrg.org/download/UnifiedKeyboardProject_enGB.pdf [<sup>1</sup>](#note1)
* Lao [<sup>1</sup>](#note1)
* Latin American
* Latvian (QWERTY)
* Lisu Basic
* Lisu Standard
* Lithuanian IBM
* Lithuanian Standard
* Luxembourgish
* Macedonian (FYROM)
* Macedonian (FYROM) - Standard
* Malayalam [<sup>1</sup>](#note1)
* Maltese 47-Key
* Maltese 48-Key
* Maori
* Marathi [<sup>1</sup>](#note1)
* Mongolian (Mongolian Script)
* Mongolian Cyrillic
* Myanmar
* Nepali
* Neo 2 [<sup>2</sup>](#note2)
* New Tai Lue
* Norwegian with Sami
* N’Ko
* Odia [<sup>1</sup>](#note1)
* Ogham
* Pashto (Afghanistan)
* Persian standard [<sup>1</sup>](#note1)
* Phags Pa [<sup>1</sup>](#note1)
* Punjabi [<sup>1</sup>](#note1)
* Russian (Typewriter)
* Russian Phonetic Linux[<sup>3</sup>](#note3)
* Russian Phonetic YaWert
* Sakha [<sup>1</sup>](#note1)
* Sami Extended Finland-Sweden
* Sami Extended Norway
* Scottish Gaelic
* Santali (Sarjom baha - phonetic Ol' Chiki script)
* Serbian (Cyrillic)
* Serbian (Latin)
* Sesotho sa Leboa
* Setswana
* Sinhala [<sup>1</sup>](#note1)
* Slovak (QWERTY)
* Slovak (QWERTZ)
* Sorbian Extended
* Sorbian Standard
* Spanish variation
* Swedish with Sami
* Syriac
* Syriac Phonetic
* Tajik
* Tamil [<sup>1</sup>](#note1)
* Tamil 99
* Tatar
* Telugu [<sup>1</sup>](#note1)
* Thai Kedmanee (non-ShiftLock)
* Thai Pattachote
* Thai Pattachote (non-ShiftLock)
* Tifinagh basic [<sup>1</sup>](#note1)
* Tifinagh extended [<sup>1</sup>](#note1)
* Turkish F
* Turkish Q
* Turkmen
* US English Table for IBM Arabic 238_L
* Ukrainian (Enhanced)
* United States-Dvorak for left hand
* United States-Dvorak for right hand
* Urdu
* Uyghur [<sup>1</sup>](#note1)
* Uzbek Cyrillic
* Vietnamese
* Wolof


<sup id="note1">**1**</sup> For some of the layouts, combo key ligatures that on other OSs can be typed by shift+numbers are not directly supported. Instead, you'll have to type the components individually. 

For Hindi for example on a QWERTY keyboard, instead of shift + 3 you have to type D+J
* D J ्र 
* J D र् 
* P D SHIFT+] ज्ञ 
* L D J त्र 
* K D SHIFT+, क्ष

For Jawi SIRIM, the B key does not type anything. and you should be able to reproduce its behavior by typing G followed by H and G followed by SHIFT + N
* G H لا
* G SHIFT + N لآ
* G SHIFT + H لأ
* G SHIFT + Y لإ


For Lao
* A H => LAO VOWEL SIGN MAI KAN + LAO TONE MAI THO
* B H =>  LAO VOWEL SIGN Y + LAO TONE MAI THO
* N H => LAO VOWEL SIGN YY + LAO TONE MAI THO
* Q H => LAO VOWEL SIGN MAI KON + LAO TONE MAI THO
* Y H => LAO VOWEL SIGN II + LAO TONE MAI THO
* U H  => LAO VOWEL SIGN I + LAO TONE MAI THO
* = J  => LAO NIGGAHITA + LAO TONE MAI EK
* s^ => LAO LETTER HO SUNG + LAO SEMIVOWEL SIGN LO
[↩](#a1)


For Kurdish KRG:
* وو <= و و    you have to press the key twice, no shift
* shift H => ZERO WIDTH NON-JOINER, to be used in combination with ھ 

<sup id="note2">**2**</sup> Neo 2's 4th level is severely crippled while not locked because in order to access level  4 you need to press the right alt key, and the right alt key in combination with level 4 directions results in unexpected behavior. So try level 4 navigation only by locking. 

Also, locking isn't working as you're used to: press the start / windows key to lock level 4. Press scroll lock to lock level 2.

The following features are not available in android:
* compose (triggered by TAB in level 3)
* undo functionality (triggered by Z in level 4)
* rotate key

<sup id="note3">**3**</sup> Russian Phonetic Linux is taken from standard layouts available on Linux, it was modified slightly to add back some symbols that are replaced by Russian characters in the Base and Shift layers, to get to them use RightAlt and RightAlt+Shift respectively.

Here are the notable modifications in relation to QWERTY
* `SHIFT` + 3 => ё
* `RALT` + 3 => #
* `RALT` + `SHIFT` + 3 => №
* `SHIFT` + 4 => Ё
* `RALT` + 4 => $
* `SHIFT` + 5 => ъ
* `RALT` + 5 => %
* `SHIFT` + 6 => Ъ
* `RALT` + 6 => ^
* = => ч
* `SHIFT` + = (+) => Ч
* `RALT` + = => =
* `RALT` + `SHIFT` + = => +
* [ => ш
* `SHIFT` + [ => Ш
* `RALT` + [ => [
* `RALT` + `SHIFT` + [ => {
* ] => щ
* `SHIFT` + ] => Щ
* `RALT` + ] => ]
* `RALT` + `SHIFT` + ] => }
* \` => ю
* `SHIFT` + \` => Ю
* `RALT` + \` => \`
* `RALT` + `SHIFT` + \` => ~
* \\ => э
* `SHIFT` + \\ => Э
* `RALT` + \\ => \\
* `RALT` + `SHIFT` + \\ => |

## Credits

All layout files and the original app come from
[calin-darie/extra-keyboard-layouts][upstream], MIT licensed, copyright Călin
Darie. EurKEY itself is by Steffen Brüntjen. If upstream ever resumes
development, this fork exists only to keep the layouts installable — go star
the original.

If you found the original useful, you may
[buy the author a drink](https://paypal.me/CalinDarie?locale.x=en_US).

## License

MIT, see [LICENSE](LICENSE).
