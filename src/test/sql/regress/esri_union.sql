-- Test 1 -------------
-- This is test that does a "esri union" between sl_lop.ar250_flate_rute_3_flate and sl_lop.sk_grl_flate

-- Test that input data are ok
SELECT '1', count(*) from sl_lop.ar250_flate_rute_3_flate;
SELECT '2', count(*) from sl_lop.sk_grl_flate;
SELECT '3', count(*) from sl_lop.ar250_flate_rute_3_flate a, sl_lop.sk_grl_flate b WHERE ST_Intersects(a.geo,b.geo);

-- Get the union between the table
SELECT '4', get_esri_union('sl_lop.ar250_flate_rute_3_flate sl_sdeid geo','sl_lop.sk_grl_flate komid geo','sl_lop.res_ar250_sk_grl',500,'sl_lop.grid_ar250_sk_grl');

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

-- SELECT '18', SUM(num_points) FROM (SELECT ST_NumPoints(ST_InteriorRingN(a.geo, generate_series(1, 52079))) as num_points from sl_lop.helling_data_d1 as a where gid = 9419961) as t;
-- The test abouve Fails after Time: 430062.190 ms,  Here is info from the log
-- 2016-02-22 11:29:41 CET   LOG:  server process (PID 40220) was terminated by signal 9: Killed
-- 2016-02-22 11:29:41 CET   DETAIL:  Failed process was running: SELECT '17', SUM(num_points) FROM (SELECT ST_NumPoints(ST_InteriorRingN(a.geo, generate_series(1, 52079))) as num_points from sl_lop.helling_data_d1 as a where gid = 9419961) as t
--         ;
-- 2016-02-22 11:29:41 CET   LOG:  terminating any other active server processes
-- 2016-02-22 11:29:41 CET   WARNING:  terminating connection because of crash of another server process
-- 2016-02-22 11:29:41 CET   DETAIL:  The postmaster has commanded this server process to roll back the current transaction and exit, because another server process exited abnormally and possibly corrupted shared memory.
-- 2016-02-22 11:29:41 CET   HINT:  In a moment you should be able to reconnect to the database and repeat your command.
-- 2016-02-22 11:29:41 CET sl lop FATAL:  the database system is in recovery mode
-- 2016-02-22 11:29:41 CET   LOG:  all server processes terminated; reinitializing
-- 2016-02-22 11:29:41 CET   LOG:  database system was interrupted; last known up at 2016-02-22 11:26:38 CET
-- 2016-02-22 11:29:45 CET   LOG:  database system was not properly shut down; automatic recovery in progress
-- 2016-02-22 11:29:45 CET   LOG:  record with zero length at 1F/C40F1A18
-- 2016-02-22 11:29:45 CET   LOG:  redo is not required
-- 2016-02-22 11:29:45 CET   LOG:  MultiXact member wraparound protections are now enabled
-- 2016-02-22 11:29:45 CET   LOG:  database system is ready to accept connections
-- 2016-02-22 11:29:45 CET   LOG:  autovacuum launcher started

