#!/usr/bin/perl
use HTML::TreeBuilder;
use Data::Dumper;
use Parallel::ForkManager;
require './common.pl';

$db->do("delete from filers");
$db->do("alter table filers auto_increment= 0");
my $filing_id = $ARGV[0];
#my $file = "data/2008/1/68065.hdr"; 
#my $cik = "0001156491";
$db->disconnect;
$manager = new Parallel::ForkManager( 5 );
$manager->run_on_finish(
	sub { 
		my ($pid, $code, $ident) = @_; 
		if ($code == 20) {
			$manager->wait_all_children;
			exit;
		}
	}
);

if ($filing_id) { 
	chomp($filing_id);
	*LOG = *STDOUT; 
} else {
	open (LOG, '>parse_headers.log');
}
foreach my $year (2008) {
	foreach my $q (1 .. 4) {
		my $dir = "$datadir/$year/$q/" || die("can't open $dir");
		opendir(DIR, $dir);
		my @files = readdir(DIR);
		closedir(DIR);
		my $total = $#files;
		my $set_size = int($total * .01);
		$limit = int($total / $set_size * .01);
		my ($x, $y) = 0;
		print "Parsing $year Q $q\n";
		for my $set (0 .. int($total/$set_size)+1) { 
			if ($x == $limit) { $y++; print "\r\t".($y)."%  "; $x = 0; } $x++;
			my $pid = $manager->start and next;
			$db = &dbconnect();
			for my $count (1 .. $set_size) {
				$count += ($set * $set_size);
				if ($count > $total) { $manager->finish; }
				my $file = @files[$count];
				if ($file =~ /^(\d+)\.hdr$/) {
					my $id = $1;
					unless ($filing_id && $id != $filing_id) {
						unless (my $filers = &parse_filers("$dir/$file", $id)) {
							print LOG "$id didn't parse\n";
						}
						if ($filing_id) { 
							$filing_id = 20;
							last;
						}
					}
				}
			}
			#if ($filing_id eq 'imdone') { print 'BAILING!!!!'; $manager->wait_all_children; exit; }
			$manager->finish($filing_id);
			print "\n";
		}
		$manager->wait_all_children;
	}
}

sub parse_filers() {
	my ($file, $id) = @_;
	my $filers;
	my $sth = $db->prepare_cached('select cik from filings where filing_id = ?');
	$sth->execute($id);
	my $cik = $sth->fetchrow_arrayref()->[0];
	$sth->finish;
	#print "$file - $id - $cik\n";
	my $tree = HTML::TreeBuilder->new_from_file($file);
	my @filerdivs =  $tree->find_by_attribute('id', 'filerDiv');
	foreach my $filerdiv (@filerdivs) {
		unless ($filerdiv->as_text =~ /$cik/) { next; }
	#	print "##\n\n".$filerdiv->as_HTML."\n";
		my $values = {'filing_id'=>$id, 'cik'=>$cik};
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
		my $sth2 = $db->prepare_cached("insert into filers (filer_id, filing_id, cik, irs_number, conformed_name, fiscal_year_end, sic_code, business_street_1, business_street_2, business_city, business_state, business_zip, mail_street_1, mail_street_2, mail_city, mail_state, mail_zip, business_phone, state_of_incorporation) values (NULL ". ", ?" x 18 .")") || die "$!";

		foreach my $key ('filing_id', 'cik', 'irs_number', 'conformed_name', 'fiscal_year_end', 'sic_code', 'business_street_1', 'business_street_2', 'business_city', 'business_state', 'business_zip', 'mail_street_1', 'mail_street_2', 'mail_city', 'mail_state', 'mail_zip', 'business_phone', 'state_of_incorporation') {
			push (@results, $values->{$key}) ;
		}
		$sth2->execute(@results);
	}
	$tree->delete();
	return $filers;
}

