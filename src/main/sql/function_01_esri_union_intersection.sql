-- this did not work or have any effect
DROP FUNCTION IF EXISTS esri_union_st_multi(newg geometry);


CREATE OR REPLACE FUNCTION esri_union_st_multi(newg geometry) RETURNS geometry AS $$DECLARE
	empty_polygon geometry = 'POLYGON EMPTY'::geometry;
    
    -- the geo to be returned
    geo_return geometry;
    
BEGIN
		
	IF ST_Area(newg) > 0 THEN 
		BEGIN
			geo_return := ST_Multi(newg);
		EXCEPTION WHEN OTHERS THEN
			newg := ST_MakeValid(newg);

			IF NOT ST_isValid(newg)  THEN 
				RAISE NOTICE 'failed to make valid % : %',ST_isValid(newg),ST_AsBinary(newg);
				geo_return := empty_polygon;
			END IF;

			geo_return := ST_Multi(newg);
				
			IF NOT ST_isValid(geo_return)  THEN 
				RAISE NOTICE 'failed to make valid % : %',ST_isValid(geo_return),ST_AsBinary(geo_return);
				geo_return := empty_polygon;
			END IF;

		END;
	
	ELSE
		geo_return := empty_polygon;
	END IF;


	RETURN geo_return;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant som all can use it

GRANT EXECUTE ON FUNCTION esri_union_st_multi(newg geometry) to PUBLIC;


DROP FUNCTION IF EXISTS esri_union_intersection(g1 geometry,g2 geometry);


CREATE OR REPLACE FUNCTION esri_union_intersection(g1 geometry,g2 geometry,remove_holes boolean DEFAULT FALSE) RETURNS geometry AS $$DECLARE
	empty_polygon geometry = 'POLYGON EMPTY'::geometry;
    
    -- the result intersetcion
    newg geometry; 
    
    -- the geo to be returned
    geo_return geometry;
    
    -- temp object used when braeking up polygons
   	newg1 geometry; 
  	
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

	
	
	IF remove_holes THEN 
		-- find the interesing area to work with only do diff ig number of hholes area verry bigg
		newg1 := esri_union_reduce_polygon_with_holes(g1,g2);
	ELSE 
		newg1 := g1;
	END IF;	

	--find intersection
	BEGIN
		newg := ST_Intersection(newg1,g2);
	EXCEPTION WHEN OTHERS THEN
		-- try tu run with buffer 0
		newg := ST_Intersection(ST_BUffer(newg1,0),ST_BUffer(g2,0));
	END;

	
	IF ST_GeometryType(newg) = 'ST_GeometryCollection' THEN
		SELECT ST_Collect(a.geom) INTO newg
  		FROM ( SELECT (ST_Dump(newg)).geom as geom ) as a
  		WHERE ST_Area(a.geom) > 0;
	END IF;

	IF ST_Area(newg) > 0 THEN 
		BEGIN
			geo_return := ST_Multi(newg);
		EXCEPTION WHEN OTHERS THEN
			-- try tu run with buffer 0
			geo_return := ST_Multi(ST_BUffer(newg,0));
		END;
	ELSE
		geo_return := empty_polygon;
	END IF;

	IF NOT ST_isValid(geo_return) THEN 
		RAISE NOTICE 'failed to make valid % : %',ST_isValid(geo_return),ST_AsBinary(geo_return);
	
		geo_return := empty_polygon;
	END IF;

	RETURN geo_return;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant som all can use it
GRANT EXECUTE ON FUNCTION esri_union_intersection(g1 geometry,g2 geometry,remove_holes boolean) to PUBLIC;


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

-- Grant som all can use it
GRANT EXECUTE ON FUNCTION esri_union_reduce_polygon_with_holes(g1 geometry,g2 geometry) to PUBLIC;

CREATE OR REPLACE FUNCTION valid_multipolygon_difference(g1 geometry,g2_in geometry[]) RETURNS geometry AS $$DECLARE
   -- the geo to be returned
    geo_return geometry;

    empty_polygon geometry = 'POLYGON EMPTY'::geometry;
    
    newg geometry; 
    
    g2 geometry;
    
    g2_in_row geometry;

 	
  BEGIN

	-- Make union g2
	BEGIN
		g2 := ST_Union(g2_in);

	EXCEPTION WHEN OTHERS THEN
	    RAISE WARNING 'Failed to to union before running differense at % try row by row union.', ST_Centroid(g1);

		g2 := empty_polygon;
		FOREACH g2_in_row IN ARRAY g2_in LOOP
       		RAISE WARNING 'Failed to to union, isValid %, % , Area:%, srid %', ST_IsValid(g2_in_row), ST_GeometryType(g2_in_row), ST_Area(g2_in_row), ST_Srid(g2_in_row);
       		RAISE WARNING 'Failed to to union, geo  %', ST_AsBinary(g2_in_row);
       		
       		IF ST_isValid(g2_in_row) THEN
 				g2 := ST_Union(g2,g2_in_row);
 			ELSE 
 				g2 := ST_Union(g2,ST_MakeValid(g2_in_row));
 			END IF;
    	END loop;
    	
	END;
	  

	BEGIN
		newg := ST_Difference(g1,g2);
		
	EXCEPTION WHEN OTHERS THEN
	

		g1 := ST_MakeValid(g1);
		g2 := ST_MakeValid(g2);

		
		IF NOT ST_isValid(g1) THEN 
			RAISE NOTICE 'failed to make valid % : %',ST_isValid(g1),ST_AsBinary(g1) ;
			RETURN empty_polygon;
		END IF;
	
		IF  NOT ST_isValid(g2)THEN 
			RAISE NOTICE 'failed to make valid % : %',ST_isValid(g2),ST_AsBinary(g2);
			RETURN empty_polygon;
		END IF;
		
		BEGIN
			newg := ST_Difference(g1,g2);
		
			EXCEPTION WHEN OTHERS THEN
	
				RAISE NOTICE 'Failed to handle geos with type % : g2 %',ST_GeometryType(g1),ST_GeometryType(g2);
				RAISE NOTICE 'Failed to handle geos with St_Area g1 % : g2 %',ST_Area(g1),ST_area(g2) ;
			
-- work ok	
				-- did not work with ,-0.00000000001, but worsk ok with
				g1 = ST_Buffer(g1,-0.000000001);
				g2 = ST_Buffer(g2,-0.000000001);
				RAISE NOTICE 'Try to fix by makeing g1 and g2 a tiny bit smaller (new area)  g1 % : g2 %',ST_Area(g1),ST_area(g2) ;

-- did not work				
--				g1 = ST_Snap(g1,g2,0.000001);
--				g2 = ST_Snap(g2,g1,0.000001);
--				RAISE NOTICE 'Try to fix by using snapto  (new area)  g1 % : g2 %',ST_Area(g1),ST_area(g2) ;

-- did not work				
-- ERROR:  XX000: GEOSDifference: TopologyException: Input geom 1 is invalid: Self-intersection at or near point 602777.84329999995 7123831.9999989998 at 602777.84329999995 7123831.9999989998
--				g1 = ST_SnapToGrid(g1,0.000001);
--				g2 = ST_SnapToGrid(g2,0.000001);
--				RAISE NOTICE 'Try to fix by using snapto  (new area)  g1 % : g2 %',ST_Area(g1),ST_area(g2) ;

				g1 := ST_MakeValid(g1);
				g2 := ST_MakeValid(g2);

		
				IF NOT ST_isValid(g1) THEN 
					RAISE NOTICE 'failed to make valid after polygon change % : %',ST_isValid(g1),ST_AsBinary(g1) ;
					RETURN empty_polygon;
				END IF;
			
				IF  NOT ST_isValid(g2)THEN 
					RAISE NOTICE 'failed to make valid after polygon change  % : %',ST_isValid(g2),ST_AsBinary(g2);
					RETURN empty_polygon;
				END IF;

				newg := ST_Difference(g1,g2);
		END;
	END;

	
	
	IF ST_GeometryType(newg) = 'ST_GeometryCollection' THEN
		SELECT ST_Collect(a.geom) INTO newg
  		FROM ( SELECT (ST_Dump(newg)).geom as geom ) as a
  		WHERE ST_Area(a.geom) > 0;
	END IF;
	
	
	IF ST_Area(newg) > 0 THEN 
		BEGIN
			geo_return := ST_Multi(newg);
		EXCEPTION WHEN OTHERS THEN
		
			newg := ST_MakeValid(newg);
		
			IF NOT ST_isValid(newg) THEN 
				RAISE NOTICE 'failed to make valid : % : %',ST_isValid(newg),ST_AsBinary(newg) ;
				RETURN empty_polygon;
			END IF;
			geo_return := ST_Multi(newg);
		END;
	ELSE
		geo_return := empty_polygon;
	END IF;
	
	RETURN geo_return;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant som all can use it
GRANT EXECUTE ON FUNCTION valid_multipolygon_difference(g1 geometry,g2 geometry[]) to PUBLIC;
