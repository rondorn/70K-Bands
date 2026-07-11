# Festival Data Maintenance Tools

Portable, festival-agnostic tools for entering **band lineup** and **schedule** CSV data.

See **[WORKSPACE.md](WORKSPACE.md)** for the promoter product model (testing/production pointers, promote, Dropbox folder layout).
See **[STORE_SUBMISSION.md](STORE_SUBMISSION.md)** for Mac / iPad / Windows store readiness.
See **[promoter_admin/](promoter_admin/)** for the Flutter shell.

## What is in this folder

| Item | Purpose |
|------|---------|
| `run_data_entry.py` | Main entry point (Python / Flask prototype) |
| `run.sh` / `run.bat` | Start the server (creates venv on first run) |
| `setup.sh` / `setup.bat` | One-time install of dependencies |
| `requirements.txt` | Python packages (Flask, BeautifulSoup, dropbox) |
| `festival_data_entry.example.json` | Config template |
| `data_entry/` | Application code, HTML templates, CSS, workspace API |
| `promoter_admin/` | Flutter cross-platform shell (store apps) |
| `WORKSPACE.md` | Festival workspace conventions |
| `STORE_SUBMISSION.md` | App store path |

You do **not** need anything else from the parent repository. Copy or zip this entire `data_maintenance_tools` folder to another machine.

## Requirements

- **Python 3.9+** with `pip` ([python.org/downloads](https://www.python.org/downloads/))
- On Windows, enable **“Add python.exe to PATH”** during install
- **Optional:** `curl` on your PATH helps when fetching Metal Archives / Bandcamp pages (the app falls back to urllib)

## Quick start

### macOS / Linux

```bash
cd data_maintenance_tools
chmod +x setup.sh run.sh
./setup.sh
./run.sh --open-browser
```

Double-click **Run Data Entry.command** on macOS (runs setup automatically if needed).

### Windows

1. Open Command Prompt in this folder.
2. Run `setup.bat`, then `run.bat --open-browser`.

Or double-click `run.bat` (runs setup on first launch).

### Manual (any platform)

```bash
cd data_maintenance_tools
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp festival_data_entry.example.json festival_data_entry.json   # Windows: copy ...
python run_data_entry.py --open-browser
```

## First-time configuration

1. Open **http://127.0.0.1:8080/config**
2. Set festival name, pointer URL (if you have one), event year, and CSV paths.
3. Use **Load from pointer** to pull venues, dates, and days from historical schedule files linked by the pointer.
4. Save, then use **Schedule entry** and **Add band**.

Default CSV paths (relative to this folder):

- `./data/artistLineup.csv`
- `./data/artistSchedule.csv`

Empty files with correct headers are created automatically on first run.

## Web pages

| URL | Description |
|-----|-------------|
| `/config` | Festival settings and pointer introspection |
| `/schedule` | Add schedule rows |
| `/schedule/view` | View schedule |
| `/schedule/stats` | Schedule statistics |
| `/bands` | Add bands with Metal Archives / MusicBrainz discovery |

## Band discovery

- Paste a **Metal Archives** band URL, or a **MusicBrainz** artist URL, or enter a band name (MusicBrainz search).
- **YouTube** is always stored as a search URL (`official music video {band} {latest album}`), not a direct video link.
- Images prefer **Bandcamp** header logo, then Cover Art Archive album art.

## Command-line options

```
python run_data_entry.py [--port 8080] [--config /path/to/config.json] [--open-browser]
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Missing dependencies` | Run `setup.sh` or `setup.bat` |
| Port 8080 in use | `python run_data_entry.py --port 8090` |
| Empty band dropdown | Check lineup CSV path in config; ensure file exists |
| Discovery fails for a site | Install `curl`; check network/firewall |
| Windows “python not found” | Reinstall Python with PATH option, or use `py -3` in scripts |

## License / distribution

Ship this folder as-is. Do not commit `festival_data_entry.json` or real festival CSV data if they contain private paths; use the example config instead.
