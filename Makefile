all:
	@echo "Try make check"

check:
	$(MAKE) -C src/test/sql/regress/ check
