#!/usr/bin/perl -w
use utf8;
use Text::Unidecode;

require "./common.pl";
$| = 1;
our $db;
$db->{mysql_enable_utf8} = 1;

#my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships where company_name rlike "[^[:alnum:] ,\.\(\)[.hyphen.]&@\/\\%!\'\*\:\+~]"');
print "Cleaning databases...\n";
$db->do("update relationships set clean_company = ''");
$db->do("update relationships set cik = null");
$db->do("update cik_name_lookup set match_name = ''");
$db->do("update relationships a join un_countries b on company_name = country_name set company_name = location, location = country_name");
$db->do("update relationships a join un_country_aliases b on company_name = country_name set company_name = location, location = country_name");
$db->do("update relationships a join un_country_subdivisions b on company_name = subdivision_name set company_name = location, location = subdivision_name");



my $sth = $db->prepare("update relationships set clean_company = ? where relationship_id = ?");
my $sth2 = $db->prepare("update cik_name_lookup set match_name = ? where row_id = ?");
my $sth3 = $db->prepare("update filers set match_name = ? where filer_id = ?");
#my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships where filing_id = 44202');
#my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships where company_name rlike "[^[:alnum:] ,\.\(\)[.hyphen.]&@\/\\%!\'\*\:\+~]" and relationship_id = 23818');

print "Cleaning relationships...\n";
my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships');
($x, $y) = 0;
$limit = int($#${relates}*.01);
foreach my $relate (@$relates) {
	my ($id, $company, $location) = @$relate;
    if ($x == $limit) { print "\r".++$y."%"; $x = 0; }
	$company = unidecode($company);
	$company = &clean_for_match($company);
	if ($company) { 
		$sth->execute($company, $id);
	}
	$x++;
}

print "\nCleaning edgar names...\n";
my $edgar_cos = $db->selectall_arrayref('select row_id, edgar_name from cik_name_lookup');
($x, $y) = 0;
$limit = int($#${edgar_cos}*.01);
foreach my $edgar_co (@$edgar_cos) {
	my ($id, $name) = @$edgar_co;
    if ($x == $limit) { print "\r".++$y."%"; $x = 0; }
	$name = &clean_for_match($name);
	if ($name) {
		$sth2->execute($name, $id);
	}
	$x++;
}

print "\nCleaning filer names...\n";
my $filers = $db->selectall_arrayref('select filer_id, conformed_name from filers');
($x, $y) = 0;
$limit = int($#${filers}*.01);
foreach my $filer (@$filers) {
	my ($id, $name) = @$filer;
    if ($x == $limit) { print "\r".++$y."%"; $x = 0; }
	$name = &clean_for_match($name);
	if ($name) {
		$sth3->execute($name, $id);
	}
	$x++;
}
print "Matching relationships...\n";
$db->do("update relationships a join cik_name_lookup b on clean_company = match_name  set a.cik = b.cik where clean_company !=''");

