CREATE OR REPLACE FUNCTION esri_union_remove_grid (
	result_table text,
	pk_key_one text,
	pk_key_two text
) RETURNS text  AS
$body$
DECLARE
	
	-- the sql get the intersection
	sql text;

	-- holds dynamic sql to be able to use the same code for different
	command_string text;
	
	rec RECORD;

	result_table_tmp text;
	
BEGIN
	
	result_table_tmp = replace(result_table, '.', '_');

	command_string := format('CREATE INDEX %s ON %s(%s)', result_table_tmp || pk_key_one, result_table,pk_key_one);
	EXECUTE command_string;
	command_string := format('CREATE INDEX %s ON %s(%s)', result_table_tmp || pk_key_two, result_table,pk_key_two);
	EXECUTE command_string;



	-- find rows that can be grouped togehter because they have the same attribittes
	sql := '
	SELECT id_array,id_to_keep 
	FROM
	(		
			SELECT * FROM  (
			SELECT  count(r.*) as counts, array_agg(distinct(r.id)) id_array, min(r.id) as id_to_keep FROM 
			' || result_table || ' r
			WHERE r.' || pk_key_one || ' is NOT NULL AND r.' || pk_key_two || ' is NOT NULL 
 			GROUP BY r.' || pk_key_one || ', r.' || pk_key_two || '
			) AS t WHERE counts > 1
			UNION
			SELECT * FROM 
			(
			SELECT  count(r.*) as counts, array_agg(distinct(r.id)) id_array, min(r.id) as id_to_keep FROM 
			' || result_table || ' r 
			WHERE r.' || pk_key_one || ' is NOT NULL AND r.' || pk_key_two || ' is NULL
 			GROUP BY r.' || pk_key_one || '
			) AS t WHERE counts > 1
			UNION
			SELECT * FROM 
			(
			SELECT  count(r.*) as counts, array_agg(distinct(r.id)) id_array, min(r.id) as id_to_keep FROM 
			' || result_table || ' r 
			WHERE  r.' || pk_key_two || ' is NOT NULL AND r.' || pk_key_one || ' is NULL
 			GROUP BY r.' || pk_key_two || '
			) AS t WHERE counts > 1
	) AS to_update';
	
	-- drop the index we dont't ned them any more
	IF position('.' in result_table)	= 0 THEN
		command_string := format('DROP INDEX %s',  result_table_tmp || pk_key_one);
		RAISE NOTICE 'drop index 1 %',command_string;
		EXECUTE command_string;
		command_string := format('DROP INDEX %s',  result_table_tmp || pk_key_two);
		RAISE NOTICE 'drop index 2 %',command_string;
		EXECUTE command_string;
	ELSE
		-- get the schem name
		
		command_string := format('DROP INDEX %s',  ((string_to_array(result_table, '.'))[1]) || '.' || result_table_tmp || pk_key_one);
		RAISE NOTICE 'drop index 1 %',command_string;
		EXECUTE command_string;
		command_string := format('DROP INDEX %s',  ((string_to_array(result_table, '.'))[1]) || '.' ||  result_table_tmp || pk_key_two);
		RAISE NOTICE 'drop index 2 %',command_string;
		EXECUTE command_string;
	
	END IF;

	
	FOR rec IN EXECUTE sql LOOP
		-- update the rows the lowest value delete e
		command_string := format(
		'UPDATE ' || result_table || ' AS r 
		SET geom =  ST_Multi(u.geom)
		FROM (SELECT St_Union(r.geom) AS geom FROM ' || result_table || ' r WHERE r.id = ANY(%L) ) AS u
		WHERE r.id = %L',
		rec.id_array,
		rec.id_to_keep);
    	RAISE NOTICE '%',command_string;
		EXECUTE command_string;

    	command_string := format(
		'DELETE FROM ' || result_table || ' AS r
		WHERE r.id = ANY(%L) AND r.id > %L',
		rec.id_array,
		rec.id_to_keep);
    	RAISE NOTICE '%',command_string;
 		EXECUTE command_string;


	END LOOP;

	
	--RETURN QUERY select * FROM return_call_list;
	RETURN 'test';
END;
$body$
LANGUAGE 'plpgsql';


-- Grant som all can use it
GRANT EXECUTE ON FUNCTION esri_union_remove_grid (
	result_table text,
	pk_key_one text,
	pk_key_two text
) to PUBLIC;
