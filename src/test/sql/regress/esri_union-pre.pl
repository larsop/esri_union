#!/usr/bin/perl
use File::Copy;
use File::Spec::Functions;

$ESRI_UNION='esri_union-pre.sql';
print "\n Output file is $ESRI_UNION \n";

open($fh_out, ">", $ESRI_UNION);

# get funtion defs for esri union based grid
for my $file (glob '../../../main/sql/func*') {
	copy_file_into($file,$fh_out);
}

# get def for conetnet based grid
if ( -e '/Users/lop/dev/github/content_balanced_grid/func_grid' ) 
{
	# TODO find another way to to get data from github
	for my $file (glob '/Users/lop/dev/github/content_balanced_grid/func_grid/func*.sql') {
		copy_file_into($file,$fh_out);
	}
} 
else
{
	copy_file_into('esri_union-pre-cbg-def.sql',$fh_out);
	print "use the esri_union-pre-cbg-def.sql \n";
}

copy_file_into('esri_union-pre-data.sql',$fh_out);
close($fh_out);	 

sub copy_file_into() { 
	my ($v1, $v2) = @_;
	open(my $fh, '<',$v1);
	while (my $row = <$fh>) {
	  print $v2 "$row";
	}
	close($fh);	 
    
}
