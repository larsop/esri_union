#!/usr/bin/perl
use File::Copy;
use File::Spec::Functions;

my ($pre_filename) = @ARGV;


print "\n Output file is $pre_filename \n";

$ESRI_UNION='esri_union-pre.sql';

if ( -e '/Users/lop/dev/github/esri_union/src/main/sql/function_01_esri_unio_create_tmp_tables.sql' ) 
{


	print "Source file exist so we can create a new $ESRI_UNION \n";
	# We need the spatial ref. for this tests 
	open($fh_out, ">", $ESRI_UNION);

	# TODO find another way to to get data from github
	for my $file (glob '/Users/lop/dev/github/esri_union/src/main/sql/func*.sql') {
		copy_file_into($file,$fh_out);
	}

	# TODO find another way to to get data from github
	for my $file (glob '/Users/lop/dev/github/content_balanced_grid/func_grid/func*.sql') {
		copy_file_into($file,$fh_out);
	}

	copy_file_into('/Users/lop/dev/github/esri_union/src/test/sql/regress/esri_union-pre-data.sql',$fh_out);
	
	close($fh_out);	 
	
	
} 
else
{
	print "Source file use the old one $ESRI_UNION \n";
}

# build up topo_update.sql file used for test
open($fh_out_final, ">", $pre_filename);

copy_file_into($ESRI_UNION,$fh_out_final);

copy_file_into('../../../main/sql/topo_update/schema_topo_update.sql',$fh_out_final);

for my $file (glob '../../../main/sql/topo_update/schema_userdef*') {
	copy_file_into($file,$fh_out_final);
}

for my $file (glob '../../../main/sql/topo_update/function*') {
	copy_file_into($file,$fh_out_final);
}

close($fh_out_final);	 


sub copy_file_into() { 
	my ($v1, $v2) = @_;
	open(my $fh, '<',$v1);
	while (my $row = <$fh>) {
	  print $v2 "$row";
	}
	close($fh);	 
    
}
