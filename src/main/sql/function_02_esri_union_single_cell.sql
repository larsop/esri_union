
DROP FUNCTION IF EXISTS get_esri_union_cell (scp esri_union_single_cell_pameter) cascade;

DROP FUNCTION IF EXISTS get_esri_union_cell (scp esri_union_single_cell_pameter, create_tmp_table boolean) cascade;


CREATE OR REPLACE FUNCTION get_esri_union_cell (
scp esri_union_single_cell_pameter, 
create_tmp_table boolean default true) RETURNS int  AS
$body$
DECLARE
	-- input
	cell_id int = scp.cell_id ; 
	max_cell_id int= scp.max_cell_id ;

	tables_as_array text[]= scp.tables_as_array ;
	pk_columns_array text[]= scp.pk_columns_array ;
	
	org_columns_names_array text[]=scp.org_columns_names_array;
	columns_names_array text[]= scp.columns_names_array ;
	columns_as_array text[]= scp.columns_as_array ;
	
	geo_colums_array text[]= scp.geo_colums_array ;
	geo_colums_as_array text[]= scp.geo_colums_as_array ;
	
	result_table_name text= scp.result_table_name; 
	tmp_grid_table_name text= scp.tmp_grid_table_name ;

	-- holds dynamic sql to be able to use the same code for different
	command_string text;
	sql_to_run text;
	-- the sql used to create temp result table
	new_table_def_sql text;
	

	-- the new table 
	column_names_as  text := '';
	column_names  text := '';
--	table_names_as text := '';
	geo_column_names_as text := '';
	
	new_rows int;

    tmp_table_names_as text;

      -- used to hold result temp data for table1
    table_name_tmp_t1 text = scp.table_name_tmp_t1; 

    -- used to hold result temp data for table1
    table_name_tmp_t2 text = scp.table_name_tmp_t2; 
    
    -- used to loop
	result_table_name_tmp text = scp.result_table_name_tmp ;


BEGIN

	-- set togther
	column_names := columns_names_array[1] || ', ' || columns_names_array[2];
	column_names_as := columns_as_array[1] || ', ' || columns_as_array[2];
--	table_names_as := tables_as_array[1] || ', ' || tables_as_array[2];
	geo_column_names_as :=   geo_colums_as_array[1] || ', ' ||  geo_colums_as_array[2] ;
   	tmp_table_names_as := table_name_tmp_t1 || ' AS t_1, ' || table_name_tmp_t2 || ' AS t_2';

  	IF create_tmp_table = true THEN		
		perform esri_union_create_tmp_tables(scp);
	ELSE
		-- remove data from temp tables to release loocks
		command_string := format('TRUNCATE TABLE %s',table_name_tmp_t1);
	    EXECUTE command_string;
		command_string := format('TRUNCATE TABLE %s',table_name_tmp_t2);
	    EXECUTE command_string;
		command_string := format('TRUNCATE TABLE %s',result_table_name_tmp);
		EXECUTE command_string;
    END IF;

    		      
        -- find all intersection between table one and current grid
        sql_to_run := 
        'SELECT ' 
		|| 'CASE WHEN ST_Within(' ||  geo_colums_as_array[1] || ',gc.geom)'
       	|| ' THEN ST_Multi(' || geo_colums_as_array[1] || ') '
		|| ' ELSE ' || ' esri_union_intersection(' || geo_colums_as_array[1] || ',gc.geom,TRUE)' 
		|| ' END AS ' || geo_colums_array[1] 
		|| ',' || columns_as_array[1]  
        || ' FROM ' ||  tables_as_array[1] || ', ' ||  tmp_grid_table_name || ' AS gc  ' 
        || ' WHERE gc.id = ' || cell_id || ' AND ST_Intersects(' ||  geo_colums_as_array[1] || ',gc.geom)';
        
        command_string := format('INSERT INTO %s(%s) %s',table_name_tmp_t1,geo_colums_array[1] || ',' || org_columns_names_array[1],sql_to_run);
        RAISE NOTICE 'command_string P1 : % ',command_string;
        EXECUTE command_string;
        command_string := format('ANALYZE %I',table_name_tmp_t1);
        EXECUTE command_string;
                
        -- find all intersection between table two and current grid
        sql_to_run := 
        'SELECT ' 
		|| 'CASE WHEN ST_Within(' ||  geo_colums_as_array[2] || ',gc.geom)'
       	|| ' THEN ST_Multi(' || geo_colums_as_array[2] || ') '
		|| ' ELSE ' || ' esri_union_intersection(' || geo_colums_as_array[2] || ',gc.geom,TRUE)' 
		|| ' END AS ' || geo_colums_array[2] 
		|| ',' || columns_as_array[2]  
        || ' FROM ' ||  tables_as_array[2] || ', ' ||  tmp_grid_table_name || ' AS gc  ' 
        || ' WHERE gc.id = ' || cell_id || ' AND ST_Intersects(' ||  geo_colums_as_array[2] || ',gc.geom)';
        
        
        command_string := format('INSERT INTO %s(%s) %s',table_name_tmp_t2,geo_colums_array[2] || ',' || org_columns_names_array[2],sql_to_run);
        RAISE NOTICE 'command_string P2 : % ',command_string;
        EXECUTE command_string;
        command_string := format('ANALYZE %I',table_name_tmp_t2);
        EXECUTE command_string;



	 	-- find all intersection between selected rows from table one and two
        sql_to_run := 'SELECT * FROM ( SELECT '
        || ' CASE ' 
        || ' WHEN ST_Within(' ||  geo_colums_as_array[1]  || ',' ||  geo_colums_as_array[2] || ') THEN ST_Multi(' || geo_colums_as_array[1] || ') '
        || ' WHEN ST_Within(' ||  geo_colums_as_array[2]  || ',' ||  geo_colums_as_array[1] || ') THEN ST_Multi(' || geo_colums_as_array[2] || ') '
		|| ' ELSE ' || ' esri_union_intersection(' || geo_column_names_as || ')' 
		|| ' END AS geom,'
        || column_names_as  
        || ' FROM ' ||  tmp_table_names_as ||' WHERE ST_Intersects(' || geo_column_names_as || ')'  || ' ) AS foo_t ';
        command_string := format('INSERT INTO %s(%s) %s',result_table_name_tmp,' geom, ' ||  column_names,sql_to_run);
        RAISE NOTICE 'command_string 1 : % ',command_string;
        EXECUTE command_string;
        		
		
	    
		-- find all rows from table one - minus area that are covered by table two
		-- TODO reuse sql for the 4 statements below using using $1
		sql_to_run := 'SELECT * FROM (SELECT valid_multipolygon_difference('||  geo_colums_as_array[1] || ', res_b.to_be_removed) AS geom, '  
		|| columns_as_array[1]   
		|| ' FROM ' ||  table_name_tmp_t1  || ' AS t_1 '
	--	|| ', ' ||  tmp_grid_table_name || ' AS gc '
		|| ', (SELECT ' || ' t_1.' || pk_columns_array[1] || ', ST_Union('|| geo_colums_as_array[2] || ') AS to_be_removed ' 
		|| ' FROM ' ||  tmp_table_names_as 
		--|| ', ' 
		--||  tmp_grid_table_name || ' AS gc  ' 
		--|| ' WHERE gc.id = ' || cell_id || ' AND ST_Intersects(gc.geom,' ||  geo_colums_as_array[1] || ') AND ST_Intersects(gc.geom,' ||  geo_colums_as_array[2] || ')' 
		|| ' WHERE ST_Intersects(' || geo_column_names_as || ')' 
		|| ' GROUP BY ' || ' t_1.' || pk_columns_array[1] || ') as res_b ' 
		|| ' WHERE res_b.'  || pk_columns_array[1] || '= t_1.'  || pk_columns_array[1] || ' AND ST_Area(res_b.to_be_removed) > 0 '
		--|| ' AND gc.id = ' || cell_id || ' AND gc.geom && ' ||  geo_colums_as_array[1] || 
		') AS foo_t ';
		RAISE NOTICE 'command_string 2 : % ',command_string;
		command_string := format('INSERT INTO %s(%s) %s',result_table_name_tmp,' geom, ' ||  columns_names_array[1],sql_to_run);
		EXECUTE command_string;


		-- find all rows from table two - minus area that are covered by table one
		sql_to_run := 'SELECT * FROM (SELECT valid_multipolygon_difference(' || geo_colums_as_array[2] || ', res_b.to_be_removed) AS geom, '  
		|| columns_as_array[2]   
		|| ' FROM ' || table_name_tmp_t2 || ' AS t_2 '
	--	|| ', ' ||  tmp_grid_table_name || ' AS gc '
		|| ', (SELECT ' || ' t_2.' || pk_columns_array[2] || ', ST_Union('|| geo_colums_as_array[1] || ') AS to_be_removed ' 
		|| ' FROM ' ||  tmp_table_names_as  
	--	|| ', ' ||  tmp_grid_table_name || ' AS gc  ' 
	--	|| ' WHERE gc.id = ' || cell_id || ' AND ST_Intersects(gc.geom,' ||  geo_colums_as_array[1] || ') AND ST_Intersects(gc.geom,' ||  geo_colums_as_array[2] || ')' 
		|| ' WHERE ST_Intersects(' || geo_column_names_as || ')' 
		|| ' GROUP BY ' || ' t_2.' || pk_columns_array[2] || ') as res_b ' 
		|| ' WHERE res_b.'  || pk_columns_array[2] || ' = t_2.'  || pk_columns_array[2] || ' AND ST_Area(res_b.to_be_removed) > 0 '
		--|| ' AND gc.id = ' || cell_id || ' AND gc.geom && ' ||  geo_colums_as_array[2] 
		|| ') AS foo_t ';
		RAISE NOTICE 'command_string 3 : % ',command_string;
		command_string := format('INSERT INTO %s(%s) %s',result_table_name_tmp,' geom, ' ||  columns_names_array[2],sql_to_run);
		EXECUTE command_string;

		-- add index because we need them in the next quary
		command_string := format('CREATE INDEX %s ON %s USING gist (geom)',result_table_name_tmp||'_geom_indx', result_table_name_tmp);
		EXECUTE command_string;

		command_string := format('ANALYZE %I',result_table_name_tmp);
		EXECUTE command_string;
		command_string := format('DELETE FROM %I WHERE ST_IsEmpty(geom)',result_table_name_tmp);
		EXECUTE command_string;

		-- find all rows from table one that are not added yet (because they do not intersect with any rows from table two in this cell)
		sql_to_run := 'SELECT * FROM (SELECT esri_union_intersection(' || geo_colums_as_array[1] || ',gc.geom) AS geom, ' || columns_as_array[1]   || 
		' FROM ' ||  table_name_tmp_t1 || ' AS t_1 '  
		|| ', ' ||  tmp_grid_table_name || ' AS gc '
		|| ' WHERE gc.id = ' || cell_id || ' AND gc.geom && ' || geo_colums_as_array[1] || ' AND ST_IsValid( ' || geo_colums_as_array[1] || ')' 
		|| ' AND NOT EXISTS (SELECT 1 FROM ' || result_table_name_tmp || ' AS found, ' ||  tmp_grid_table_name || ' AS gc '  
		|| '  WHERE ' || ' t_1.' || pk_columns_array[1] || ' = found.t1_' || pk_columns_array[1]  
		|| '  AND gc.id = ' || cell_id || ' AND gc.geom && ' || ' found.geom'  
		|| '  AND ST_Intersects(found.geom,gc.geom)) '
		|| ') AS foo_t ';
		command_string := format('INSERT INTO %s(%s) %s',result_table_name_tmp,' geom, ' ||  columns_names_array[1],sql_to_run);
		RAISE NOTICE 'command_string 4 : % ',command_string;
		EXECUTE command_string;

		command_string := format('ANALYZE %I',result_table_name_tmp);
		EXECUTE command_string;
		command_string := format('DELETE FROM %I WHERE ST_IsEmpty(geom)',result_table_name_tmp);
		EXECUTE command_string;

		-- find all rows from table two that are not added yet (because they do not intersect with any rows from table one in this cell)
		sql_to_run := 'SELECT * FROM (SELECT esri_union_intersection(' || geo_colums_as_array[2] || ',gc.geom) AS geom, ' || columns_as_array[2]   || 
		' FROM ' || table_name_tmp_t2 || ' AS t_2 '
		|| ', ' ||  tmp_grid_table_name || ' AS gc '
		|| ' WHERE gc.id = ' || cell_id || ' AND gc.geom && ' || geo_colums_as_array[2] || ' AND ST_IsValid( ' || geo_colums_as_array[2] || ')' 
		|| ' AND NOT EXISTS (SELECT 1 FROM ' || result_table_name_tmp ||  ' AS found, ' ||  tmp_grid_table_name || ' AS gc ' 
		|| '  WHERE ' || ' t_2.' || pk_columns_array[2] || ' = found.t2_' || pk_columns_array[2]
		|| '  AND gc.id = ' || cell_id || ' AND gc.geom && ' ||  ' found.geom'   
		|| '  AND ST_Intersects(found.geom,gc.geom)) '
		|| ') AS foo_t ';
		RAISE NOTICE 'command_string 5 : % ',command_string;
		command_string := format('INSERT INTO %s(%s) %s',result_table_name_tmp,' geom, ' ||  columns_names_array[2],sql_to_run);
		EXECUTE command_string;

		command_string := format('ANALYZE %I',result_table_name_tmp);
		EXECUTE command_string;
		command_string := format('DELETE FROM %I WHERE ST_IsEmpty(geom)',result_table_name_tmp);
		EXECUTE command_string;

		
		-- get results from temp
		command_string := format('INSERT INTO %s(%s) SELECT %s FROM %s',result_table_name, ('geom, ' ||  column_names), ('geom, ' ||  column_names),result_table_name_tmp);
		RAISE NOTICE 'command_string 5 : % ',command_string;
		EXECUTE command_string;
		
		-- drop the inde
		command_string := format('DROP INDEX %s ',result_table_name_tmp||'_geom_indx');
		EXECUTE command_string;


		GET DIAGNOSTICS new_rows = ROW_COUNT;
	
	                    

	RETURN new_rows;
END;
$body$
LANGUAGE 'plpgsql';


-- Grant so all can use it
GRANT EXECUTE ON FUNCTION get_esri_union_cell (
scp esri_union_single_cell_pameter, 
create_tmp_table boolean )
to PUBLIC;

