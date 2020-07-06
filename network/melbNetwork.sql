-- turning timing on
\timing
-- transforms the geometries to a projected (i.e, x,y) system and snaps to the
-- nearest metre. Was using GDA2020 (7845), now using MGA Zone 55 (28355)
ALTER TABLE roads
 ALTER COLUMN geom TYPE geometry(LineString,28355)
  USING ST_SnapToGrid(ST_Transform(geom,28355),1);
ALTER TABLE roads_points
 ALTER COLUMN geom TYPE geometry(Point,28355)
  USING ST_SnapToGrid(ST_Transform(geom,28355),1);
CREATE INDEX roads_points_gix ON roads USING GIST (geom);

-- determine if the road segment is a bridge or tunnel
ALTER TABLE roads ADD COLUMN bridge_or_tunnel BOOLEAN;
UPDATE roads
  SET bridge_or_tunnel =
       CASE WHEN other_tags LIKE '%bridge%' OR other_tags LIKE '%tunnel%' THEN TRUE
       ELSE FALSE END;
CREATE INDEX roads_gix ON roads USING GIST (geom);

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

-- take the intersections, buffer them 0.01m, and use them to cut the lines they
-- intersect. We then snap to the nearest metre, ensuring there are no gaps.
-- Only intersections with the same osm_id need to be considered
DROP TABLE IF EXISTS line_cut;
CREATE TABLE line_cut AS
SELECT a.osm_id,
(ST_Dump(ST_SnapToGrid(ST_Difference(a.geom,ST_Buffer(b.geom,0.01)),1))).geom AS geom
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
CREATE INDEX line_cut_gix ON line_cut USING GIST (geom);
ALTER TABLE line_cut ADD COLUMN lid SERIAL PRIMARY KEY;

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

-- most lines will only have 2 endpoints near them, but some will have extra
DROP TABLE IF EXISTS endpoints_near_lines;
CREATE TABLE endpoints_near_lines AS
SELECT c.lid, c.num_endpoints, c.geom
FROM
 (SELECT a.lid, COUNT(b.id) AS num_endpoints,
         st_unaryunion(st_collect(b.geom)) AS geom
  FROM
    line_cut AS a,
    endpoints_clustered AS b
  WHERE
    st_intersects(st_buffer(a.geom,0.1),b.geom)
  GROUP BY
    a.lid
  ) AS c
WHERE
  c.num_endpoints > 2;

DROP TABLE IF EXISTS line_cut2;
CREATE TABLE line_cut2 AS
SELECT a.lid, a.osm_id,
(ST_Dump(ST_SnapToGrid(ST_Difference(a.geom,ST_Buffer(b.geom,0.01)),1))).geom AS geom
FROM line_cut AS a, endpoints_near_lines AS b
WHERE a.lid = b.lid;

DELETE FROM line_cut 
WHERE lid IN 
  (SELECT lid FROM line_cut2);


DROP TABLE IF EXISTS line_cut3;
CREATE TABLE line_cut3 AS
	SELECT osm_id, geom
	FROM line_cut
	WHERE lid NOT IN (SELECT lid FROM line_cut2)
UNION
	SELECT osm_id, geom
	FROM line_cut2;
	-- add length
ALTER TABLE line_cut3 ADD COLUMN length INTEGER;
UPDATE line_cut3 SET length = ST_Length(geom);

-- add from and to id columns
ALTER TABLE line_cut3 ADD COLUMN from_id INTEGER;
ALTER TABLE line_cut3 ADD COLUMN to_id INTEGER;

-- assign the from and to ids to the road segments
UPDATE line_cut3 AS a
  SET from_id = b.id
FROM
  endpoints_clustered as b
WHERE
  ST_Intersects(ST_StartPoint(a.geom),b.geom);

UPDATE line_cut3 AS a
  SET to_id = b.id
FROM
  endpoints_clustered as b
WHERE
  ST_Intersects(ST_EndPoint(a.geom),b.geom);

DELETE FROM line_cut3
WHERE ST_isEmpty(geom);


-- This doesn't seem to be necessary, but will keep this in in case we do need
-- it for other networks. It finds all the unique ids used by the line_cut3
-- table and builds an index on it.
DROP TABLE IF EXISTS unique_node_ids;
CREATE TABLE unique_node_ids AS
SELECT DISTINCT c.id
FROM
 (SELECT DISTINCT a.from_id AS id
  FROM line_cut3 AS a
  UNION
  SELECT DISTINCT b.to_id AS id
  FROM line_cut3 AS b) as c;
CREATE UNIQUE INDEX unique_node_ids_idx ON unique_node_ids (id);

-- filters endpoints_clustered to only have the nodes used in line_cut3
DROP TABLE IF EXISTS endpoints_filtered;
CREATE TABLE endpoints_filtered AS
SELECT a.id, a.geom
FROM endpoints_clustered AS a,
  unique_node_ids AS b
WHERE
  a.id = b.id;
CREATE INDEX endpoints_filtered_gix ON endpoints_filtered USING GIST (geom);

-- the non-spatial data for the osm_id entries present in the network
DROP TABLE IF EXISTS osm_metadata;
CREATE TABLE osm_metadata AS
SELECT osm_id, highway, other_tags
FROM roads
WHERE osm_id IN
 (SELECT DISTINCT osm_id FROM line_cut3);

-- from and to ids of edges that are roundabouts
DROP TABLE IF EXISTS edges_roundabout;
CREATE TABLE edges_roundabout AS
SELECT a.from_id,
  a.to_id,
  CASE WHEN b.other_tags LIKE '%roundabout%' THEN TRUE
                                             ELSE FALSE
       END AS is_roundabout
FROM
  line_cut3 AS a,
  osm_metadata AS b
WHERE
  a.osm_id = b.osm_id;

-- node ids that connect to roundabouts
DROP TABLE IF EXISTS nodes_roundabout;
CREATE TABLE nodes_roundabout AS
SELECT DISTINCT c.id
FROM
 (SELECT DISTINCT a.from_id AS id
		FROM edges_roundabout AS a
		WHERE is_roundabout = TRUE
	UNION
		SELECT DISTINCT b.to_id AS id
		FROM edges_roundabout AS b
		WHERE is_roundabout = TRUE) AS c;

-- nodes attributed with if they are at roundabouts or traffic signals 
DROP TABLE IF EXISTS nodes_attributed;
CREATE TABLE nodes_attributed AS
SELECT c.id,
       CASE WHEN c.id IN (SELECT id FROM nodes_roundabout) THEN 1
                                                           ELSE 0
       END AS is_roundabout,
       CASE WHEN c.length <= 20 THEN 1
                                ELSE 0
       END AS is_signal,
       c.geom
FROM
 (SELECT
		a.id,
		a.geom,
		ST_Distance(a.geom,b.geom) AS length
	FROM
		endpoints_filtered AS a
	CROSS JOIN LATERAL
		(SELECT geom
		 FROM roads_points
		 ORDER BY
		   a.geom <-> geom
		 LIMIT 1) AS b
	) AS c;

CREATE INDEX nodes_attributed_gix ON nodes_attributed USING GIST (geom);

