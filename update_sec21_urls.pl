#!/usr/bin/perl 

    # Copyright 2009 CorpWatch.org 
    # San Francisco, CA | 94110, USA | Tel: +1-415-641-1633
    # Developed by Greg Michalec and Skye Bender-deMoll
    
    # This program is free software: you can redistribute it and/or modify
    # it under the terms of the GNU General Public License as published by
    # the Free Software Foundation, either version 3 of the License, or
    # (at your option) any later version.

    # This program is distributed in the hope that it will be useful,
    # but WITHOUT ANY WARRANTY; without even the implied warranty of
    # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    # GNU General Public License for more details.

    # You should have received a copy of the GNU General Public License
    # along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
#-----------------------------------   
# This script updates the urls for the Exhibt 21 pages in the database to convert them into a better form
#-----------------------------------
 

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

