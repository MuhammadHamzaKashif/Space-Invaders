# Space Invaders (MASM)

A 32-bit Windows space shooter written entirely in x86 assembly with MASM32. It draws everything through the GDI, runs a fixed game loop, and packs in waves, a boss fight, power-ups, particles, and a scrolling starfield.

![Assembly](https://img.shields.io/badge/MASM-x86_32-6E4C13?style=flat-square)
![Win32](https://img.shields.io/badge/Win32-GDI-0078D4?style=flat-square&logo=windows&logoColor=white)

## Gameplay

- Multiple enemy waves, including a V-formation wave
- A boss with a beam attack
- Player and enemy bullets with velocity, plus collision checks
- Power-ups for weapon upgrades and health
- Explosion particles and an animated starfield background
- Title, playing, dead, and win states

## How it is built

- Full-screen window with a GDI device context; all rendering is manual `DrawRect` calls, no engine or framework
- Game objects are fixed-size C-style structs (`Enemy`, `Bullet`, `PowerUp`, `Star`, `Explosion`, `BossBeam`) held in fixed arrays
- The loop is driven by `WM_TIMER`; logic and rendering are split into `UpdateGame` and `RenderGame`
- Randomness comes from a small custom PRNG (`Random`, `RandomRange`)

## Layout

```
spacewars.asm   full source
spacewars.obj   assembled object
spacewars.exe   prebuilt binary
```

## Building

Requires [MASM32](https://www.masm32.com/) installed at `C:\masm32` (the includes are referenced by absolute path in `spacewars.asm`).

```bat
ml /c /coff spacewars.asm
link /subsystem:windows spacewars.obj
```

Or open `spacewars.asm` in the MASM32 editor and build from there. The committed `spacewars.exe` can be run directly on 32-bit or 64-bit Windows.

## Notes

- The include paths are absolute (`C:\masm32\...`). Adjust them if MASM32 lives elsewhere.
- Screen size and entity caps are compile-time constants near the top of the file, so tuning gameplay means reassembling.
