-- Test 1 -------------
-- This is test that does a "esri union" between sl_lop.ar250_flate_rute_3_flate and sl_lop.sk_grl_flate
-- More info at https://github.com/larsop/esri_union/wiki

-- Test that input data are ok
SELECT '1', count(*) from sl_lop.ar250_flate_rute_3_flate;
SELECT '2', count(*) from sl_lop.sk_grl_flate;
SELECT '3', count(*) from sl_lop.ar250_flate_rute_3_flate a, sl_lop.sk_grl_flate b WHERE ST_Intersects(a.geo,b.geo);

-- Get the union between the table
SELECT '4', get_esri_union('sl_lop.ar250_flate_rute_3_flate sl_sdeid geo','sl_lop.sk_grl_flate komid geo','sl_lop.res_ar250_sk_grl',500,true,'sl_lop.grid_ar250_sk_grl');

-- Check that the result sl_lop.res_ar250_sk_grl is ok 
SELECT '5', count(*) from sl_lop.res_ar250_sk_grl;
SELECT '6', round(Sum(ST_area(geom))::numeric, 13) from sl_lop.res_ar250_sk_grl;
SELECT '7', round(Sum(ST_area(a.geom))::numeric, 13) AS areal_new from sl_lop.res_ar250_sk_grl a WHERE a.t1_sl_sdeid  is not null;
SELECT '8', round(Sum(ST_area(b.geo))::numeric, 13) from sl_lop.ar250_flate_rute_3_flate b;
SELECT '9', round(Sum(ST_area(a.geom))::numeric, 13) from sl_lop.res_ar250_sk_grl a WHERE a.t2_komid  is not null;
SELECT '10', round(Sum(ST_area(b.geo))::numeric, 13) from sl_lop.sk_grl_flate b;
SELECT '11', round(Sum(ST_area(a.geom))::numeric, 13) AS areal_new from sl_lop.res_ar250_sk_grl a WHERE a.t1_sl_sdeid  is not null AND a.t2_komid  is not null;

-- Test 2 -------------
-- This test on using polygons with more 50000 interior rings.
-- NB This test is not complete yet. We are just testing on input data.
SELECT '12', ST_NumPoints(ST_ExteriorRing(a.geo)) from sl_lop.helling_data_d1 as a where gid = 9419961;
SELECT '13', ST_NumInteriorRing(a.geo) from sl_lop.helling_data_d1 as a where gid = 9419961;
SELECT '14', ST_InteriorRingN(a.geo,1) as geo from sl_lop.helling_data_d1 as a where gid = 9419961;
SELECT '15', ST_InteriorRingN(a.geo,52079) as geo from sl_lop.helling_data_d1 as a where gid = 9419961;
SELECT '16', SUM(num_points) FROM (SELECT ST_NumPoints(ST_InteriorRingN(a.geo, generate_series(52075, 52079))) as num_points from sl_lop.helling_data_d1 as a where gid = 9419961) as t;
SELECT '17', sum(ST_Numpoints(ST_ExteriorRing(geom))) FROM (SELECT (ST_DumpRings(a.geo)).geom from sl_lop.helling_data_d1 as a where gid = 9419961) as test;

-- this test will take to long run on travis since this is 50000 interior ring, this must be run parrralel to get any speed
-- SELECT '18', get_esri_union('sl_lop.ar250_flate_rute_3_flate sl_sdeid geo','sl_lop.helling_data_d1 gid geo','sl_lop.res_ar250_helling',500,'sl_lop.grid_ar250_helling');


-- Test 3 -------------
-- This is test that does a "esri union" between sl_lop.ar250_flate_rute_3_flate and sl_lop.sk_grl_flate
-- More info at https://github.com/larsop/esri_union/wiki where it's son with two parameters
-- Since the result is somthing like 'union result table:esri_union_result_523edb181c823275bb956aabdb79420a , grid table used:grid_table_523edb181c823275bb956aabdb79420a'
-- We just check on the length
SELECT '30', char_length(get_esri_union('sl_lop.ar250_flate_rute_3_flate sl_sdeid geo','sl_lop.sk_grl_flate komid geo')::varchar);
