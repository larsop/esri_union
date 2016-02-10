-- DROP FUNCTION get_esri_union (input_table_one text, input_table_two text,result_table_name text,max_rows_pr_cell int); 

CREATE OR REPLACE FUNCTION get_esri_union (
input_table_one text, 
input_table_two text,
result_table_name text default null,
max_rows_pr_cell integer default 3000
) RETURNS TEXT  AS
$body$
DECLARE

	run_sql_created boolean = true;
	tmp_grid_table_name text = 'grid_table'; 

	-- used as input when building content based grids
	schema_table_name_column_name_array text[2];
	
	-- tmp
	line VARCHAR;
	line_values VARCHAR[];
	line_schema_table VARCHAR[];
	
	geo_column_name VARCHAR;
	schema_table_name VARCHAR;
	source_srid int;
	schema_name VARCHAR;
	table_name VARCHAR;
	sql VARCHAR;

	-- array of quoted field identifiers
	-- for attribute fields passed in by user and known (by name)
	-- in the target table
	new_column_as_tmp text[];
	new_column_name_tmp text[];
	org_column_name_tmp text[];
	table_name_ref_tmp text;

	-- values with no prefix or postfix likt t_1, t1
	org_columns_names_array text[];

	columns_names_array  text[2];
	pk_columns_array text[2];
	geo_colums_array text[2];
	

	-- values with no prefix or postfix likt t_1, t1
	columns_as_array text[2];
	tables_as_array text[2];
	geo_colums_as_array text[2];

	-- the new table 
	column_names_as  text := '';
	column_names  text := '';
	table_names_as text := '';
	tmp_table_names_as text := '';
	geo_column_names_as text := '';
	
	-- the sql used to create the result table
	new_table_def_sql text;
	
	-- the sql get the intersection
	sql_to_run text;

	-- holds dynamic sql to be able to use the same code for different
	command_string text;
	
	-- used to loop
	cell_id int;
	max_cell_id int;

	func_call text;
	singel_paramter esri_union_single_cell_pameter;
	
	random_value text;
		 
BEGIN
	-- get random value
	random_value := '_' || md5(random()::text);
	tmp_grid_table_name := tmp_grid_table_name || random_value;
	
	-- parse input to get primary key and geo coulumn name and build input to get content based grid
	SELECT string_to_array(input_table_one, ' ') INTO line_values; 
	schema_table_name_column_name_array[1] := line_values[1] || ' ' || line_values[3];
	pk_columns_array[1] := line_values[2]; 
	geo_colums_as_array[1] := 't_1.' || line_values[3];
	geo_colums_array[1] := line_values[3];

	tables_as_array[1] := line_values[1] || ' AS t_1';
	
	SELECT string_to_array(input_table_two, ' ') INTO line_values; 
	schema_table_name_column_name_array[2] := line_values[1] || ' ' || line_values[3];
	pk_columns_array[2] := line_values[2]; 
	geo_colums_as_array[2] := 't_2.' || line_values[3];
	geo_colums_array[2] := line_values[3];
	tables_as_array[2] := line_values[1] || ' AS t_2';

	-- TODO handle table with different srid for now just use the first table
	SELECT string_to_array(schema_table_name_column_name_array[1], ' ') INTO line_values; 
	geo_column_name := line_values[2];
	schema_table_name := line_values[1];
	SELECT string_to_array(line_values[1], '.') INTO line_values; 
	command_string := format('SELECT Find_SRID(%L,%L,%L)',line_values[1],line_values[2], geo_column_name);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string INTO source_srid ;

	-- create grid cell table 
	-- TODO return a delete command and not delete if it exits
 	command_string := format('DROP TABLE IF EXISTS %s',tmp_grid_table_name);
	EXECUTE command_string;
	command_string := format('CREATE TEMP TABLE %s(id serial , geom geometry , PRIMARY KEY (id)) ON COMMIT PRESERVE ROWS',tmp_grid_table_name);
	EXECUTE command_string;
	command_string := format('INSERT INTO %s(geom) 
	SELECT q_grid.cell::geometry(geometry,%L)  as geom FROM (SELECT(ST_Dump(cbg_content_based_balanced_grid(%L,%L))).geom AS cell) AS q_grid',
	tmp_grid_table_name,source_srid,schema_table_name_column_name_array,max_rows_pr_cell);
	EXECUTE command_string;
	GET DIAGNOSTICS max_cell_id = ROW_COUNT;
	command_string := format('CREATE INDEX %s ON %s USING gist (geom)', (tmp_grid_table_name || '_gist_index_geom'),tmp_grid_table_name);
	EXECUTE command_string;
	command_string := format('ANALYZE %s',tmp_grid_table_name);
	EXECUTE command_string;


	-- find all coulums in table one and two
	-- TODO drop using this array but use input parameter on and two
	FOR i IN ARRAY_LOWER(schema_table_name_column_name_array,1)..ARRAY_UPPER(schema_table_name_column_name_array,1) LOOP
		line := schema_table_name_column_name_array[i];

		SELECT string_to_array(line, ' ') INTO line_values; 
		schema_table_name := line_values[1];
		geo_column_name := line_values[2];
	
        command_string := format('
        SELECT 
        array_agg( ''t_''|| %s || ''.''  || quote_ident(update_column) || '' AS '' ||  '' t'' || %s || ''_'' || quote_ident(update_column)) AS new_column_as_tmp,
        array_agg('' t'' || %s || ''_'' || quote_ident(update_column)) AS new_column_name_tmp,
        array_agg(quote_ident(update_column)) AS org_column_name_tmp
        FROM (
        SELECT distinct(key) AS update_column
        FROM  (SELECT * FROM %s limit 1) AS t, json_each_text(to_json((t))) 
		WHERE key != %L
        ) AS keys',
        i,
        i,
        i,
        schema_table_name,
        geo_colums_array[i]);
        
        RAISE NOTICE 'command_string %', command_string;
        EXECUTE command_string  INTO new_column_as_tmp, new_column_name_tmp, org_column_name_tmp;

		columns_names_array[i] := array_to_string(new_column_name_tmp, ',');
		columns_as_array[i] :=  array_to_string(new_column_as_tmp, ',');
		org_columns_names_array[i] :=  array_to_string( org_column_name_tmp, ',');
	
	END LOOP;
	

	-- set togther
	column_names := columns_names_array[1] || ', ' || columns_names_array[2];
	column_names_as := columns_as_array[1] || ', ' || columns_as_array[2];
	table_names_as := tables_as_array[1] || ', ' || tables_as_array[2];
	geo_column_names_as :=   geo_colums_as_array[1] || ', ' ||  geo_colums_as_array[2] ;

	
	
	-- Create the result table, use UNLOGGED because it's faster
		
  	new_table_def_sql := 'Select ' || column_names_as  || ' from ' ||  table_names_as || ' WHERE ST_Intersects(' || geo_column_names_as || ') limit 0';
  	-- TODO return a delete command and not delete it
	IF result_table_name IS NULL THEN
		result_table_name = 'esri_union_result' || random_value;
		command_string := format('DROP table IF EXISTS %s',result_table_name);
		EXECUTE command_string;
		command_string := format('CREATE TEMP TABLE %s ON COMMIT PRESERVE ROWS AS %s ',result_table_name,new_table_def_sql);
		EXECUTE command_string;
	ELSE
		command_string := format('CREATE UNLOGGED TABLE %s AS %s ',result_table_name,new_table_def_sql);
		EXECUTE command_string;
	END IF;

	-- add a result geometry column
	command_string := format('ALTER TABLE %s ADD COLUMN geom geometry(geometry,%L)',result_table_name,source_srid);
	EXECUTE command_string;
	-- add a id column
	command_string := format('ALTER TABLE %s ADD COLUMN id serial PRIMARY KEY ',result_table_name);
	EXECUTE command_string;
	-- add flag for border or border polygon
	--command_string := format('ALTER TABLE %s ADD COLUMN cell_border_geom boolean ',result_table_name);
	--EXECUTE command_string;


	-- set common values
	singel_paramter.max_cell_id := max_cell_id; 
	singel_paramter.tables_as_array := tables_as_array; 
	singel_paramter.org_columns_names_array := org_columns_names_array;
	singel_paramter.pk_columns_array := pk_columns_array; 
	singel_paramter.columns_names_array := columns_names_array; 
	singel_paramter.columns_as_array := columns_as_array; 
	singel_paramter.geo_colums_array := geo_colums_array; 
	singel_paramter.geo_colums_as_array := geo_colums_as_array; 
	singel_paramter.result_table_name := result_table_name; 
	singel_paramter.tmp_grid_table_name := tmp_grid_table_name;
	
	    -- used to hold result temp data for table1
    singel_paramter.table_name_tmp_t1 := 'tmp_data_esri_intersects_t1' || random_value;

    -- used to hold result temp data for table1
    singel_paramter.table_name_tmp_t2 := 'tmp_data_esri_intersects_t2' || random_value;
    
    -- used to loop
	singel_paramter.result_table_name_tmp := 'tmp_data_esri_intersects' || random_value;
	
	-- create temp tables if the code should run now
	IF run_sql_created = true THEN		
		perform esri_union_create_tmp_tables(singel_paramter);
	END IF;
 

	FOR cell_id IN 1..max_cell_id LOOP
		-- set current cell is
		singel_paramter.cell_id := cell_id;
		RAISE NOTICE 'cell_id  %  of %',cell_id, max_cell_id;
		IF run_sql_created = true THEN		
			perform get_esri_union_cell(singel_paramter,false);
		END IF;
	END LOOP;

	
	-- grep remove grid lines 
	perform esri_union_remove_grid(result_table_name,'t1_' || pk_columns_array[1],'t2_' || pk_columns_array[2]);

	RETURN  'union result table:' || result_table_name || ' , grid table used:' || tmp_grid_table_name;
END;
$body$
LANGUAGE 'plpgsql';


