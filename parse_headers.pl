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
    
#---------------------------------------
# This script is also used to extract company meta data from the headers of 10-K filings
#---------------------------------------



use HTML::TreeBuilder;
use Data::Dumper;
use Parallel::ForkManager;
require './common.pl';
our $db;
$| = 1;
our $logdir;
open (LOG, ">$logdir/parse_headers.log");

my ($year, $nuke) = @ARGV;
$where = "";
if ($year) {
	$where = " and year = $year ";
	@years = ($year);
} else {
	@years = our @years_available;
}

print "Resetting...\n";
if ($nuke) {
	$db->do("delete from filers where filer_id = filer_id $where");
	$db->do("alter table filers auto_increment= 0");
}
print "Caching already_parsed...\n";
#my $file = "data/2008/1/68065.hdr"; 
#my $cik = "0001156491";
$db->disconnect;

my $manager = new Parallel::ForkManager( 5 );

foreach my $year (@years) {
	my $already_parsed = $db->selectall_hashref("select b.filing_id from filers b where b.year = $year and cik is not null", 'filing_id');
	foreach my $q (1 .. 4) {
		my @check_headers;
		my $dir = "$datadir/$year/$q/" || die("can't open $dir");
		opendir(DIR, $dir);
		my @files = readdir(DIR);
		closedir(DIR);
		print "\nChecking $year Q $q\n";
		foreach my $file (@files) {
			if ($file =~ /^(\d+)\.hdr$/) {
				my $id = $1;
				unless ($already_parsed->{$id}) {
					push(@check_headers, {id=>$id, file=>$file});
				}
			}
			#if ($filing_id eq 'imdone') { print 'BAILING!!!!'; $manager->wait_all_children; exit; }
		}
		my $total = $#check_headers +1;
		if ($total > 0) {
			print "\tNeed to parse $total headers\n";
			my $set_size = int($total * .01);
			if ($set_size == 0) { $set_size =1; }
			$limit = int($total / $set_size * .01);
			my ($x, $y) = 0;
			for my $set (0 .. int($total/$set_size)+1) { 
				if ($x == $limit) { $y++; print "\r\t".($y)."%"; $x = 0; } $x++;
				my $pid = $manager->start and next;
				$db = &dbconnect();
				for my $count (0 .. $set_size-1) {
					$count += ($set * $set_size);
					if ($count > $total) { $manager->finish; }
					my $id = $check_headers[$count]{id};
					my $file = $check_headers[$count]{file};
					if ($id) {
						unless (my $filers = &parse_filers("$dir/$file", $id)) {
							print LOG "$id didn't parse\n";
						}
					}
				}
				$db->disconnect;
				$manager->finish();
			}
		}
	}
}


$manager->wait_all_children;
print "\nHiding bad ciks...\n";
#The following 2 queries can be undone with this: update filers a join filings b using(filing_id) set a.cik = b.cik where a.cik is null
	#This finds filers that match to other filers on name and location, but with different ciks and sets one side to have null cik, preserving the side that has sec_21
	$db->do("update filers a join (select b.cik from filers a join filers b use key (clean_name) using (match_name) join filings c on a.cik = c.cik join filings d on b.cik = d.cik and a.year = c.year and b.year = d.year where (a.incorp_country_code = b.incorp_country_code or (a.incorp_country_code is null and b.incorp_country_code is null)) and (a.incorp_subdiv_code = b.incorp_subdiv_code or (a.incorp_subdiv_code is null and b.incorp_subdiv_code is null)) and a.cik != b.cik and c.has_sec21 =1  and (d.has_sec21 = 0 or a.cik > b.cik) group by a.cik, b.cik) b using (cik) set a.cik = null");
	#This does the same as the previous, but for pairs without sec21s
	$db->do("update filers a join (select b.cik from filers a join filers b use key (clean_name) using (match_name) where (a.incorp_country_code = b.incorp_country_code or (a.incorp_country_code is null and b.incorp_country_code is null)) and (a.incorp_subdiv_code = b.incorp_subdiv_code or (a.incorp_subdiv_code is null and b.incorp_subdiv_code is null)) and a.cik != b.cik and a.cik > b.cik and a.cik is not null group by a.cik, b.cik) b using (cik) set a.cik = null");


sub parse_filers() {
	my ($file, $id) = @_;
	my $filers;
	my $sth = $db->prepare_cached('select cik, year from filings where filing_id = ?');
	$sth->execute($id);
	my $res = $sth->fetchrow_arrayref();
	unless ($res) { 
		print LOG "BaD: $id, $file\n"; 
		`rm ./$file`;
		return;
	}

	my $cik = $res->[0];
	my $year = $res->[1];
	$sth->finish;
	#print "$file - $id - $cik\n";
	my $tree = HTML::TreeBuilder->new_from_file($file);
	unless ($tree->as_text =~ /$cik/) {
		#If the filing doesn't have the cik in it, it's bogus - we'll delete it and get the update on the next fetch
		print LOG "$id missing cik $cik\n";
		$db->do("update filings set bad_header =1 where filing_id = $id");
		`rm ./$file`;
	}
	my @filerdivs =  $tree->find_by_attribute('id', 'filerDiv');
	foreach my $filerdiv (@filerdivs) {
		unless ($filerdiv->as_text =~ /$cik/) { 
			#This is not the div you're looking for
			next; 
		}
	#	print "##\n\n".$filerdiv->as_HTML."\n";
		my $values = {'filing_id'=>$id, 'cik'=>$cik, 'year'=>$year};
		my @results;
		foreach my $address ($filerdiv->find_by_attribute('class', 'mailer')) {
			$type = $address->as_text =~ /^Business/ ? 'business' : 'mail';
			my @address_parts = $address->find('span');
			@address_parts = grep { $_->as_trimmed_text ne 'NULL' } @address_parts;
			if (my $phone = $address_parts[$#address_parts]) {
				if ($phone->as_trimmed_text =~ /^([^a-df-su-wyz]+)$/i) {
					$values->{"$type\_phone"} = $1;
					pop @address_parts;
				}
				my $line1 = shift @address_parts;
				if ($line1) { 
					$values->{"$type\_street_1"} = $line1->as_text;
					my $citystate = pop(@address_parts);
					if ($citystate) {
						if ($citystate->as_trimmed_text =~ /^((.+?) )?(\S+) ([\S]+)$/) {
							($values->{"$type\_city"}, $values->{"$type\_state"},$values->{"$type\_zip"}) = ($2, $3, $4);
						} else {
							$values->{"$type\_state"} = $citystate->as_trimmed_text;
						}
						if (my $line2 = shift @address_parts ) { 
							$values->{"$type\_street_2"} = $line2->as_text;
						}	
						if ($values->{"$type\_street_2"} && ! $values->{"$type\_city"}) {
							$values->{"$type\_city"} = $values->{"$type\_street_2"};
							$values->{"$type\_street_2"} = undef;
						}
					}
				}
			}
			foreach my $part (@address_parts) {
				print LOG "$id extra parts: ".$part->as_text."\n";
				print LOG Data::Dumper::Dumper($values);
				print LOG $address->as_HTML."\n";
				print LOG "=================\n";
			}
			if ($values->{"$type\_street_1"} && ! $values->{"$type\_state"}) {
				print LOG "$id strange address:\n";
				print LOG Data::Dumper::Dumper($values);
				print LOG $address->as_HTML."\n";
				print LOG "=================\n";
			}
		}	

		if ($filerdiv->as_HTML =~ m|class="companyName">(.+?)( \([^\)]+\))? <|) {
			$values->{'conformed_name'} = HTML::Entities::decode_entities($1);
		}
		my $ident = $filerdiv->find_by_attribute('class', 'identInfo');
		my $regexes = { 
			'irs_number' => qr|IRS No.</acronym>: <strong>(\d+)</strong>|,
			'sic_code' => qr|SIC</acronym>: <b><a[^>]+>(\d+)</a>|,
			'state_of_incorporation' =>  qr|State of Incorp.: <strong>([^<]+)</strong>|, 
			'fiscal_year_end' => qr|Fiscal Year End: <strong>(\d+)</strong>|,
		};
		foreach my $key (keys(%$regexes)) {
			if ($ident->as_HTML =~ /$regexes->{$key}/) {
				$values->{$key} = HTML::Entities::decode_entities($1);
			}
		}
		
		push(@$filers, $values);
		my $sth2 = $db->prepare_cached("insert into filers (filer_id, filing_id, cik, irs_number, conformed_name, fiscal_year_end, sic_code, business_street_1, business_street_2, business_city, business_state, business_zip, mail_street_1, mail_street_2, mail_city, mail_state, mail_zip, business_phone, state_of_incorporation, year) values (NULL ". ", ?" x 19 .")") || die "$!";

		foreach my $key ('filing_id', 'cik', 'irs_number', 'conformed_name', 'fiscal_year_end', 'sic_code', 'business_street_1', 'business_street_2', 'business_city', 'business_state', 'business_zip', 'mail_street_1', 'mail_street_2', 'mail_city', 'mail_state', 'mail_zip', 'business_phone', 'state_of_incorporation', 'year') {
			push (@results, $values->{$key}) ;
		}
		$sth2->execute(@results);
		last;
	}
	$tree->delete();
	return $filers;
}

