# Terrarium — `tools/`

Developer-only scripts for the Stream A POI catalog pipeline. These scripts are
**never** bundled into the app target (they live outside `Terrarium/`).

---

## `seed_pois.py` — Foursquare Places seeder (US-A2)

Fetches San Francisco POI candidates from the **Foursquare Places API** and
emits schema-shaped JSON for hand-tagging. Objective fields (name, coordinate,
neighborhood, hoursRef, category, specimenKind, source) are filled
automatically; subjective tag fields (`vibe`, `bestTime`, `weatherFit`,
`goodFor`, `indoorOutdoor`, `price`) are left blank for a curator to fill in.

### Prerequisites

| Requirement | Notes |
|---|---|
| Python 3.10+ | Only stdlib modules used; no `pip install` needed. |
| Foursquare developer account | Free tier at https://foursquare.com/developers/ |
| `FSQ_API_KEY` env var | **Never hard-code or commit the key.** |

### Setup

1. Create a free Foursquare developer account and generate an API key.
2. Export the key in your shell session (not `.env`, not `.zshrc` — ephemeral
   export only):

   ```bash
   export FSQ_API_KEY="fsq3..."
   ```

3. Verify the key is set:

   ```bash
   echo $FSQ_API_KEY
   ```

### Running

```bash
# Write candidates to stdout (pipe to file or jq)
python3 tools/seed_pois.py

# Write directly to a file
python3 tools/seed_pois.py --output tools/sf-pois-candidates.json

# Fetch more candidates per category (default: 10, max: 50 per FSQ free tier)
python3 tools/seed_pois.py --per-category 25 --output tools/sf-pois-candidates.json
```

### Output format

The output is a JSON array of objects shaped like `sf-pois.json`. Blank fields
need curator input before the entries are valid `POI` objects:

```json
[
  {
    "poiRef": "poi.sightglass-coffee.sf",
    "name": "Sightglass Coffee",
    "category": "coffee",
    "neighborhood": "SoMa",
    "coordinate": { "latitude": 37.7765, "longitude": -122.4089 },
    "hoursRef": "fsq.4b...",
    "specimenKind": "building",
    "source": "foursquare",

    // ← Fill these in before merging:
    "indoorOutdoor": "",
    "bestTime": [],
    "weatherFit": [],
    "goodFor": [],
    "vibe": [],
    "price": "",

    // ← Strip this debug field before merging:
    "_fsq_id": "4b..."
  }
]
```

### Curation workflow

1. Run the script to generate `tools/sf-pois-candidates.json`.
2. Open the file in your editor and fill in the blank tag fields for each POI.
   Refer to the schema doc in `tasks/prd-explore-drift-anchor.md` (FR-1).
3. Delete the `_fsq_id` debug fields.
4. Validate with a JSON linter (e.g. `python3 -m json.tool < file.json`).
5. Merge the hand-tagged entries into `Terrarium/Resources/sf-pois.json`.
6. Run `xcodebuild test` — `BundledPOICatalogTests` will catch malformed entries
   and enum mismatches automatically.

### Security notes

- `FSQ_API_KEY` is read **only** from the environment; it is never written to
  any file by this script.
- `tools/sf-pois-candidates.json` is in `.gitignore` — do not commit raw API
  output, which may contain venue IDs that Foursquare considers restricted data.
- The app target never reads from `tools/`; the script is dev-only.

---

## `.gitignore` additions

Ensure your project `.gitignore` includes:

```gitignore
tools/sf-pois-candidates.json
tools/*.json
```
