# Teams Backgrounds

A macOS shell script that prepares images for use as Microsoft Teams custom backgrounds. It renames each image to a GUID filename and generates a correctly-sized thumbnail, matching the format Teams expects when you drop files directly into its backgrounds folder.

## How it works

For every supported image in the target folder the script:

1. Assigns a new UUID-based filename (e.g. `3F8A2B1C-…-4D9E.jpg`)
2. Produces a `280×158` thumbnail using scale-to-cover + centre-crop (e.g. `3F8A2B1C-…-4D9E_thumb.jpg`)

The original file is renamed in-place; no copies of the full-resolution image are made.

## Requirements

- macOS (uses `sips` and `uuidgen`, both included with macOS)
- Bash 3.2+

## Usage

**1. Set the target directory**

Open `teamsBackgrounds.sh` and set `TARGET_DIR` to the absolute path of your backgrounds folder. For the new Teams client on macOS this is typically:

```
~/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds/Uploads
```

```bash
TARGET_DIR="/path/to/your/backgrounds/folder"
```

**2. (Optional) Dry run first**

Set `DRY_RUN=1` to preview what the script will do without touching any files:

```bash
DRY_RUN=1
```

**3. Run the script**

```bash
chmod +x teamsBackgrounds.sh
./teamsBackgrounds.sh
```

**4. Apply changes**

If the dry run looks correct, set `DRY_RUN=0` and run again.

## Supported image formats

`.jpg` / `.jpeg`, `.png`, `.heic`, `.tif` / `.tiff`, `.gif`, `.bmp`

Files already named with a `_thumb` suffix are skipped automatically.

## Configuration

| Variable   | Default | Description                          |
|------------|---------|--------------------------------------|
| `TARGET_DIR` | *(empty)* | **Required.** Absolute path to your backgrounds folder. |
| `THUMB_W`  | `280`   | Thumbnail width in pixels (Teams spec). |
| `THUMB_H`  | `158`   | Thumbnail height in pixels (Teams spec). |
| `DRY_RUN`  | `0`     | Set to `1` to preview without making changes. |

## Notes

- The script uses a temp file when creating thumbnails so a partial failure never corrupts the original.
- GUIDs are checked for collisions before use — safe to run multiple times against the same folder.
- Renaming uses `mv -n` (no-clobber) as an extra safeguard.

## Reference

[Microsoft Teams for Mac — custom backgrounds file location](https://learn.microsoft.com/en-us/answers/questions/4412157/new-microsoft-teams-for-mac-where-is-the-new-calls)

## License

See [LICENSE](LICENSE).
