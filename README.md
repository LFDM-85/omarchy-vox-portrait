# Vox Portrait

A theme-adaptive Omarchy shell plugin for Voxtype 1.0.1. The neural portrait
responds to real microphone levels, animates during transcription, and
progressively reveals recognized text.

## Usage

Use your existing Voxtype shortcut. The overlay appears during recording
and transcription, then displays the result for 14 seconds. It never takes
keyboard focus or intercepts clicks. It respects `--no-osd`.

Preview for 20 seconds without recording:

```sh
omarchy-shell vox-portrait preview
omarchy-shell vox-portrait close
omarchy-shell vox-portrait status
```

## Theme Integration

The plugin binds directly to the shell's live `Color` and `Style` singletons.
Background, text, borders, typography, spacing, portrait tint, waveform and
scan accents follow the selected theme automatically. Accents with less than
3:1 background contrast fall back to the theme text color. The transparent
monochrome artwork is tinted at render time. All interface labels are English;
dictated text is preserved in its original language.

## Integration

- `Service.qml` uses the installed Voxtype AudioBridge and StateReader.
- `capture.py` receives text through `output.post_process`, publishes an
  atomic UI event, and returns the original bytes unchanged. Publication
  failures do not block text output.
- The last transcript is stored in
  `$XDG_RUNTIME_DIR/vox-portrait/transcript.json` with permissions 0600 until
  replaced or the session ends.
- The plugin is enabled in `~/.config/omarchy/shell.json`.
- `osd.enabled = false` disables the original frontend while keeping the
  audio level socket available.

## Limits

The plugin supports any local Voxtype transcription model and language setting.
Text arrives after recording finishes. The reveal animation presents the result;
it does not confirm each keystroke delivered to the destination application.
Processing means transcription, not access to internal AI reasoning. No new
external audio or transcript service is used.

## Disable

Remove `luismelo.vox-portrait` from `plugins` in shell.json, remove the active
`[output.post_process]` section calling capture.py, and set `[osd] enabled`
to `true` in the Voxtype configuration. Run `systemctl --user restart voxtype`.

Original configuration backups have the `.before-vox-portrait` suffix.

## Artwork

`neural-portrait.png` was generated with the built-in image generation tool.
The full production prompt is recorded in `artwork-prompt.txt`.
