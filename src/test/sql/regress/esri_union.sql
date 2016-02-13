-- Repeat all tests with the new function names.
SELECT '1', count(*) from sl_lop.ar250_flate_rute_3_flate;
SELECT '2', count(*) from sl_lop.beitebruk;
SELECT '3', count(*) from sl_lop.ar250_flate_rute_3_flate a, sl_lop.beitebruk b WHERE ST_Intersects(a.geo,b.geom);
SELECT '4', get_esri_union('sl_lop.ar250_flate_rute_3_flate sl_sdeid geo','sl_lop.beitebruk gid geom','sl_lop.res_beite_bruk',500);
