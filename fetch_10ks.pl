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
    
#---------------------------------
# This script is used to download SEC filings corresponding to a listing in the database
#--------------------------------

require './common.pl';
our $db;
our $datadir;
$| = 1;

use Compress::Zlib;
use Time::ParseDate;
use Time::HiRes qw(time sleep);
use Date::Format; 
use Parallel::ForkManager;

$ua = create_agent();

my $manager = new Parallel::ForkManager( 10 );

my ($year, $nuke) = @ARGV;
my (@years, @quarters);
my $update = 0;
$db_current_date = $db->selectcol_arrayref('select value from meta where meta = "update_date" limit 1')->[0];
$current_date = $db_current_date ? parsedate($db_current_date) : ""; 
if (! $current_date || $current_date < 0) {
  $year = 'all';
}
$update_all_years = $db->selectrow_arrayref('select value from meta where meta = "update_all_years"');
if ($update_all_years && $update_all_years->[0]){
	print "Overriding to update all years due to changed state\n";
	$year = 'all';
	$db->do("alter table filings auto_increment = 0");
	$db->do("alter table filers auto_increment = 0");
}
if ($year) { 
	if ($year eq 'all') {
		@years = our @years_available;
	} else {
		@years = ($year);
	}
	@quarters = (1 .. 4);
} else {
	print "Calculating most recent quarter\n";
	($year, $quarter) = $db->selectrow_array("select year, quarter from filings order by year desc, quarter desc limit 1");
	@years =($year);
	@quarters = ($quarter .. 4);
	$update = 1;
}
unless (-d "$datadir") { mkdir("$datadir") ; }
if ($nuke) {
	print "Resetting data\n";
	foreach my $year (@years) { 
		$db->do("delete from filings where year = $year");
		`rm -rf $datadir/$year/*`;
	}
	$db->do("alter table filings auto_increment = 0");
}

#my $sth3 = $db->prepare("select filing_id from filings where year=? and quarter=? and type=? and filename=? and cik=?") || die "$!";

foreach my $year (@years) { 
	unless (-d "$datadir$year/") { mkdir("$datadir$year/") ; }
	foreach my $q (@quarters) { 
		unless (-d "$datadir$year/$q/") { mkdir("$datadir$year/$q/") ; }
		print "\nFetching $year Q$q: ";
		$res = $ua->get("http://www.sec.gov/Archives/edgar/full-index/$year/QTR".$q."/master.gz");
		unless ($res->is_success) { die "Unable to download SEC index for $year Q$q: ".$res->status_line()." $!"; }

		#if we're updating, we need to keep fetching until it fails
		if ($update && $q == 4) {
			push(@years, $year+1);
		}

		$db = &dbconnect();
		my $content = Compress::Zlib::memGunzip($res->content());
		print "Caching filings already fetched\n";
		my $filings =$db->selectall_hashref("select concat(year,filename,type) as id from filings where year = $year and quarter = $q", 'id');
		#print $content;
		my @lines = split(/\n/, $content);
		shift @lines;
		my $count = 0;
		my $total = $#lines+1;
		foreach my $line (@lines) {
			print "\r".int((++$count/$total)*100)."%";
			my $id;
			if ($line =~ /^Last Data Received:\s+(.+)$/) {
				my $data_date = parsedate($1);
				if (! $current_date || $current_date < $data_date) {
					$date_string = time2str("%Y-%m-%d", $data_date);
					print "\n\t**updating current date to $date_string\n";
					$db->do("update meta set value = '$date_string' where meta = 'update_date'");
					$db->do("update meta set value = '$current_date' where meta = 'previous_update'");
				}
			}
			my ($cik, $name, $type, $date, $filename) = split(/\|/, $line);
			unless ($filename && $filename ne 'Filename') { next; }
			#$sth3 = $db->prepare_cached("select filing_id from filings where year=? and filename=? and type=?");
			#print "Testing $year $filename $type - ";
			#$sth3->execute($year, $filename, $type);
			if ($filings->{$year.$filename.$type}) {
			#if ($sth3->rows()) {
				#$sth3->finish;
				#print "Already entered - skipping\n";
				next;
			}
			#$sth3->finish;
			#print "\n$cik: ";
			$db = &dbconnect();

			my $sth = $db->prepare_cached("insert into filings (filing_date, type, company_name, filename, cik, has_sec21, year, quarter) values(?, ?, ?, ?, ?, 0, ?, ?)");
			$sth->execute($date, $type, $name, $filename, $cik, $year, $q) || die $sth->errstr;
			$id =  $db->last_insert_id(undef, 'edgarapi', 'filings', 'filing_id');	
			#print "$id";

			$db->disconnect();
			unless ($type =~ /^10-KT?(\/A)?$/) { $manager->finish; next; } #We only want 10-K, 10-K/A, 10-KT, 10-KT/A 
			my $pid = $manager->start and next;	
			$start = time;
			$db = &dbconnect();
			#print "\tFetching $cik ($id): ";
			my $output = "$datadir$year/$q/$id";
			if (-e "$output.sec21") { 
				#print "Skipping - File Exists"; 
				$manager->finish;
				next;
			}
			chomp($filename);
			#my $res2 = $ua->get("ftp://ftp.sec.gov/$file");
			my $res2 = $ua->get("http://www.sec.gov/Archives/$filename");
			unless ($res2->is_success) { print "Unable to fetch $filename: ". $res2->status_line() ." $!"; $manager->finish; next}
			my $filing = $res2->decoded_content();
			my ($header, $section21);
			#if ($filing =~ /(<SEC-HEADER>.+?<\/SEC-HEADER>)/s ) { $header = $1; }
			if ($filing =~ /(<DOCUMENT>\n<TYPE>EX-21.+?<\/DOCUMENT>)/s) { $section21 = $1; }
			if ($section21) { 
				my $sec_21_url = "";
				if ($section21 =~ /<FILENAME>([^\n]+)\n/s) { 
					$sec_21_url = $1;
					my $path = $filename;
					$path =~ s/\-//g;
					$path =~ s/.{4}$//;
					$sec_21_url = "http://www.sec.gov/Archives/$path/$sec_21_url";
				}
				#open (HEADER, ">$output\.hdr");
				#print HEADER $header;
				#close HEADER;
				open (SEC21, ">$output\.sec21");
				print SEC21 $section21;
				close SEC21;
				my $sth2 = $db->prepare_cached("update filings set has_sec21 = 1, sec_21_url = ? where filing_id = ?");
				$sth2->execute($sec_21_url, $id);
			} else { 
				#print "(no sec21) "; 
			}
			#print "done\n";
			$db->disconnect();
			$exec_time = 1 - (time - $start);
			if ($exec_time > 0) {
				sleep($exec_time);
			}
			$manager->finish;
		}
		$manager->wait_all_children;
	}
	if ($update) { 
		@quarters = (1 .. 4);
	}
}
print "\n";
$db->do("update meta set value = 0 where meta = 'update_all_years'");

