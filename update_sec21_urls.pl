#!/usr/bin/perl 
chdir "/home/dameat/edgarapi/backend/";
require "common.pl";

our $db;
our $datadir;
	my $sth = $db->prepare("update filings set sec_21_url = ? where filing_id = ?");
	$filing = $db->selectall_arrayref("select filing_id, filename, quarter, year, a.cik, company_name from filings a $join where has_sec21 = 1 $where order by company_name") || die "$!";
	foreach my $filing (@$filing) {
		open(FILE, "$datadir/$filing->[3]/$filing->[2]/$filing->[0].sec21");
		my $filename;
		while (<FILE>) { 
			if ($_ =~ /^<FILENAME>(.+)/) {
				$filename = $1;
				last;
			}
		}
		my $path = $filing->[1];
		$path =~ s/\-//g;
		$path =~ s/.{4}$//;
		$filename = "http://idea.sec.gov/Archives/$path/$filename";
		$sth->execute($filename, $filing->[0]);
	}

