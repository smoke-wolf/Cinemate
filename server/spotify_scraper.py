"""Spotify + Wikipedia artist enrichment — no API credentials required.

Uses Spotify's anonymous web-player token to search artists and fetch metadata,
and Wikipedia's REST API for artist bios. Designed for async FastAPI usage.
"""

import asyncio
import logging
import re
import time
import urllib.parse
from datetime import datetime
from typing import Optional

import aiohttp

logger = logging.getLogger("cinemate.spotify")

# ---------------------------------------------------------------------------
# Anonymous token management
# ---------------------------------------------------------------------------

SPOTIFY_TOKEN_URL = "https://open.spotify.com/get_access_token?reason=transport&productType=web-player"
SPOTIFY_API_BASE = "https://api.spotify.com/v1"
WIKIPEDIA_API_BASE = "https://en.wikipedia.org/api/rest_v1/page/summary"
MUSICBRAINZ_API_BASE = "https://musicbrainz.org/ws/2"
MUSICBRAINZ_UA = "CinemateApp/1.0 (maliq@cinemate.app)"

# Genre keywords for extracting genres from Wikipedia bio text (last-resort fallback)
_WIKI_GENRE_KEYWORDS = [
    # Multi-word genres first (longer patterns matched before shorter ones)
    "singer-songwriter", "art pop", "dream pop", "hip hop", "lo-fi",
    "post-punk", "r&b", "synthpop", "shoegaze", "grunge", "emo",
    "hardcore", "acoustic", "experimental",
    # Single-word genres
    "pop", "rock", "indie", "electronic", "jazz", "classical", "folk",
    "country", "metal", "punk", "soul", "funk", "blues", "reggae",
    "dance", "alternative", "ambient",
]


class SpotifyScraper:
    """Scrapes Spotify artist data using anonymous tokens + Wikipedia bios."""

    def __init__(self):
        self._token: Optional[str] = None
        self._token_expires: float = 0

    async def _get_token(self) -> Optional[str]:
        """Fetch or return cached anonymous Spotify access token."""
        if self._token and time.time() < self._token_expires:
            return self._token

        try:
            async with aiohttp.ClientSession() as session:
                headers = {
                    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                                  "Chrome/120.0.0.0 Safari/537.36",
                    "Accept": "application/json",
                }
                async with session.get(
                    SPOTIFY_TOKEN_URL, headers=headers, timeout=aiohttp.ClientTimeout(total=10)
                ) as resp:
                    if resp.status != 200:
                        logger.warning("Spotify token request returned %d", resp.status)
                        return None
                    data = await resp.json()

            token = data.get("accessToken")
            if not token:
                logger.warning("Spotify token response missing accessToken field")
                return None

            # Token typically lasts ~1 hour; expire 5 minutes early to be safe.
            expires_ms = data.get("accessTokenExpirationTimestampMs", 0)
            if expires_ms:
                self._token_expires = (expires_ms / 1000) - 300
            else:
                self._token_expires = time.time() + 3300  # fallback: 55 min

            self._token = token
            logger.info("Obtained anonymous Spotify token (expires in %d min)",
                        int((self._token_expires - time.time()) / 60))
            return self._token

        except Exception as exc:
            logger.error("Failed to get Spotify anonymous token: %s", exc)
            return None

    async def _spotify_get(self, path: str, params: Optional[dict] = None) -> Optional[dict]:
        """Make an authenticated GET to the Spotify API. Refreshes token on 401."""
        for attempt in range(2):
            token = await self._get_token()
            if not token:
                return None

            try:
                async with aiohttp.ClientSession() as session:
                    headers = {"Authorization": f"Bearer {token}"}
                    async with session.get(
                        f"{SPOTIFY_API_BASE}{path}",
                        headers=headers,
                        params=params,
                        timeout=aiohttp.ClientTimeout(total=10),
                    ) as resp:
                        if resp.status == 401 and attempt == 0:
                            logger.info("Spotify token expired, refreshing")
                            self._token = None
                            self._token_expires = 0
                            continue
                        if resp.status != 200:
                            logger.warning("Spotify API %s returned %d", path, resp.status)
                            return None
                        return await resp.json()
            except Exception as exc:
                logger.error("Spotify API request failed: %s", exc)
                return None

        return None

    async def search_artist(self, name: str) -> Optional[dict]:
        """Search Spotify for an artist, return best match metadata.

        Returns dict with: spotify_id, name, genres, image_url, popularity, followers
        or None if not found.
        """
        data = await self._spotify_get("/search", params={
            "q": name,
            "type": "artist",
            "limit": "5",
        })
        if not data:
            return None

        items = data.get("artists", {}).get("items", [])
        if not items:
            logger.info("No Spotify results for artist '%s'", name)
            return None

        # Pick best match: prefer exact name match, fall back to first result
        best = items[0]
        name_lower = name.lower().strip()
        for item in items:
            if item.get("name", "").lower().strip() == name_lower:
                best = item
                break

        # Extract largest image
        images = best.get("images", [])
        image_url = images[0]["url"] if images else None

        return {
            "spotify_id": best.get("id"),
            "name": best.get("name"),
            "genres": ", ".join(best.get("genres", [])),
            "image_url": image_url,
            "popularity": best.get("popularity"),
            "followers": best.get("followers", {}).get("total"),
        }

    async def _musicbrainz_genres(self, name: str) -> list[str]:
        """Fetch artist genres from MusicBrainz as a fallback when Spotify fails.

        Searches for the artist, picks the best name match, then fetches tags.
        Returns a list of genre strings (may be empty).
        """
        headers = {
            "User-Agent": MUSICBRAINZ_UA,
            "Accept": "application/json",
        }
        timeout = aiohttp.ClientTimeout(total=15)

        try:
            # Step 1: search for artist
            encoded_name = urllib.parse.quote(name, safe="")
            search_url = (
                f"{MUSICBRAINZ_API_BASE}/artist/"
                f"?query=artist:{encoded_name}&fmt=json&limit=5"
            )
            async with aiohttp.ClientSession() as session:
                async with session.get(search_url, headers=headers, timeout=timeout) as resp:
                    if resp.status != 200:
                        logger.warning("MusicBrainz search returned %d for '%s'", resp.status, name)
                        return []
                    search_data = await resp.json()

            artists = search_data.get("artists", [])
            if not artists:
                logger.debug("MusicBrainz: no results for '%s'", name)
                return []

            # Pick best name match
            name_lower = name.lower().strip()
            best = artists[0]
            for artist in artists:
                if artist.get("name", "").lower().strip() == name_lower:
                    best = artist
                    break

            mbid = best.get("id")
            if not mbid:
                return []

            logger.debug("MusicBrainz: matched '%s' -> %s (id=%s)",
                         name, best.get("name"), mbid)

            # Rate limit: MusicBrainz requires 1 second between requests
            await asyncio.sleep(1.0)

            # Step 2: fetch tags for the matched artist
            tags_url = f"{MUSICBRAINZ_API_BASE}/artist/{mbid}?inc=tags&fmt=json"
            async with aiohttp.ClientSession() as session:
                async with session.get(tags_url, headers=headers, timeout=timeout) as resp:
                    if resp.status != 200:
                        logger.warning("MusicBrainz tags request returned %d for mbid %s",
                                       resp.status, mbid)
                        return []
                    tags_data = await resp.json()

            tags = tags_data.get("tags", [])
            # Filter to tags with count > 0 and return genre names
            genres = [
                tag["name"]
                for tag in tags
                if isinstance(tag, dict) and tag.get("count", 0) > 0 and tag.get("name")
            ]

            if genres:
                logger.info("MusicBrainz genres for '%s': %s", name, ", ".join(genres))
            else:
                logger.debug("MusicBrainz: no tags with count > 0 for '%s'", name)

            return genres

        except Exception as exc:
            logger.error("MusicBrainz lookup failed for '%s': %s", name, exc)
            return []

    async def get_artist_bio(self, name: str) -> Optional[dict]:
        """Fetch artist bio from Wikipedia.

        Returns dict with: bio (first 2-3 paragraphs), wikipedia_url
        or None if not found.
        """
        try:
            # Search Wikipedia for the artist
            encoded = urllib.parse.quote(name.replace(" ", "_"), safe="")
            url = f"{WIKIPEDIA_API_BASE}/{encoded}"

            async with aiohttp.ClientSession() as session:
                headers = {
                    "User-Agent": "CinemateApp/1.0 (artist bio enrichment)",
                    "Accept": "application/json",
                }
                async with session.get(
                    url, headers=headers, timeout=aiohttp.ClientTimeout(total=10)
                ) as resp:
                    if resp.status == 404:
                        # Try appending common disambiguations
                        for suffix in ["_(musician)", "_(singer)", "_(band)", "_(rapper)"]:
                            alt_url = f"{WIKIPEDIA_API_BASE}/{encoded}{suffix}"
                            async with session.get(
                                alt_url, headers=headers, timeout=aiohttp.ClientTimeout(total=10)
                            ) as alt_resp:
                                if alt_resp.status == 200:
                                    data = await alt_resp.json()
                                    if data.get("type") != "disambiguation":
                                        return self._parse_wiki_bio(data)
                        logger.info("No Wikipedia article for '%s'", name)
                        return None

                    if resp.status != 200:
                        logger.warning("Wikipedia API returned %d for '%s'", resp.status, name)
                        return None

                    data = await resp.json()

            # Skip disambiguation pages
            if data.get("type") == "disambiguation":
                logger.info("Wikipedia disambiguation page for '%s', skipping", name)
                return None

            return self._parse_wiki_bio(data)

        except Exception as exc:
            logger.error("Wikipedia lookup failed for '%s': %s", name, exc)
            return None

    @staticmethod
    def _parse_wiki_bio(data: dict) -> Optional[dict]:
        """Extract bio text, URL, and any genre hints from Wikipedia summary response."""
        extract = data.get("extract", "").strip()
        if not extract:
            return None

        # Wikipedia summary endpoint already returns a concise extract (2-3 paragraphs)
        wiki_url = data.get("content_urls", {}).get("desktop", {}).get("page")

        # --- Genre extraction from bio text (last-resort fallback) ---
        # Look for patterns like "is an American pop singer", "is a British rock band",
        # "genres include pop, rock, and electronic", etc.
        bio_lower = extract.lower()
        found_genres: list[str] = []

        # Build a regex alternation from the keyword list (longest first to avoid
        # partial matches, e.g. "post-punk" before "punk")
        sorted_kw = sorted(_WIKI_GENRE_KEYWORDS, key=len, reverse=True)
        genre_alt = "|".join(re.escape(g) for g in sorted_kw)

        # Pattern 1: "is a/an {nationality} {genre} {artist-type}" —
        #   e.g. "is an Australian indie pop singer-songwriter"
        #   Capture all genre keywords between "is a(n) ..." and a role word.
        role_words = (
            r"(?:singer|band|group|duo|trio|musician|rapper|artist|producer|DJ|"
            r"songwriter|vocalist|ensemble|collective|act|project|performer)"
        )
        pattern1 = re.compile(
            r"\bis\s+(?:an?\s+)(?:\w+\s+)*?(" + genre_alt + r")(?:[,/\s-]+(?:" + genre_alt + r"))*",
            re.IGNORECASE,
        )
        for m in pattern1.finditer(bio_lower):
            span = bio_lower[m.start():m.end() + 40]  # grab a bit extra for chained genres
            for kw in sorted_kw:
                if kw in span and kw not in found_genres:
                    found_genres.append(kw)

        # Pattern 2: "genres include ..." / "musical genres such as ..."
        pattern2 = re.compile(
            r"genres?\s+(?:include|such as|ranging from|incorporat\w+|blend\w*|span\w*)\s+(.{5,120})",
            re.IGNORECASE,
        )
        for m in pattern2.finditer(bio_lower):
            chunk = m.group(1)
            for kw in sorted_kw:
                if kw in chunk and kw not in found_genres:
                    found_genres.append(kw)

        # Pattern 3: standalone "{genre} music" anywhere in bio
        pattern3 = re.compile(r"\b(" + genre_alt + r")\s+music\b", re.IGNORECASE)
        for m in pattern3.finditer(bio_lower):
            kw = m.group(1).lower()
            if kw not in found_genres:
                found_genres.append(kw)

        genres_from_bio = ", ".join(found_genres) if found_genres else None

        result = {
            "bio": extract,
            "wikipedia_url": wiki_url,
        }
        if genres_from_bio:
            result["genres_from_bio"] = genres_from_bio

        return result

    async def enrich_artist(self, name: str) -> Optional[dict]:
        """Combine Spotify + Wikipedia data into a dict ready for DB insert.

        Genre fallback chain:
            1. Spotify genres (if Spotify lookup succeeds)
            2. MusicBrainz tags (if Spotify returns no genres or fails entirely)
            3. Genres extracted from Wikipedia bio text (last resort)

        Returns dict matching music_artists table columns, or None on total failure.
        """
        # Run both lookups concurrently
        spotify_task = self.search_artist(name)
        wiki_task = self.get_artist_bio(name)
        spotify_data, wiki_data = await asyncio.gather(spotify_task, wiki_task)

        if not spotify_data and not wiki_data:
            logger.info("No enrichment data found for '%s'", name)
            return None

        result = {
            "name": name,
            "bio": None,
            "image_url": None,
            "genres": None,
            "spotify_id": None,
            "popularity": None,
            "followers": None,
            "wikipedia_url": None,
            "enriched_at": datetime.utcnow().isoformat(),
        }

        if spotify_data:
            result["name"] = spotify_data.get("name", name)  # use Spotify's canonical name
            result["image_url"] = spotify_data.get("image_url")
            result["genres"] = spotify_data.get("genres") or None
            result["spotify_id"] = spotify_data.get("spotify_id")
            result["popularity"] = spotify_data.get("popularity")
            result["followers"] = spotify_data.get("followers")

        if wiki_data:
            result["bio"] = wiki_data.get("bio")
            result["wikipedia_url"] = wiki_data.get("wikipedia_url")

        # --- Genre fallback chain ---
        if not result["genres"]:
            # Fallback 1: MusicBrainz
            logger.info("No Spotify genres for '%s', trying MusicBrainz fallback", name)
            mb_genres = await self._musicbrainz_genres(name)
            if mb_genres:
                result["genres"] = ", ".join(mb_genres)
                logger.info("MusicBrainz provided genres for '%s': %s", name, result["genres"])

        if not result["genres"] and wiki_data and wiki_data.get("genres_from_bio"):
            # Fallback 2: genres extracted from Wikipedia bio text
            result["genres"] = wiki_data["genres_from_bio"]
            logger.info("Wikipedia bio provided genres for '%s': %s", name, result["genres"])

        return result


# ---------------------------------------------------------------------------
# Standalone helpers
# ---------------------------------------------------------------------------

_scraper_instance: Optional[SpotifyScraper] = None


def _get_scraper() -> SpotifyScraper:
    """Lazy singleton so the token cache is reused across calls."""
    global _scraper_instance
    if _scraper_instance is None:
        _scraper_instance = SpotifyScraper()
    return _scraper_instance


async def classify_genre(artist_name: str, existing_genre: Optional[str] = None) -> Optional[str]:
    """Look up genres for an artist if the existing genre is empty.

    If existing_genre already has a value, returns it unchanged.
    Otherwise queries Spotify -> MusicBrainz -> Wikipedia bio and returns
    a comma-separated genre string, or None if all lookups fail.
    """
    if existing_genre and existing_genre.strip():
        return existing_genre

    scraper = _get_scraper()
    enriched = await scraper.enrich_artist(artist_name)
    if enriched and enriched.get("genres"):
        return enriched["genres"]
    return None


async def enrich_library_genres(db) -> dict:
    """Backfill NULL/empty genres on music_tracks and music_albums tables.

    Args:
        db: An aiosqlite database connection.

    Returns:
        Summary dict with counts of artists looked up and tracks/albums updated.
    """
    scraper = _get_scraper()

    # Find distinct artists with tracks that have no genre
    cursor = await db.execute("""
        SELECT DISTINCT artist FROM music_tracks
        WHERE genre IS NULL OR genre = '' OR TRIM(genre) = ''
    """)
    track_artists = await cursor.fetchall()

    # Also check albums
    cursor = await db.execute("""
        SELECT DISTINCT artist FROM music_albums
        WHERE genre IS NULL OR genre = '' OR TRIM(genre) = ''
    """)
    album_artists = await cursor.fetchall()

    # Combine unique artist names
    all_artists = set()
    for row in track_artists:
        name = row[0] if isinstance(row, tuple) else row["artist"]
        if name and name.strip() and name.lower() != "unknown artist":
            all_artists.add(name.strip())
    for row in album_artists:
        name = row[0] if isinstance(row, tuple) else row["artist"]
        if name and name.strip() and name.lower() != "unknown artist":
            all_artists.add(name.strip())

    if not all_artists:
        logger.info("No artists with missing genres found")
        return {"artists_checked": 0, "tracks_updated": 0, "albums_updated": 0}

    logger.info("Enriching genres for %d artists", len(all_artists))

    artists_checked = 0
    tracks_updated = 0
    albums_updated = 0

    for artist_name in sorted(all_artists):
        enriched = await scraper.enrich_artist(artist_name)
        artists_checked += 1

        if enriched and enriched.get("genres"):
            genres = enriched["genres"]

            # Update tracks
            result = await db.execute("""
                UPDATE music_tracks SET genre = ?
                WHERE artist = ? AND (genre IS NULL OR genre = '' OR TRIM(genre) = '')
            """, (genres, artist_name))
            tracks_updated += result.rowcount

            # Update albums
            result = await db.execute("""
                UPDATE music_albums SET genre = ?
                WHERE artist = ? AND (genre IS NULL OR genre = '' OR TRIM(genre) = '')
            """, (genres, artist_name))
            albums_updated += result.rowcount

            logger.info("  %s -> %s (%d tracks, %d albums)",
                        artist_name, genres, result.rowcount, result.rowcount)
        else:
            logger.debug("  %s -> no genres found (Spotify + MusicBrainz + Wikipedia)", artist_name)

        # Rate limit: 1 request per second (MusicBrainz has its own internal delay too)
        await asyncio.sleep(1.0)

    await db.commit()
    logger.info("Genre enrichment complete: %d artists checked, %d tracks updated, %d albums updated",
                artists_checked, tracks_updated, albums_updated)

    return {
        "artists_checked": artists_checked,
        "tracks_updated": tracks_updated,
        "albums_updated": albums_updated,
    }
