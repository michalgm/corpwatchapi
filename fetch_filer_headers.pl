#!/usr/bin/perl -w

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
    
#---------------------------------------
# This script fetches html header files for filings, to be parsed by parse_headers.pl
#---------------------------------------




#use this if yo uneed to: grep -rl "Sorry, there was a problem" data/* | xargs rm

require './common.pl';
our $db;
our $datadir;
$| = 1;

use Parallel::ForkManager;
use LWP::UserAgent;
use Compress::Zlib;
use Time::HiRes;
my $year = "";
if ($ARGV[0]) { 
	$year = " and year = $ARGV[0] ";
}
if ($ARGV[1]) { 
	$year .= " and cik = $ARGV[1] ";
}
print "query...";
$sth = $db->prepare("select filing_id, filename, cik, type,year,quarter from ( select max(filing_id) as filing_id from filings where cik != 0 $year group by cik,year having group_concat(distinct type) != '4' and group_concat(distinct type) != 'REGDEX') a join filings b using(filing_id) order by filing_id");
print "prepared...$sth\n";
$sth->execute();
print "done...\n";
my $count = 0;

open(BADFILINGS, ">bad_filings.log");
my $manager = new Parallel::ForkManager( 5 );
	while(my $filing = $sth->fetchrow_arrayref) { 
		my ($id, $file, $cik, $form, $year, $q) = @$filing;
		print "$id\n";
		unless (-d "$datadir$year/$q/") { mkdir("$datadir$year/$q/") ; }
		my $output = "$datadir$year/$q/$id";
		if (-f "$output.hdr") { 
			#if ($type eq '4') { 
			#	unlink("$output.hdr");
			#} else {
			print "\tSkipping $cik ($id)- File Exists\n"; 
			next;
			#}
		}
		$manager->start and next;
		&download_filing($filing);
		#Time::HiRes::sleep(.1);
		$manager->finish;
	}
#$manager->wait_all_children;
#print "\nDone\n";

sub download_filing() {
	my $filing = shift;
	my $count = shift;
	my ($id, $file, $cik, $form, $year, $q) = @$filing;
	if ($count && $count > 5) { 
		print "tried $file too many times - giving up\n";
		print BADFILINGS "$id, $file, $cik, $form, $year, $q";
		return; 
	}
	my $output = "$datadir$year/$q/$id";
	print "Fetching $cik ($id):\n";
	$file =~ /([\d-]+)\.txt/;
	my $file_id = $1;
	my $filing_dir = $file_id;
	$filing_dir =~ s/-//g;
	my $url = "http://www.sec.gov/Archives/edgar/data/$cik/$filing_dir/$file_id-index.htm";
	my $ua = LWP::UserAgent->new();
	#my $ua2 = LWP::UserAgent->new();
	my $res2 = $ua->get("$url");
	my $header;
	unless ($res2->is_success) { 
		print "Unable to fetch $url: $!\n"; 
	} else {
		$header = $res2->content();
	}
	if (! $header || $header =~ /Sorry, there was a problem/) {
		$count++;
		print "refetching $url ($id) for the $count time\n";
		&download_filing($filing, $count);
	} else {
		open (HEADER, ">$output\.hdr");
		print HEADER $header;
		close HEADER;
		print "\t$cik ($id): done\n";
	}
}
