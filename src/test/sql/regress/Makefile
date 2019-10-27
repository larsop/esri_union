POSTGIS_SCRIPT_DIR ?=/usr/share/postgresql/11/contrib/postgis-2.5

check: loader 00-regress
	POSTGIS_REGRESS_DB=nibio_reg ./run_test.pl --spatial_ref_sys --topology $(RUNTESTFLAGS) topo_update 

loader:
#	find / -name shp2pgsql 2>/dev/null # debug 
#	ls # debug
	
#	export PATH=$(PATH):`pg_config --bindir`; 
	export PATH=$(PATH):/usr/bin
	
	which shp2pgsql pgsql2shp > /dev/null || \
    { echo "shp2pgsql and pgsql2shp must be in your PATH" && exit 1; }; \
	mkdir -p ../loader; \
	ln -fs `which shp2pgsql` ../loader; \
	ln -fs `which pgsql2shp` ../loader

00-regress:
	find /usr/share/postgresql -name postgis.sql # debug 
	find /usr/share/postgresql -name shp2pgsql # debug 
	ls $(POSTGIS_SCRIPT_DIR) # debug
	
	@test -f $(POSTGIS_SCRIPT_DIR)/postgis.sql || \
    { echo "No postgis.sql file found in $(POSTGIS_SCRIPT_DIR)," \
           "please tweak \$$POSTGIS_SCRIPT_DIR" && exit 1; }
	@test -f $(POSTGIS_SCRIPT_DIR)/topology.sql || \
    { echo "No topology.sql file found in $(POSTGIS_SCRIPT_DIR)," \
           "please tweak \$$POSTGIS_SCRIPT_DIR" && exit 1; }
	test -e 00-regress-install/share/contrib/postgis || { \
	mkdir -p 00-regress-install/share/contrib; \
	ln -fs $(POSTGIS_SCRIPT_DIR) 00-regress-install/share/contrib/postgis; \
  }
