# Game audio

## Background music

**Hymn** by Scott Buckley — released under CC BY 4.0.

- Artist: https://www.scottbuckley.com.au
- Source: https://www.scottbuckley.com.au/library/hymn/
- Download: https://www.scottbuckley.com.au/library/wp-content/uploads/2018/02/sb_hymn.mp3
- License: https://creativecommons.org/licenses/by/4.0/

The original MP3 is unedited. The game loops playback and applies a quiet
-3 dB music-player trim (-9 dB in menus), plus the saved Music/Master levels.
Attribution and clickable source/license links appear in Pause → Audio.

## Original synthesized effects and retained prototype music


These mono PCM WAV files are synthesized specifically for Pursuit: The Journey.
These synthesized WAVs contain no third-party recordings or samples. Rebuild them
with `python3 tools/build_audio.py` from the repository root (standard library).

The unused prototype `journey-ambient.wav` is a 32-second loop of sparse, soft piano-like synthesized
notes, with no sustained pad, bass drone or percussion. The remaining files are short menu, pipe rotation,
success/error, shot/impact/damage and footstep cues. Footsteps use a filtered, softly enveloped shoe rustle rather than a pitched tap.
Their playback has an additional -24 dB trim, independent of other effects.
Walking triggers one cue per 1.8 world units, rather than the earlier rapid taps.

`GameAudio.gd` routes playback through Master, Music and Effects buses. The
classroom murmur and ending chime also use Effects. Default linear levels are
50% on all three sliders. The untouched older prototype preset upgrades to 50%;
custom player values and mutes are preserved. At 100% both buses are at unity
gain; the music player retains 3 dB of headroom. Zero mutes; the Audio page saves changes locally in Godot's
user-data directory. Music fades in, becomes quieter in menus, pauses when the
application loses focus, and survives Restart Run without starting a second loop.
