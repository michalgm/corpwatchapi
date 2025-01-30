#!/usr/bin/perl
require './common.pl';
our $db;
my @years = our @years_available;
open (LOG, ">>$logdir/cleanup_state.log");
print LOG "------------------------------------------\nbeginning cleanup - ".localtime()."\n-------------------------------\n";
my $state_changed = 0;
#@years = (2009);
#Every ,sec21 should have sec21 entry in filings, else delete .sec21
#every .hdr should have entry in filers, else delete .hdr
#every filer should have .hdr, else delete filer
#Every sec21 filing should have .sec21, else delete filing
#every relationship should have filing entry else delete relationship
#every filer should have filing entry else delete filer
#
foreach my $year (@years) {
	my $filers = $db->selectall_hashref("select distinct b.filing_id, b.cik from filers b join filings a using(filing_id) where b.year = $year and bad_header = 0", 'filing_id');
	foreach my $q (1 .. 4) {
		print "** $year $q **\n\n";
		my $filings = $db->selectall_hashref("select distinct filing_id, cik, type from filings b where year = $year and quarter = $q and has_sec21 = 1", 'filing_id');
		my $dir = "$datadir/$year/$q/" || die("can't open $dir");
		opendir(DIR, $dir);
		my @files = readdir(DIR);
		closedir(DIR);
		foreach my $file (@files) {
			if ($file =~ /^(\d+)\.(sec21|hdr)$/) {
				my ($id, $type) = ($1, $2);
				if ($type eq 'sec21') {
					if ($filings->{$id}) {
						$filings->{$id}->{found} =1;
					} else {
						print LOG "\tdeleting $dir/$file\n";
						$state_changed = 1;
						print "rm $dir/$file\n";
						system("rm $dir/$file");
					}
				} else {
					if ($filers->{$id}) {
						$filers->{$id}->{found} =1;
					} else {
						print LOG "\tdeleting $dir/$file\n";
						$state_changed = 1;
						print "rm $dir/$file\n";
						system("rm $dir/$file");
					}
				}
			}
		}
		foreach my $id (keys(%$filings)) {
			unless ($filings->{$id}->{found} == 1) { 
				$state_changed = 1;
				print LOG "\tremoving filing for $year\-$q cik: $filings-{$id}->{cik} type: $filings-{$id}->{type}\n"; 
				print "delete from filings where filing_id = $id\n";
				$db->do("delete from filings where filing_id = $id");
			}
		}
	}
	foreach my $id (keys(%$filers)) {
		unless ($filers->{$id}->{found} == 1) { 
			$state_changed = 1;
			if ($filers->{$id}->{cik}) { 
				print LOG "\tremoving filer for $year cik: $filers->{$id}->{cik}\n"; 
				print "delete from filers where cik = $filers->{$id}->{cik} and year = $year\n";
				$db->do("delete from filers where cik = $filers->{$id}->{cik} and year = $year");
			}
		}
	}
}

print "deleting orphaned filers\n";
$rows = $db->do("DELETE a FROM filers a JOIN filings b USING (filing_id) WHERE b.cik IS NULL");
# $db->do("update filers a left join filings b using (filing_id) set a.filing_id = null where b.cik is null");
# $rows = $db->do("delete from filers where filing_id is null");
if ($rows > 0 ) { 
	print LOG "$rows filers deleted due to missing filing\n";
	$db->do("update meta set value = 1 where meta = 'update_all_years'");
}
print "deleting orphaned relationships\n";
$rows = $db->do("DELETE a from relationships a join filings b using (filing_id) where b.cik is null");
# $db->do("update relationships a left join filings b using (filing_id) set a.filing_id = null where b.cik is null");
# $rows = $db->do("delete from relationships where filing_id is null");
if ($rows > 0 ) { 
	print LOG "$rows relationships delete due to missing filing\n";
	$db->do("update meta set value = 1 where meta = 'update_all_years'");
}
exit;

