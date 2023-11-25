-------- Data Cleaning and Preparation --------
-- Handling missing values in key column
UPDATE spotify
SET song_key = 'Unknown'
WHERE song_key IS NULL;

-- Removing duplicate records
WITH DuplicateCTE AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY track_name ORDER BY released_year DESC) AS RowNum
  FROM spotify
)
DELETE FROM DuplicateCTE WHERE RowNum > 1;

-- Adding a released_date column
ALTER TABLE spotify
ADD COLUMN release_date DATE;

UPDATE spotify
SET release_date = STR_TO_DATE(CONCAT(released_year, '-', released_month, '-', released_day), '%Y-%m-%d');

/* Analysis */
----------- Basic Analysis -----------
-- Most Popular Songs
SELECT track_name, SUM(streams) as total_streams
FROM spotify
GROUP BY track_name
ORDER BY total_streams DESC;

-- Release Date Analysis
SELECT released_year, AVG(streams) as avg_streams
FROM spotify
GROUP BY released_year
ORDER BY released_year DESC;


SELECT released_year, released_month, AVG(streams) as avg_streams
FROM spotify
GROUP BY released_year, released_month
ORDER BY released_year DESC;

-- Artist Impact
SELECT 
	artist_count, 
	AVG(in_spotify_charts) as avg_spotify_charts, 
	AVG(in_apple_charts) as avg_apple_charts, 
	AVG(in_deezer_charts) as avg_deezer_charts,
	AVG(streams) as avg_sreams
FROM spotify
GROUP BY artist_count
ORDER BY artist_count;

-- Top Songs based on streams
SELECT track_name, artists_name, streams
FROM spotify
ORDER BY streams DESC
LIMIT 5;

-- Popular Artists based on total streams
SELECT artist_name, SUM(streams) AS total_streams
FROM spotify
GROUP BY artist_name
ORDER BY total_streams DESC
LIMIT 5;

-- Temporal Trends in streams
SELECT released_year, released_month, SUM(streams) AS monthly_streams
FROM spotify
GROUP BY released_year, released_month
ORDER BY released_year, released_month;

-------------- Intermediate Analysis ---------------
-- Correlation between streams and danceability
SELECT track_name, streams, danceability_percentage
FROM spotify
ORDER BY streams DESC
LIMIT 10;

-- Playlist Impact analysis
SELECT in_spotify_playlists, in_apple_playlists, in_deezer_playlists, streams
FROM spotify
ORDER BY streams DESC
LIMIT 10;

----------------- Major KPIs ----------------------
-- Average Streams per Day:
SELECT
  AVG(streams / TIMESTAMPDIFF(DAY, min_release_date, NOW())) AS avg_streams_per_day
FROM (
  SELECT
    streams,
    MIN(STR_TO_DATE(CONCAT(released_year, '-', released_month, '-', released_day), '%Y-%m-%d')) AS min_release_date
  FROM spotify
  GROUP BY streams
) AS subquery;

-- Number of Unique Artists
SELECT
  COUNT(DISTINCT artists_name) AS unique_artists
FROM
  spotify;

-- Monthly Temporal Trends
SELECT
  released_year,
  released_month,
  SUM(streams) AS monthly_streams
FROM
  spotify
GROUP BY
  released_year, released_month
ORDER BY
  released_year, released_month;
  
-- Collaborative Impacts on Streams
SELECT
  artists_name,
  COUNT(track_name) AS songs_collaborated,
  AVG(streams) AS avg_streams
FROM
  spotify
WHERE
  artist_count > 1
GROUP BY
  artists_name
ORDER BY
  avg_streams DESC
LIMIT 5;

-- Seasonal Trend Analysis
SELECT
  CASE
    WHEN released_month IN (12, 1, 2) THEN 'Winter'
    WHEN released_month IN (3, 4, 5) THEN 'Spring'
    WHEN released_month IN (6, 7, 8) THEN 'Summer'
    ELSE 'Fall'
  END AS season,
  AVG(streams) AS avg_streams
FROM
  spotify
GROUP BY season
ORDER BY avg_streams DESC;

-- Speechiness vs Valence Analysis
SELECT
  track_name,
  speechiness_percent,
  valence_percent
FROM
  spotify
ORDER BY
  valence_percent DESC
LIMIT 10;

----------------- Subquery Analysis -----------------
-- Question: Which songs have more streams than the average streams for their respective artists?
SELECT track_name, artists_name, streams
FROM spotify s
WHERE streams > (
  SELECT AVG(streams)
  FROM spotify AS sub
  WHERE sub.artists_name = s.artists_name
);

-- Question: List songs that have user interactions in the UserEngagement table
SELECT track_name, artists_name, streams
FROM spotify s
WHERE EXISTS (
  SELECT 1
  FROM spotify sp
  WHERE sp.track_name = s.track_name
);

-- Question: What percentage of total streams does each artist contribute?
SELECT artists_name, 
       SUM(streams) / (SELECT SUM(streams) FROM spotify) * 100 AS percentage_contribution
FROM spotify
GROUP BY artists_name;

-- Question: Find the average streams per artist, considering only artists with more than 3 songs.
SELECT AVG(avg_streams) AS overall_average_streams
FROM (
  SELECT artists_name, AVG(streams) AS avg_streams
  FROM spotify
  GROUP BY artists_name
  HAVING COUNT(track_name) > 3
) AS artist_avg_streams;

-- Question: Find the artist(s) with the highest average streams, and then list their top song(s).
SELECT track_name, artists_name, streams
FROM spotify
WHERE artists_name = (
  SELECT artists_name
  FROM spotify
  GROUP BY artists_name
  ORDER BY AVG(streams) DESC
  LIMIT 1
)
ORDER BY streams DESC;

-- Question: Find songs released in the same month as the song "Cruel Summer" by Taylor Swift.
SELECT track_name, artists_name, released_year, released_month
FROM spotify
WHERE (released_year, released_month) = (
  SELECT released_year, released_month
  FROM spotify
  WHERE track_name = 'Cruel Summer'
);

-- Question: List songs with a higher danceability than the average danceability of the top 5 streamed songs.
SELECT track_name, artists_name, danceability_percent
FROM spotify
WHERE danceability_percent > (
  SELECT AVG(danceability_percent)
  FROM spotify
  ORDER BY streams DESC
  LIMIT 5
);

-- Question: Find songs that have more streams than the song with the lowest streams by each artist.
SELECT track_name, artists_name, streams
FROM spotify s
WHERE streams > (
  SELECT MIN(streams)
  FROM spotify AS sub
  WHERE sub.artists_name = s.artists_name
);

-- Question: Rank songs within each artist based on streams, and then select the top 3 ranked songs.
SELECT track_name, artists_name, streams, ranks
FROM (
  SELECT track_name, artists_name, streams,
         RANK() OVER (PARTITION BY artists_name ORDER BY streams DESC) AS ranks
  FROM spotify
) AS ranked_songs
WHERE ranks <= 3;

-- Question: List songs with streams higher than the average streams of songs released in the same year.
SELECT track_name, artists_name, streams
FROM spotify s
WHERE streams > (
  SELECT AVG(streams)
  FROM spotify
  WHERE released_year = s.released_year
);

-- Using Subquery for Top-N Analysis:
-- Question: Rank artists based on the sum of their top 3 streamed songs.

WITH RankedSongs AS (
  SELECT
    artists_name,
    streams,
    ROW_NUMBER() OVER (PARTITION BY artists_name ORDER BY streams DESC) AS ranks
  FROM spotify
)

SELECT
  artists_name,
  SUM(streams) AS total_top3_streams
FROM RankedSongs
WHERE ranks <= 3
GROUP BY artists_name
ORDER BY total_top3_streams DESC;

-- Predictive Modeling - Random Forest Example
WITH FeatureEngineered AS (
  SELECT
    track_name,
    artists_name,
    danceability_percent AS X1,
    valence_percent AS X2,
    danceability_percent * valence_percent AS interaction,
    streams
  FROM
    spotify
)
SELECT track_name, artists_name, X1, X2, interaction, streams
FROM FeatureEngineered
ORDER BY streams DESC;


----------- Time Series Analysis ------------
-- Time Series Analysis
WITH TimeSeriesAnalysis AS (
  SELECT
    release_date,
    AVG(streams) OVER (ORDER BY release_date ROWS BETWEEN 7 PRECEDING AND CURRENT ROW) AS avg_streams_7d
  FROM
    spotify
)
SELECT release_date, avg_streams_7d
FROM TimeSeriesAnalysis
ORDER BY release_date;

-- Advanced Analysis: Top 5 Artists with Consistent Growth in Streams (using provided dataset)
WITH ArtistGrowth AS (
  SELECT
    artists_name,
    released_year,
    released_month,
    SUM(streams) AS total_streams,
    ROW_NUMBER() OVER (PARTITION BY artists_name ORDER BY released_year, released_month) AS month_rank
  FROM spotify
  GROUP BY artists_name, released_year, released_month
)
SELECT
  artists_name,
  AVG(total_streams) AS avg_monthly_streams
FROM ArtistGrowth
WHERE month_rank <= 5
GROUP BY artists_name
ORDER BY avg_monthly_streams DESC
LIMIT 5;

-- Outlier Detection
SELECT track_name, artist_name, streams
FROM (
  SELECT
    track_name,
    artist_name,
    streams,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY streams) OVER () AS high_percentile,
    PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY streams) OVER () AS low_percentile
  FROM YourTableName
) AS PercentileData
WHERE streams > high_percentile OR streams < low_percentile
ORDER BY streams DESC;



