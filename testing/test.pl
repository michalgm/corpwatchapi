require "../common.pl";
$| = 1;
our $db;
$db->{mysql_enable_utf8} = 1;

use LWP::UserAgent;
use Compress::Zlib;
use JSON;
use Data::Dumper;
use Test::More 'no_plan';
use Test::Differences;
$ua = LWP::UserAgent->new(keep_alive=>1);
my $json = new JSON;
$json->pretty(1);

my $localbase = 'http://nopants.primate.net/~dameat/edgarapi/';
my $remotebase = 'http://api.corpwatch.org/';

#	compare_new_to_old("companies/cw_444668");
#	exit;



my @cw_ids = fetch_cw_ids(400, 'where num_children != 0' );
foreach (@cw_ids) { 
	compare_children_to_standalone($_);
	next;
	check_relations($_, 1);
	check_most_recent($_);
	compare_new_to_old("companies/$_");
}	
#$json = from_json($res->content());
#print Data::Dumper::Dumper($json);

sub compare_children_to_standalone() {
	my $cw_id = shift;
	my $company = get_company(fetch("$localbase/companies/$cw_id"));
	my $year = ($company->{min_year} .. $company->{max_year})[rand(int($company->{min_year} .. $company->{max_year}))];
	my $fetchchildren = fetch("$localbase/$year/companies/$cw_id/children");
	if ($fetchchildren) {
		my @children = values(%{fetch("$localbase/$year/companies/$cw_id/children")->{result}->{companies}});;
		foreach my $child (@children) {
			my $childco = get_company(fetch("$localbase/$year/companies/$child->{cw_id}"));
			eq_or_diff($child, $childco, "child v. standalon $child->{cw_id}");
		}
	}
}

sub check_relations() {
	my $cw_id = shift;
	my $children = shift;
	if ($children) { $children = 'children'; } else { $children = 'parents'; }
	my $num = get_company(fetch("$localbase/companies/$cw_id"))->{"num_$children"};
	my $results = fetch("$localbase/companies/$cw_id/$children");
	if($results) {
		my $found = $results->{meta}->{total_results};
		is ($num, $found, "$children $cw_id");
	}
}


sub check_most_recent() {
	my $cw_id = shift;
	my $company = get_company(fetch("$localbase/companies/$cw_id"));
	my $year = $company->{max_year};
	foreach my $type ('children', 'parents', 'names', 'locations', 'filings') { 
		my $static = fetch("$localbase/$year/companies/$cw_id/$type", 1);
		my $recent = fetch("$localbase/companies/$cw_id/$type", 1);
		$recent->{meta}->{parameters}->{year} = "$year";
		eq_or_diff($static, $recent, "most recent $cw_id $type");
	}
	return;
}

sub get_company() {
	my $obj = shift;
	return (values(%{$obj->{'result'}->{'companies'}}))[0];
}

sub compare_new_to_old() {
	my $resource = shift;
	my $local = fetch("$localbase/2008/$resource", 1);
	#print "$localbase/2008/$resource vs. $remotebase/$resource\n ";
	my $remote = fetch("$remotebase/$resource", 1);
	unless ($remote->{meta}->{total_results} != 0) { 
		$remote->{meta}->{total_results} = $local->{meta}->{total_results};
		$remote->{meta}->{results_complete} = $local->{meta}->{results_complete};
	}
	$remote->{meta}->{parameters}->{year} = "2008";
	$remote->{meta}->{status_string} = $local->{meta}->{status_string};
	if (ref $remote->{result} eq 'HASH') {
		foreach my $key (keys(%{$remote->{result}->{companies}})) {
			$remote->{result}->{companies}->{$key}->{sic_code} = $remote->{result}->{companies}->{$key}->{sic_category};
			delete $remote->{result}->{companies}->{$key}->{sic_category};
			$remote->{result}->{companies}->{$key}->{max_year} = $local->{result}->{companies}->{$key}->{max_year};
			$remote->{result}->{companies}->{$key}->{min_year} = $local->{result}->{companies}->{$key}->{min_year};
		}
	}
	#my $remote = fetch("$localbase/$resource");
	eq_or_diff($local, $remote, "new to old $resource");
}

sub fetch() {
	my $url = shift;
	my $allow_empty = shift;
	if ($url =~ /\?/) { 
		$url .= "&";
	} else { $url .= "?"; }
	$url .= "key=c855af7c49b35aef8710d7450eedb56e";
	$res = $ua->get("$url");
	#unless ($res->is_success) { die "Unable to fetch $url: $!"; }
	my $text = from_json(lc($res->content()));
	#my $text = $json->encode($json->decode($res->content()));
	#ddump($text);
	foreach my $part ('query', 'execution_time') {
		$text->{meta}->{$part} = undef
	}
	if ($text->{meta}->{total_results} == 0 && ! $allow_empty) { 
		#print $url;
		return; 
	}
	return $text;
}

sub fetch_cw_ids() {
	my $num = shift || 100;
	my $where = shift;
	my $res = $db->selectall_arrayref("select cw_id from company_info $where order by rand() limit $num");
	my @cw_ids;
	foreach (@$res) {
		push(@cw_ids, $_->[0]);
	}
	return @cw_ids;
}

sub ddump () {
	print Data::Dumper::Dumper(shift);
}
