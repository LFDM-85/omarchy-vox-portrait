# Vox Portrait

A theme-adaptive Omarchy shell plugin for Voxtype 1.0.1. The neural portrait
responds to real microphone levels, animates during transcription, and
progressively reveals recognized text.

## Install

Requirements: Omarchy with the shell plugin system and a working local
Voxtype installation. Review the repository before enabling it: Omarchy
plugins run unsandboxed inside the long-lived shell process.

```sh
omarchy plugin add https://github.com/LFDM-85/omarchy-vox-portrait.git --enable
```

Then merge the following into `~/.config/voxtype/config.toml`. Replace
`your-user` with your Linux username. `output.post_process` supports one
command, so preserve or intentionally replace any existing command in that
section.

```toml
[osd]
enabled = false

[output.post_process]
command = "python3 /home/your-user/.config/omarchy/plugins/luismelo.vox-portrait/capture.py"
timeout_ms = 1000
```

Apply the Voxtype configuration:

```sh
systemctl --user restart voxtype
```

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

## Remove

First remove the `output.post_process` command that calls `capture.py` from
`~/.config/voxtype/config.toml`, set `[osd] enabled` to `true` if you want the
built-in Voxtype interface back, then restart Voxtype:

```sh
systemctl --user restart voxtype
omarchy plugin remove luismelo.vox-portrait
```

Original configuration backups have the `.before-vox-portrait` suffix.

## Artwork

`neural-portrait.png` was generated with the built-in image generation tool.
The full production prompt is recorded in `artwork-prompt.txt`.

## License

MIT. See [LICENSE](LICENSE).
