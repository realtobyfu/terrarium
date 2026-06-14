#!/usr/bin/env python3
"""
seed_pois.py — Terrarium Stream A / US-A2
==========================================
Fetches San Francisco POI candidates from the Foursquare Places API and emits
schema-shaped JSON for hand-tagging.

Output format mirrors sf-pois.json:
  • Objective fields filled automatically: poiRef, name, category, neighborhood,
    coordinate, hoursRef, source ("foursquare"), specimenKind (category guess).
  • Subjective tag fields left blank/empty for a human curator to fill in:
    vibe, bestTime, weatherFit, goodFor, indoorOutdoor, price.

Usage:
  export FSQ_API_KEY="<your_key>"
  python3 tools/seed_pois.py > tools/sf-pois-candidates.json

  # Or specify output file:
  python3 tools/seed_pois.py --output tools/sf-pois-candidates.json

  # Limit results per category (default: 10):
  python3 tools/seed_pois.py --per-category 20

See tools/README.md for full setup instructions.

SECURITY: The API key is read from the FSQ_API_KEY environment variable.
          NEVER hard-code the key. NEVER commit the key or the output file
          (which may contain FSQ response data) to version control.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

FSQ_PLACES_SEARCH_URL = "https://api.foursquare.com/v3/places/search"
FSQ_PLACE_DETAILS_URL = "https://api.foursquare.com/v3/places/{fsq_id}"

# Foursquare category IDs → Terrarium POICategory
# Reference: https://developer.foursquare.com/docs/categories
FSQ_CATEGORY_MAP: dict[str, str] = {
    # Parks / Outdoors
    "16032": "park",       # Park
    "16017": "park",       # Garden
    "16019": "park",       # Hiking Trail
    "16025": "viewpoint",  # Scenic Lookout
    "16038": "viewpoint",  # Beach
    # Coffee
    "13032": "coffee",     # Coffee Shop
    "13059": "coffee",     # Cafe
    # Bookstores
    "17114": "bookstore",  # Bookstore
    # Restaurants / Food
    "13065": "restaurant", # Restaurant
    "13145": "restaurant", # Fast Food
    # Markets
    "17053": "market",     # Farmers Market
    "17051": "market",     # Grocery Store / Supermarket
    # Museums
    "10027": "museum",     # Museum
    "10024": "museum",     # Art Museum
    "10023": "museum",     # History Museum
    # Bars
    "13003": "bar",        # Bar
    "13006": "bar",        # Cocktail Bar
    "13271": "bar",        # Pub
}

# Terrarium category → specimenKind (FR-21)
SPECIMEN_KIND_MAP: dict[str, str] = {
    "park": "tree",
    "viewpoint": "tree",
    "coffee": "building",
    "bookstore": "building",
    "restaurant": "building",
    "market": "building",
    "museum": "building",
    "bar": "building",
    "other": "flowers",
}

# Foursquare category search queries per Terrarium category
SEARCH_QUERIES: list[dict] = [
    {"query": "park",          "terrarium_category": "park",       "categories": "16032,16017,16019"},
    {"query": "scenic lookout","terrarium_category": "viewpoint",  "categories": "16025,16038"},
    {"query": "coffee shop",   "terrarium_category": "coffee",     "categories": "13032,13059"},
    {"query": "bookstore",     "terrarium_category": "bookstore",  "categories": "17114"},
    {"query": "restaurant",    "terrarium_category": "restaurant", "categories": "13065"},
    {"query": "farmers market","terrarium_category": "market",     "categories": "17053,17051"},
    {"query": "museum",        "terrarium_category": "museum",     "categories": "10027,10024,10023"},
    {"query": "bar",           "terrarium_category": "bar",        "categories": "13003,13006,13271"},
    # "other" is a catch-all; seed with interesting SF landmarks
    {"query": "landmark",      "terrarium_category": "other",      "categories": ""},
]

# San Francisco bounding box (lat, lon degrees)
SF_NE = (37.83, -122.35)
SF_SW = (37.70, -122.52)
SF_CENTER_LL = "37.7749,-122.4194"  # Foursquare ll param


# ---------------------------------------------------------------------------
# Slug helpers
# ---------------------------------------------------------------------------

def slugify(text: str) -> str:
    """Convert a display name to a URL-safe slug."""
    slug = text.lower()
    slug = re.sub(r"[''']", "", slug)       # drop apostrophes
    slug = re.sub(r"[^a-z0-9]+", "-", slug) # non-alphanumeric → dash
    slug = slug.strip("-")
    return slug


def make_poi_ref(name: str) -> str:
    return f"poi.{slugify(name)}.sf"


# ---------------------------------------------------------------------------
# Foursquare API helpers
# ---------------------------------------------------------------------------

def _fsq_get(url: str, params: dict, api_key: str) -> dict:
    """Perform a GET request against the Foursquare v3 API."""
    full_url = f"{url}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(full_url, headers={
        "Accept": "application/json",
        "Authorization": api_key,
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
        print(f"[ERROR] HTTP {exc.code} from Foursquare: {body}", file=sys.stderr)
        raise
    except urllib.error.URLError as exc:
        print(f"[ERROR] Network error: {exc.reason}", file=sys.stderr)
        raise


def search_pois(
    api_key: str,
    terrarium_category: str,
    fsq_categories: str,
    query: str,
    limit: int,
) -> list[dict]:
    """Search FSQ Places for SF candidates in a given category."""
    params: dict = {
        "ll": SF_CENTER_LL,
        "radius": 15000,          # 15 km covers all of SF
        "limit": min(limit, 50),  # FSQ free tier max per request
        "fields": "fsq_id,name,geocodes,location,categories,hours",
    }
    if fsq_categories:
        params["categories"] = fsq_categories
    else:
        params["query"] = query

    result = _fsq_get(FSQ_PLACES_SEARCH_URL, params, api_key)
    return result.get("results", [])


def extract_neighborhood(location: dict) -> str:
    """Best-effort neighborhood from the Foursquare location object."""
    for key in ("neighborhood", "locality", "cross_street", "address"):
        val = location.get(key, "")
        if val:
            return val
    return "San Francisco"


def extract_hours_ref(fsq_id: str, hours: dict | None) -> str | None:
    """Build a stable hoursRef key from the FSQ ID if hours data exists."""
    if hours is None:
        return None
    return f"fsq.{fsq_id}"


def fsq_result_to_poi_candidate(result: dict, terrarium_category: str) -> dict:
    """
    Map a single Foursquare search result to an sf-pois.json–shaped dict.

    Subjective fields (vibe, bestTime, weatherFit, goodFor, indoorOutdoor,
    price) are left blank/empty for a human curator. The `source` is set to
    "foursquare" for provenance tracking (FR-3).
    """
    name: str = result.get("name", "Unknown")
    fsq_id: str = result.get("fsq_id", "")
    geocodes: dict = result.get("geocodes", {}).get("main", {})
    lat: float = geocodes.get("latitude", 0.0)
    lon: float = geocodes.get("longitude", 0.0)
    location: dict = result.get("location", {})
    hours: dict | None = result.get("hours")

    # Derive specimenKind from category (FR-21)
    specimen_kind = SPECIMEN_KIND_MAP.get(terrarium_category, "flowers")

    return {
        # ── Objective fields (auto-filled) ──────────────────────────────────
        "poiRef": make_poi_ref(name),
        "name": name,
        "category": terrarium_category,
        "neighborhood": extract_neighborhood(location),
        "coordinate": {"latitude": lat, "longitude": lon},
        "hoursRef": extract_hours_ref(fsq_id, hours),
        "specimenKind": specimen_kind,
        "source": "foursquare",
        # ── Subjective fields — LEAVE BLANK for hand-tagging ────────────────
        # Fill these in sf-pois.json before committing to the pilot catalog.
        "indoorOutdoor": "",        # "indoor" | "outdoor" | "mixed"
        "bestTime": [],             # ["morning","afternoon","evening","night"]
        "weatherFit": [],           # ["clear","cloudy","fog","rain","snow"]
        "goodFor": [],              # ["solo","date","group"]
        "vibe": [],                 # ["quiet","lively","cozy","scenic","quirky"]
        "price": "",                # "free" | "$" | "$$" | "$$$"
        # ── Debug metadata (strip before merging into sf-pois.json) ─────────
        "_fsq_id": fsq_id,
    }


# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------

def deduplicate(candidates: list[dict]) -> list[dict]:
    """Remove candidates with duplicate poiRef (last writer wins for FSQ data)."""
    seen: dict[str, dict] = {}
    for c in candidates:
        seen[c["poiRef"]] = c
    return list(seen.values())


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Fetch SF POI candidates from Foursquare and emit schema-shaped JSON."
    )
    parser.add_argument(
        "--per-category", type=int, default=10,
        help="Number of candidates to fetch per category (default: 10, max: 50).",
    )
    parser.add_argument(
        "--output", type=str, default=None,
        help="Output file path. Defaults to stdout.",
    )
    args = parser.parse_args()

    api_key = os.environ.get("FSQ_API_KEY", "").strip()
    if not api_key:
        print(
            "[ERROR] FSQ_API_KEY environment variable is not set.\n"
            "        Export it before running this script:\n"
            "          export FSQ_API_KEY=\"<your_foursquare_api_key>\"\n"
            "        Get a free key at https://foursquare.com/developers/",
            file=sys.stderr,
        )
        sys.exit(1)

    all_candidates: list[dict] = []
    for search in SEARCH_QUERIES:
        tc = search["terrarium_category"]
        print(f"[INFO] Fetching '{tc}' candidates…", file=sys.stderr)
        try:
            results = search_pois(
                api_key=api_key,
                terrarium_category=tc,
                fsq_categories=search["categories"],
                query=search["query"],
                limit=args.per_category,
            )
            candidates = [fsq_result_to_poi_candidate(r, tc) for r in results]
            all_candidates.extend(candidates)
            print(f"[INFO]   → {len(candidates)} candidates", file=sys.stderr)
        except Exception as exc:
            print(f"[WARN] Skipping '{tc}' due to error: {exc}", file=sys.stderr)
        # Be polite to the free-tier rate limiter
        time.sleep(0.3)

    unique = deduplicate(all_candidates)
    print(
        f"[INFO] Total: {len(all_candidates)} results, "
        f"{len(unique)} after deduplication.",
        file=sys.stderr,
    )

    output_json = json.dumps(unique, indent=2, ensure_ascii=False)

    if args.output:
        out_path = args.output
        with open(out_path, "w", encoding="utf-8") as fh:
            fh.write(output_json)
        print(f"[INFO] Written to {out_path}", file=sys.stderr)
    else:
        print(output_json)


if __name__ == "__main__":
    main()
