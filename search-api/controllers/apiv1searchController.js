'use strict';

// URLs of the individual APIs (injected via environment variables in Docker)
const SONGS_API_URL = process.env.SONGS_API_URL || 'http://localhost:3001';
const MOVIES_API_URL = process.env.MOVIES_API_URL || 'http://localhost:3002';
const FOOTBALL_API_URL = process.env.FOOTBALL_API_URL || 'http://localhost:3003';

/**
 * Extracts the year from a resource item depending on its type.
 * - Songs and Movies have a `releaseYear` integer field.
 * - Football teams have a `foundationDate` string (ISO date: "YYYY-MM-DD").
 */
function getYear(item, type) {
    if (type === 'football') {
        if (!item.foundationDate) return null;
        return new Date(item.foundationDate).getFullYear();
    }
    // Support both camelCase (releaseYear - songs) and snake_case (release_year - movies)
    return item.releaseYear ?? item.release_year ?? null;
}

/**
 * Checks if a given year matches the filter criteria:
 *   - year: exact match
 *   - minYear: year >= minYear
 *   - maxYear: year <= maxYear
 * Combinations work as a range (minYear + maxYear).
 */
function matchesFilter(itemYear, { year, minYear, maxYear }) {
    if (itemYear === null) return false;

    if (year !== undefined) {
        return itemYear === year;
    }

    const aboveMin = minYear !== undefined ? itemYear >= minYear : true;
    const belowMax = maxYear !== undefined ? itemYear <= maxYear : true;
    return aboveMin && belowMax;
}

/**
 * Fetches JSON from a URL, returns empty array on failure so that
 * one broken API does not bring down the whole search.
 */
async function safeFetch(url, label) {
    try {
        const { default: fetch } = await import('node-fetch');
        const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
        if (!response.ok) {
            console.error(`[search] ${label} responded with ${response.status}`);
            return [];
        }
        return await response.json();
    } catch (err) {
        console.error(`[search] Error fetching ${label}: ${err.message}`);
        return [];
    }
}

/**
 * GET /api/v1/search
 * operationId: search  ← must match the operationId in oas-doc.yaml
 */
module.exports.search = async function search(req, res) {
    // Parse query params (OASTools already validates types)
    const year = req.query.year !== undefined ? parseInt(req.query.year) : undefined;
    const minYear = req.query.minYear !== undefined ? parseInt(req.query.minYear) : undefined;
    const maxYear = req.query.maxYear !== undefined ? parseInt(req.query.maxYear) : undefined;

    // At least one filter must be provided
    if (year === undefined && minYear === undefined && maxYear === undefined) {
        return res.status(400).json({
            message: 'At least one query parameter must be provided: year, minYear or maxYear'
        });
    }

    const filter = { year, minYear, maxYear };

    // Call all three APIs in parallel
    const [songs, movies, footballTeams] = await Promise.all([
        safeFetch(`${SONGS_API_URL}/api/v1/songs`, 'Songs API'),
        safeFetch(`${MOVIES_API_URL}/api/v1/movies`, 'Movies API'),
        safeFetch(`${FOOTBALL_API_URL}/api/v1/footballteams`, 'Football API')
    ]);

    // Filter each result set by year
    const filteredSongs = songs.filter(s => matchesFilter(getYear(s, 'song'), filter));
    const filteredMovies = movies.filter(m => matchesFilter(getYear(m, 'movie'), filter));
    const filteredTeams = footballTeams.filter(t => matchesFilter(getYear(t, 'football'), filter));

    return res.status(200).json({
        songs: filteredSongs,
        movies: filteredMovies,
        footballTeams: filteredTeams
    });
};
