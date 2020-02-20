-- turning timing on
\timing
-- transforms the geometries to a projected (i.e, x,y) system and snaps to the
-- nearest metre. Was using GDA2020 (7845), now using MGA Zone 55 (28355)
ALTER TABLE roads
 ALTER COLUMN geom TYPE geometry(LineString,28355)
  USING ST_SnapToGrid(ST_Transform(geom,28355),1);

-- determine if the road segment is a bridge or tunnel
ALTER TABLE roads ADD COLUMN bridge_or_tunnel BOOLEAN;
UPDATE roads
  SET bridge_or_tunnel =
       CASE WHEN other_tags LIKE '%bridge%' OR other_tags LIKE '%tunnel%' THEN TRUE
       ELSE FALSE END;

-- find the bridge-bridge or road-road intersections
DROP TABLE IF EXISTS line_intersections;
CREATE TABLE line_intersections AS
SELECT a.osm_id AS osm_id_a, b.osm_id AS osm_id_b,
  ST_Intersection(a.geom,b.geom) AS geom
FROM roads AS a, roads AS b
WHERE a.osm_id < b.osm_id AND
  a.bridge_or_tunnel = b.bridge_or_tunnel AND
  ST_Intersects(a.geom, b.geom) = TRUE;

-- group the intersections by osm_id
DROP TABLE IF EXISTS line_intersections_grouped;
CREATE TABLE line_intersections_grouped AS
SELECT c.osm_id, st_unaryunion(st_collect(c.geom)) AS geom
FROM
 (SELECT a.osm_id_a AS osm_id, a.geom
  FROM line_intersections as a
  UNION
  SELECT b.osm_id_b AS osm_id, b.geom
  FROM line_intersections AS b) AS c
GROUP BY osm_id;

-- take the intersections, buffer them 0.1m, and use them to cut the lines they
-- intersect. We then snap to the nearest metre, ensuring there are no gaps.
-- Only intersections with the same osm_id need to be considered
DROP TABLE IF EXISTS line_cut;
CREATE TABLE line_cut AS
SELECT a.osm_id,
(ST_Dump(ST_SnapToGrid(ST_Difference(a.geom,ST_Buffer(b.geom,0.1)),1))).geom AS geom
FROM roads AS a, line_intersections_grouped AS b
WHERE a.osm_id = b.osm_id;

-- all the osm_ids currently processed. Some segments don't have any
-- intersections so they will need to be added. Adding an index here to speedup
-- processing
DROP TABLE IF EXISTS unique_ids;
CREATE TABLE unique_ids AS
SELECT DISTINCT osm_id
FROM line_cut;
CREATE UNIQUE INDEX osm_id_idx ON unique_ids (osm_id);

-- adding the remaining road segments
INSERT INTO line_cut
SELECT a.osm_id, a.geom
FROM roads AS a,
 (SELECT osm_id
  FROM roads
  EXCEPT
  SELECT osm_id
  FROM unique_ids) AS b
WHERE a.osm_id = b.osm_id;
ALTER TABLE line_cut ADD COLUMN length INTEGER;
UPDATE line_cut SET length = ST_Length(geom);
CREATE INDEX line_cut_gix ON line_cut USING GIST (geom);

-- find all of the road segment endpoints, including the new ones we've added
-- from the intersections
DROP TABLE IF EXISTS endpoints;
CREATE TABLE endpoints AS
SELECT ST_StartPoint(a.geom) as geom
FROM line_cut as a
UNION
SELECT ST_EndPoint(b.geom) as geom
FROM line_cut as b;
CREATE INDEX endpoints_gix ON endpoints USING GIST (geom);

-- cluster the endpoints to assign each unique endpoint location an id
DROP TABLE IF EXISTS endpoints_clustered;
CREATE TABLE endpoints_clustered AS
SELECT (ST_Dump(a.geom)).geom AS geom
FROM
 (SELECT ST_Union(geom) AS geom
  FROM endpoints) AS a;
ALTER TABLE endpoints_clustered ADD COLUMN id SERIAL PRIMARY KEY;
CREATE INDEX endpoints_clustered_gix ON endpoints_clustered USING GIST (geom);

-- add from and to id columns
ALTER TABLE line_cut ADD COLUMN from_id INTEGER;
ALTER TABLE line_cut ADD COLUMN to_id INTEGER;

-- assign the from and to ids to the road segments
UPDATE line_cut AS a
  SET from_id = b.id
FROM
  endpoints_clustered as b
WHERE
  ST_Intersects(ST_StartPoint(a.geom),b.geom);

UPDATE line_cut AS a
  SET to_id = b.id
FROM
  endpoints_clustered as b
WHERE
  ST_Intersects(ST_EndPoint(a.geom),b.geom);


-- This doesn't seem to be necessary, but will keep this in in case we do need
-- it for other networks. It finds all the unique ids used by the line_cut table
-- and builds an index on it.
DROP TABLE IF EXISTS unique_node_ids;
CREATE TABLE unique_node_ids AS
SELECT DISTINCT c.id
FROM
 (SELECT DISTINCT a.from_id AS id
  FROM line_cut AS a
  UNION
  SELECT DISTINCT b.to_id AS id
  FROM line_cut AS b) as c;
CREATE UNIQUE INDEX unique_node_ids_idx ON unique_node_ids (id);

-- filters endpoints_clustered to only have the nodes used in line_cut
DROP TABLE IF EXISTS endpoints_filtered;
CREATE TABLE endpoints_filtered AS
SELECT a.id, a.geom
FROM endpoints_clustered AS a,
  unique_node_ids AS b
WHERE
  a.id = b.id;
CREATE INDEX endpoints_filtered_gix ON endpoints_filtered USING GIST (geom);
