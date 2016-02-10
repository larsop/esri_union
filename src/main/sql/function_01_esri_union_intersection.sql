
-- If an excpetion happens a buffer with a verry will be tried

CREATE OR REPLACE FUNCTION esri_union_intersection(g1 geometry,g2 geometry) RETURNS geometry AS $$DECLARE
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

	newg := ST_Intersection(g1,g2);
	
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
