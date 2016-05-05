
drop schema sl_lop cascade;

DROP FUNCTION esri_union_create_tmp_tables (scp esri_union_single_cell_pameter);

DROP FUNCTION esri_union_intersection(g1 geometry,g2 geometry,remove_holes boolean);

DROP FUNCTION valid_multipolygon_difference(g1 geometry,g2 geometry);

DROP FUNCTION esri_union_remove_grid (	result_table text,
	pk_key_one text,
	pk_key_two text);
	
DROP FUNCTION get_esri_union_cell (
scp esri_union_single_cell_pameter, 
create_tmp_table boolean);

DROP FUNCTION get_esri_union (
input_table_one text, 
input_table_two text,
result_table_name text,
max_rows_pr_cell integer,
remove_grid_lines boolean,
tmp_grid_table_name text);

DROP FUNCTION get_esri_union_muti_thread (
input_table_one text, 
input_table_two text,
result_table_name text,
max_rows_pr_cell integer,
tmp_grid_table_name text, 
run_sql_created boolean,
remove_grid_lines boolean); 

DROP FUNCTION cbg_get_table_extent (schema_table_name_column_name_array VARCHAR[]);

DROP FUNCTION cbg_content_based_balanced_grid (	
													table_name_column_name_array VARCHAR[], 
													grid_geom_in geometry,
													min_distance integer,
													max_rows integer);	
DROP FUNCTION cbg_content_based_balanced_grid(
													table_name_column_name_array VARCHAR[],
													max_rows integer); 
													
DROP TYPE IF EXISTS esri_union_single_cell_pameter cascade;
