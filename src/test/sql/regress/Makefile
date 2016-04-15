POSTGIS_SCRIPT_DIR ?= `pg_config --sharedir`/contrib/postgis-2.1

check: loader 00-regress
	POSTGIS_REGRESS_DB=nibio_reg ./run_test.pl --spatial_ref_sys --topology $(RUNTESTFLAGS) esri_union 

loader:
	export PATH=$(PATH):`pg_config --bindir`; \
	which shp2pgsql pgsql2shp > /dev/null || \
    { echo "shp2pgsql and pgsql2shp must be in your PATH" && exit 1; }; \
	mkdir -p ../loader; \
	ln -fs `which shp2pgsql` ../loader; \
	ln -fs `which pgsql2shp` ../loader

00-regress:
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
