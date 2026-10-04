# Minecraft Dungeons II on Linux

A local stand-in for Microsoft Gaming Services so Minecraft Dungeons II (Steam app `1912410`) can start under Proton. The game looks for `xgameruntime.dll`. This repository builds that DLL. It does not modify the game and it does not include Microsoft's library.

On first launch it signs you in with your own Microsoft account through the normal device-code page at <https://www.microsoft.com/link>, then caches the Xbox token next to the helper. Later launches reuse that cache until it expires.

## Install

Proton, Python 3, and OpenSSL are required. The `openssl` command has to be on `PATH`; sign-in uses it to mint the device-bound PlayFab token. Clone this repository into the directory the DLL searches:

```sh
git clone git@github.com:Kubas556/Dungeons2_linux_fix.git ~/.local/share/dungeons2-compat
cd ~/.local/share/dungeons2-compat
chmod +x install.sh xauth.py
./install.sh
```

`install.sh` copies `src/xgameruntime.dll` to three places:

- next to `Dungeons.exe`
- next to `Dungeons-Win64-Shipping.exe`
- into the Proton prefix `drive_c/windows/system32`

If the game lives in another Steam library, the script reads `libraryfolders.vdf`. Point `STEAM_ROOT` at your Steam install if it is not `~/.local/share/Steam`.

In Steam, open the game's properties and set the launch option:

```text
WINEDLLOVERRIDES="xgameruntime=n" %command%
```

Quit the game completely before installing. A running process keeps the old DLL.

## First sign-in

Start the game from Steam. A window shows a code and opens <https://www.microsoft.com/link>. Enter the code, then sign in with the Microsoft account that should own the Xbox profile. Leave that page as `https://www.microsoft.com/link` with no extra query string.

The token file is `~/.local/share/dungeons2-compat/tokens.txt` (mode `0600`). Do not share it. When it expires, the next launch refreshes it or asks you to sign in again.

## Microsoft account linking

Linking a Microsoft account in the game settings uses this same sign-in. The helper mints a device-bound PlayFab token, and the game receives that token when it talks to PlayFab. Nothing else has to be checked out.

A `tokens.txt` saved before that token existed is renewed on the next launch.

## Rebuild

The DLL already in `src/` is ready to install. To build it yourself you need a MinGW-w64 posix cross compiler:

```sh
x86_64-w64-mingw32-gcc-posix -shared -O2 -Wall -Wextra -o src/xgameruntime.dll src/xgameruntime.c
./install.sh
```

## What the game gets

The DLL answers the Gaming Services calls this title makes: task queues, a signed-in Xbox user (your real XUID and gamertag from the cache), title id, retail sandbox, persistent local storage, and the HTTPS security settings XCurl asks for before it connects. Sign-in mints device-bound Xbox tokens, including a PlayFab XSTS token, so in-game Microsoft account linking can succeed. The matching token is returned when the game asks for one.

## License

This project is licensed under the [MIT License](LICENSE).
