DROP TYPE IF EXISTS esri_union_single_cell_pameter cascade;

CREATE TYPE esri_union_single_cell_pameter
AS (
	cell_id int,
	max_cell_id int,

	tables_as_array text[],
	pk_columns_array text[],
	
	org_columns_names_array text[],
	columns_names_array text[],
	columns_as_array text[],
	
	geo_colums_array text[],
	geo_colums_as_array text[],
	
	result_table_name text, 
	tmp_grid_table_name text,
	
	    -- used to hold result temp data for table1
    table_name_tmp_t1 text,

    -- used to hold result temp data for table1
    table_name_tmp_t2 text,

	-- used to loop
	result_table_name_tmp text

);



CREATE OR REPLACE FUNCTION esri_union_create_tmp_tables (
scp esri_union_single_cell_pameter
) RETURNS VOID  AS
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
	
	
    -- used to hold result temp data for table1
    table_name_tmp_t1 text = scp.table_name_tmp_t1; 

    -- used to hold result temp data for table1
    table_name_tmp_t2 text = scp.table_name_tmp_t2; 

	-- used to loop
	result_table_name_tmp text = scp.result_table_name_tmp ;

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

BEGIN

	-- set togther
	column_names := columns_names_array[1] || ', ' || columns_names_array[2];
	column_names_as := columns_as_array[1] || ', ' || columns_as_array[2];
--	table_names_as := tables_as_array[1] || ', ' || tables_as_array[2];
	geo_column_names_as :=   geo_colums_as_array[1] || ', ' ||  geo_colums_as_array[2] ;
   	tmp_table_names_as := table_name_tmp_t1 || ' AS t_1, ' || table_name_tmp_t2 || ' AS t_2';

	-- Create the temp result table, use UNLOGGED because it's faster
	-- We don't need to drop 
	command_string := format('DROP TABLE IF EXISTS %s',result_table_name_tmp);
	EXECUTE command_string;
  	new_table_def_sql := 'Select ' || column_names_as  || ' from ' ||  tables_as_array[1] || ', ' || tables_as_array[2] || ' WHERE ST_Intersects(' || geo_column_names_as || ') limit 0';
	command_string := format('CREATE TEMP TABLE %s AS %s',result_table_name_tmp,new_table_def_sql);
	RAISE NOTICE 'command_string : % ',command_string;
	EXECUTE command_string;
	-- add a result geometry column
	command_string := format('ALTER TABLE %s ADD COLUMN geom geometry(geometry)',result_table_name_tmp);
	EXECUTE command_string;
    
	-- Create the temp table for data from table 1
	-- We don't need to drop 
    command_string := format('DROP table IF EXISTS %s',table_name_tmp_t1);
    EXECUTE command_string;
    new_table_def_sql := 'Select ' || org_columns_names_array[1]  || ' from ' ||  tables_as_array[1] || ' limit 0';
    command_string := format('CREATE TEMP TABLE %s AS %s',table_name_tmp_t1,new_table_def_sql);
    RAISE NOTICE 'command_string : % ',command_string;
    EXECUTE command_string;
    -- add a result geometry column
    command_string := format('ALTER TABLE %s ADD COLUMN %I geometry(geometry)',table_name_tmp_t1,geo_colums_array[1]);
    RAISE NOTICE 'command_string : % ',command_string;
    EXECUTE command_string;
    -- add index
    command_string := format('CREATE INDEX ON %s USING gist (%s)',table_name_tmp_t1,geo_colums_array[1]);
    EXECUTE command_string;
	-- add flag for to show if the intersects the cell line
	--command_string := format('ALTER TABLE %s ADD COLUMN cell_border_geom boolean ',table_name_tmp_t1);
	--EXECUTE command_string;

    
    -- Create the temp table for data from table 2
	-- We don't need to drop 
    command_string := format('DROP table IF EXISTS %s',table_name_tmp_t2);
    EXECUTE command_string;
    new_table_def_sql := 'Select ' || org_columns_names_array[2]  || ' from ' ||  tables_as_array[2] || ' limit 0';
    command_string := format('CREATE TEMP TABLE %s AS %s',table_name_tmp_t2,new_table_def_sql);
    RAISE NOTICE 'command_string : % ',command_string;
    EXECUTE command_string;
    -- add a result geometry column
    command_string := format('ALTER TABLE %s ADD COLUMN %I geometry(geometry)',table_name_tmp_t2,geo_colums_array[2]);
    RAISE NOTICE 'command_string : % ',command_string;
    EXECUTE command_string;
    -- add index
    command_string := format('CREATE INDEX ON %s USING gist (%s)',table_name_tmp_t2,geo_colums_array[2]);
    EXECUTE command_string;
	-- add flag for to show if the intersects the cell line
	--command_string := format('ALTER TABLE %s ADD COLUMN cell_border_geom boolean ',table_name_tmp_t2);
	--EXECUTE command_string;


--	command_string := format('CREATE INDEX ON %s USING gist (geom)',result_table_name_tmp);
--	EXECUTE command_string;

END;
$body$
LANGUAGE 'plpgsql';


-- Grant som all can use it
GRANT EXECUTE ON FUNCTION esri_union_create_tmp_tables (scp esri_union_single_cell_pameter) to PUBLIC;
