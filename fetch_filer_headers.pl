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
use Time::HiRes qw(time sleep);

my ($year, $nuke) = @ARGV;

my $where = "";
if ($year && $year ne 'all') { 
	$where = " and year = $year ";
} 
my $manager = new Parallel::ForkManager( 10 );

print "query...\n";
#Get list of all potential filings from filings table, then compare against filers table to only get cik/year combos we don't already have. Then group the results by cik/year and return the most recent
my $filings = $db->selectall_arrayref(" 
	select a.filing_id, filename, cik, type,year,quarter 
	from filings a 
	join ( 
		select max(b.filing_id) as filing_id from ( 
			select filing_id as filing_id, cik, year 
			from filings 
			where cik != 0 and bad_header = 0  and type != '4' and type != 'REGDEX' $where 
			group by cik,year 
		) a 
		join filings b using(filing_id, cik, year) 
		left join filers c  on ((a.cik= c.cik and a.year = c.year)) 
		left join filers d on a.filing_id = d.filing_id and d.cik is not null 
		where c.filer_id is null and d.filer_id is null 
		group by a.cik, a.year
	) b using (filing_id)
	order by year, quarter
") || die "unable to select filings:".$db->errstr;
print "done...\n";
my $count = 0;
my $total = $#${filings}+1;
print "Checking $total filings\n";
our $logdir; 
open(LOG, ">>$logdir/fetch_headers.log");
print LOG "---\nfetching headers - ".localtime()."\n---\n";
foreach my $filing (@$filings) { 
	my ($id, $file, $cik, $form, $year, $q) = @$filing;
	print "\r\t".int((++$count/$total)*100)."% ($year $q)";
	#print "$id\n";
	unless (-d "$datadir$year/$q/") { mkdir("$datadir$year/$q/") ; }
	my $output = "$datadir$year/$q/$id";
	if (-f "$output.hdr") { 
		#if ($type eq '4') { 
		#	unlink("$output.hdr");
		#} else {
		#print "\tSkipping $cik ($id)- File Exists\n"; 
		next;
		#}
	}
	$manager->start and next;
	$start = time;
	print ".";
	&download_filing($filing);
	$exec_time = 1 - (time - $start);
	if ($exec_time > 0) {
		sleep($exec_time);
	}
	#Time::HiRes::sleep(.1);
	$manager->finish;
}
$manager->wait_all_children;
print "\nDone\n";

sub download_filing() {
	my $filing = shift;
	my $count = shift;
	$count = $count ? $count : 0;
	my ($id, $file, $cik, $form, $year, $q) = @$filing;
	#if ($count && $count > 5) { 
	#	$db = &dbconnect();
	#	$db->do("update filings set bad_header =1 where filing_id = $id");
	#	print LOG "\n\ttried $file too many times - giving up\n";
	#	print LOG "Badfiling: $id, $file, $cik, $form, $year, $q\n";
	#	return; 
	#}
	my $output = "$datadir$year/$q/$id";
	#print LOG "Fetching $cik ($id = $file):\n";
	$file =~ /([\d-]+)\.txt/;
	my $file_id = $1;
	unless ($file_id) { 
		print LOG "Filing $id has a bad file entry: ($file) - marking as bad and skipping\n";
		$db->do("update filings set bad_header =1 where filing_id = $id");
		return;
	}
	my $filing_dir = $file_id;
	$filing_dir =~ s/-//g;
	my $url = "http://www.sec.gov/Archives/edgar/data/$cik/$filing_dir/$file_id-index.htm";
	my $ua = LWP::UserAgent->new();
	#my $ua2 = LWP::UserAgent->new();
	my $res2 = $ua->get("$url");
	my $header;
	unless ($res2->is_success) { 
		print "\n\tUnable to fetch $url: $!\n"; 
	} else {
		$header = $res2->content();
	}
	my $bad_header = 0;
	if (! $header || $header =~ /Sorry, there was a problem/ || $header =~ /ERROR 404: File not found/) { 
		$bad_header = 1;
	} elsif ($header !~ /$cik/) { 
		$bad_header = 2;
	}
	if ($bad_header) {
		if ($bad_header == 1) {
			$count++;
		}
		if ( $count > 5 || $bad_header == 2) { 
			$db = &dbconnect();
			$db->do("update filings set bad_header =1 where filing_id = $id");
			$filing = $db->selectrow_arrayref(" select b.filing_id, filename, b.cik, type,b.year,quarter from ( select max(filing_id) as filing_id, cik, year from filings where cik != 0 and bad_header = 0 and cik=$cik and year = $year group by cik,year having group_concat(distinct type) != '4' and group_concat(distinct type) != 'REGDEX') a join filings b using(filing_id, cik, year) left join filers c  on ((a.cik= c.cik and a.year = c.year)) left join filers d on a.filing_id = d.filing_id where c.filer_id is null and d.filer_id is null order by b.year, quarter");
			if ($bad_header == 1) {
				print LOG "\n\ttried $file too many times - giving up: ";
				print LOG "$id, $file, $cik, $form, $year, $q\n";
			} else {
				print LOG "\n\t$id ($year) did not contain cik $cik\n";
			}
			unless ($filing) {
				print LOG "No filings left for $cik in $year - giving up\n";
				return;
			}
		} else {
			print LOG "\n\trefetching $url ($id) for the $count time\n";
		}
		&download_filing($filing, $count);
	} else {
		open (HEADER, ">$output\.hdr");
		print HEADER $header;
		close HEADER;
		#print "\n\t$cik ($id): done\n";
	}
}
