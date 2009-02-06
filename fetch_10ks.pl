#!/usr/bin/perl -w
require './common.pl';
our $db;
our $datadir;
$| = 1;

use LWP::UserAgent;
use Compress::Zlib;
$ua = LWP::UserAgent->new(keep_alive=>1);

$nuke =1 ;
my $year = 2008;
unless (-d "$datadir") { mkdir("$datadir") ; }
unless (-d "$datadir$year/") { mkdir("$datadir$year/") ; }
if ($nuke) {
	$db->do("delete from filings");
	$db->do("alter table filings auto_increment = 0");
}
my $sth = $db->prepare("insert into filings values(null, ?, ?, ?, ?, ?, 0, '$year', ?)");
my $sth2 = $db->prepare("update filings set has_sec21 = 1 where filing_id = ?");
#my $sth3 = $db->prepare("select filing_id from filings where year=? and quarter=? and type=? and filename=? and cik=?") || die "$!";
my $count = 0;
foreach my $q (1,2,3,4) { 
#foreach my $q (2) { 
	unless (-d "$datadir$year/$q/") { mkdir("$datadir$year/$q/") ; }
	print "Fetching 2008 Q$q: ";
	$res = $ua->get("ftp://ftp.sec.gov/edgar/full-index/2008/QTR".$q."/master.gz");
	unless ($res->is_success) { die "$!"; }
	my $content = Compress::Zlib::memGunzip($res->content());
	#print $content;
	print "done\n";
	foreach my $line (split(/\n/, $content)) {
		my $id;
		my ($cik, $name, $form, $date, $file) = split(/\|/, $line);
		unless ($file) { next; }
		print "\n$cik: ";
		$count++;
		print "$count";
	
		$sth->execute($date, $form, $name, $file, $cik, $q) || die $sth->errstr;

		if ($count <= 754340) { 
			$id = $count;
			my $output = "$datadir$year/$q/$id";
			if (-e "$output.hdr") { 
				print "Skipping - File Exists"; 
				$sth2->execute($id);
			}
			next;
		}
		$id =  $db->last_insert_id(undef, 'edgarapi', 'filings', 'filing_id');	
		unless ($form =~ /^10-K(\/A)?/) { next; } 
		print "\tFetching $cik ($id): ";
		my $output = "$datadir$year/$q/$id";
		if (-e "$output.hdr") { 
			print "Skipping - File Exists"; 
			$sth2->execute($id);
			next;
		}
		chomp($file);
		my $res2 = $ua->get("ftp://ftp.sec.gov/$file");
		unless ($res2->is_success) { print "Unable to fetch $file: $!"; next}
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
