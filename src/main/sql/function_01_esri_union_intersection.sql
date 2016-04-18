
-- If an excpetion happens a buffer with a verry will be tried

DROP FUNCTION IF EXISTS esri_union_intersection(g1 geometry,g2 geometry);


CREATE OR REPLACE FUNCTION esri_union_intersection(g1 geometry,g2 geometry,remove_holes boolean DEFAULT FALSE) RETURNS geometry AS $$DECLARE
	-- the result geo returned
    empty_polygon geometry = 'POLYGON EMPTY'::geometry;
    newg geometry; 
 	
BEGIN
	
	
--	IF NOT ST_isValid(g1) THEN 
--		g1 = ST_buffer(g1,0);
--	END IF;

--	IF NOT ST_isValid(g2) THEN 
--		g2 = ST_buffer(g2,0);
--	END IF;

--	IF ST_CoveredBy(g1,g2) THEN 
--		newg := g1;
--	ELSIF ST_CoveredBy(g2,g1) THEN 
--		newg := g2;
--	ELSE 

	
	-- find the interesing area to work with only do diff ig number of hholes area verry bigg
	
		IF remove_holes THEN 
			newg := esri_union_reduce_polygon_with_holes(g1,g2);
			newg := ST_Intersection(newg,g2);
		ELSE 
			newg := ST_Intersection(g1,g2);
		END IF;
	
--	END IF;
	
	IF ST_GeometryType(newg) = 'ST_GeometryCollection' THEN
		SELECT ST_Collect(a.geom) INTO newg
  		FROM ( SELECT (ST_Dump(newg)).geom as geom ) as a
  		WHERE ST_Area(a.geom) > 0;
	END IF;

	IF ST_Area(newg) > 0 
	-- AND ST_isValid(newg )
	THEN 
		RETURN ST_Multi(newg);
	END IF;
	
	RETURN empty_polygon;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- The basic idea is to remove all holes that area outside the area we are interested in.
-- g1 is the big polygon that should be reduced 
-- g2 is the bonding box defines the valid area

CREATE OR REPLACE FUNCTION esri_union_reduce_polygon_with_holes(g1 geometry,g2 geometry) RETURNS geometry AS $$DECLARE
    newg geometry = g1; 
BEGIN
	IF ST_GeometryType(g2) = 'ST_Polygon' AND ST_GeometryType(g1) = 'ST_Polygon' AND ST_NumInteriorRings(g1) > 0 THEN
		newg := 
		ST_MakePolygon(
			(SELECT ST_ExteriorRing(g1)), 
			COALESCE(
				(SELECT (array_agg(ST_ExteriorRing(a.ring))) AS interior_ring 
				FROM 
				( 
				SELECT (rec).geom AS ring, (rec).path[1] AS arrayid 
					FROM ( 
						SELECT ST_DumpRings(g1) AS rec 
					) AS aaa
				) AS a
				WHERE g2 && a.ring AND a.arrayid > 0
				), 
				'{}' -- IF no interior ring fits just use a emty array 
			)
				
		); 
		
		RETURN newg;
	ELSE
		RAISE NOTICE 'No data reduction done for geometry of type : % ',ST_GeometryType(g1);
		RETURN g1;
	END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION valid_multipolygon_difference(g1 geometry,g2 geometry) RETURNS geometry AS $$DECLARE
	-- the result geo returned
    empty_polygon geometry = 'POLYGON EMPTY'::geometry;
    newg geometry; 
 	
BEGIN
--	IF NOT ST_isValid(g1) OR NOT ST_isValid(g1)THEN 
--		RETURN empty_polygon;
--	END IF;

	newg := ST_Difference(g1,g2);
	
	IF ST_GeometryType(newg) = 'ST_GeometryCollection' THEN
		SELECT ST_Collect(a.geom) INTO newg
  		FROM ( SELECT (ST_Dump(newg)).geom as geom ) as a
  		WHERE ST_Area(a.geom) > 0;
	END IF;

	IF ST_Area(newg) > 0 
	--AND ST_isValid(newg )
	THEN 
		RETURN ST_Multi(newg);
	END IF;
	
	RETURN empty_polygon;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
