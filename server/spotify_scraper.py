"""Spotify + Wikipedia artist enrichment — no API credentials required.

Uses Spotify's anonymous web-player token to search artists and fetch metadata,
and Wikipedia's REST API for artist bios. Designed for async FastAPI usage.
"""

import asyncio
import logging
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
        """Extract bio text and URL from Wikipedia summary response."""
        extract = data.get("extract", "").strip()
        if not extract:
            return None

        # Wikipedia summary endpoint already returns a concise extract (2-3 paragraphs)
        wiki_url = data.get("content_urls", {}).get("desktop", {}).get("page")

        return {
            "bio": extract,
            "wikipedia_url": wiki_url,
        }

    async def enrich_artist(self, name: str) -> Optional[dict]:
        """Combine Spotify + Wikipedia data into a dict ready for DB insert.

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
    Otherwise queries Spotify and returns a comma-separated genre string,
    or None if the lookup fails.
    """
    if existing_genre and existing_genre.strip():
        return existing_genre

    scraper = _get_scraper()
    data = await scraper.search_artist(artist_name)
    if data and data.get("genres"):
        return data["genres"]
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
        data = await scraper.search_artist(artist_name)
        artists_checked += 1

        if data and data.get("genres"):
            genres = data["genres"]

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
            logger.debug("  %s -> no genres found on Spotify", artist_name)

        # Rate limit: 1 request per second
        await asyncio.sleep(1.0)

    await db.commit()
    logger.info("Genre enrichment complete: %d artists checked, %d tracks updated, %d albums updated",
                artists_checked, tracks_updated, albums_updated)

    return {
        "artists_checked": artists_checked,
        "tracks_updated": tracks_updated,
        "albums_updated": albums_updated,
    }
