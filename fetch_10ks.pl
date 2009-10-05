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

use LWP::UserAgent;
use Compress::Zlib;
$ua = LWP::UserAgent->new(keep_alive=>1);

$nuke =0 ;
my $year;
if ($ARGV[0]) { 
	$year = $ARGV[0];
}
unless (-d "$datadir") { mkdir("$datadir") ; }
unless (-d "$datadir$year/") { mkdir("$datadir$year/") ; }
if ($nuke) {
	$db->do("delete from filings");
	$db->do("alter table filings auto_increment = 0");
}
my $sth = $db->prepare("insert into filings (filing_date, type, company_name, filename, cik, has_sec21, year, quarter) values(?, ?, ?, ?, ?, 0, '$year', ?)");
my $sth2 = $db->prepare("update filings set has_sec21 = 1 where filing_id = ?");
#my $sth3 = $db->prepare("select filing_id from filings where year=? and quarter=? and type=? and filename=? and cik=?") || die "$!";
foreach my $q (1,2,3,4) { 
#foreach my $q (2) { 
	unless (-d "$datadir$year/$q/") { mkdir("$datadir$year/$q/") ; }
	print "Fetching $year Q$q: ";
	$res = $ua->get("ftp://ftp.sec.gov/edgar/full-index/$year/QTR".$q."/master.gz");
	unless ($res->is_success) { die "Unable to download SEC index for $year Q$q: $!"; }
	my $content = Compress::Zlib::memGunzip($res->content());
	#print $content;
	print "done\n";
	my @lines = split(/\n/, $content);
	shift @lines;
	foreach my $line (@lines) {
		if ($. == 1) { next; }
		my $id;
		my ($cik, $name, $type, $date, $filename) = split(/\|/, $line);
		unless ($filename && $filename ne 'Filename') { next; }
		$sth3 = $db->prepare_cached("select filing_id from filings where year=? and filename=? and type=?");
		#print "Testing $year $filename $type - ";
		$sth3->execute($year, $filename, $type);
		if ($sth3->rows()) {
			$sth3->finish;
			print "Already entered - skipping\n";
			next;
		}
		$sth3->finish;
		print "\n$cik: ";
	
		$sth->execute($date, $type, $name, $filename, $cik, $q) || die $sth->errstr;
		$id =  $db->last_insert_id(undef, 'edgarapi', 'filings', 'filing_id');	
		print "$id";

		unless ($type =~ /^10-K(\/A)?/) { next; } 
		print "\tFetching $cik ($id): ";
		my $output = "$datadir$year/$q/$id";
		if (-e "$output.hdr") { 
			print "Skipping - File Exists"; 
			$sth2->execute($id);
			next;
		}
		chomp($filename);
		#my $res2 = $ua->get("ftp://ftp.sec.gov/$file");
		my $res2 = $ua->get("http://idea.sec.gov/Archives/$filename");
		unless ($res2->is_success) { print "Unable to fetch $filename: $!"; next}
		my $filing = $res2->content();
		my ($header, $section21);
		if ($filing =~ /(<SEC-HEADER>.+?<\/SEC-HEADER>)/s ) { $header = $1; }
		if ($filing =~ /(<DOCUMENT>\n<TYPE>EX-21.+?<\/DOCUMENT>)/s) { $section21 = $1; }
		if ($section21) { 
			open (HEADER, ">$output\.hdr");
			print HEADER $header;
			close HEADER;
			open (SEC21, ">$output\.sec21");
			print SEC21 $section21;
			close SEC21;
			$sth2->execute($id);
		} else { print "(no sec21) "; }
		print "done\n";
	}
}
