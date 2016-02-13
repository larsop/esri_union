-- Repeat all tests with the new function names.
SELECT '1', count(*) from sl_lop.ar250_flate_rute_3_flate;
SELECT '2', count(*) from sl_lop.sk_grl_flate;
SELECT '3', count(*) from sl_lop.ar250_flate_rute_3_flate a, sl_lop.sk_grl_flate b WHERE ST_Intersects(a.geo,b.geo);
SELECT '4', get_esri_union('sl_lop.ar250_flate_rute_3_flate sl_sdeid geo','sl_lop.sk_grl_flate komid geo','sl_lop.res_ar250_sk_grl',500,'sl_lop.grid_ar250_sk_grl');
SELECT '5', count(*) from sl_lop.res_ar250_sk_grl;
SELECT '6', Sum(ST_area(geom)) from sl_lop.res_ar250_sk_grl;
SELECT '7', Sum(ST_area(a.geom)) AS areal_new from sl_lop.res_ar250_sk_grl a WHERE a.t1_sl_sdeid  is not null;
SELECT '8', Sum(ST_area(b.geo)) from sl_lop.ar250_flate_rute_3_flate b;
SELECT '9', Sum(ST_area(a.geom)) from sl_lop.res_ar250_sk_grl a WHERE a.t2_komid  is not null;
SELECT '10', Sum(ST_area(b.geo)) from sl_lop.sk_grl_flate b;
SELECT '11', Sum(ST_area(a.geom)) AS areal_new from sl_lop.res_ar250_sk_grl a WHERE a.t1_sl_sdeid  is not null AND a.t2_komid  is not null;

