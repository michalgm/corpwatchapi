#!/usr/bin/perl 
use Parallel::ForkManager;

require "./common.pl";
$| =1;
our $db;
my $relationship_table = 'relationships';

print "deleting tables...\n";
$db->do("delete from $relationship_table");
$db->do("delete from filing_tables");
$db->do("alter table $relationship_table auto_increment = 0");
$db->do("alter table filing_tables auto_increment = 0");
print "done\n";

my $filings = $db->selectall_arrayref("select filing_id, filename, quarter, year, cik, company_name from filings where has_sec21 = 1 order by filing_id") || die "$!";

my $manager = new Parallel::ForkManager( 4 );
my ($x, $y) = 0;
my $limit = int($#${filings}*.01);
print "$#${filings} - $limit\n";
foreach my $filing (@$filings) {
	my $cmd = "perl sec21_headers.pl $filing->[0]";
    if ($x == $limit) { print "\r".++$y."%"; $x = 0; }
	print ".";
	$x++;

	$manager->start and next;
	$null = `$cmd`;
	#print `$cmd`;
	$manager->finish;
}


