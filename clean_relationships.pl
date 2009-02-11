#!/usr/bin/perl -w
use utf8;
use Text::Unidecode;

require "./common.pl";
$| = 1;
our $db;
$db->{mysql_enable_utf8} = 1;

#my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships where company_name rlike "[^[:alnum:] ,\.\(\)[.hyphen.]&@\/\\%!\'\*\:\+~]"');
print "Cleaning databases...\n";
#blank out matching fields if they have been set
$db->do("update relationships set clean_company = ''");
$db->do("update relationships set cik = null");
$db->do("update cik_name_lookup set match_name = ''");

#if we can identify that the "company name" is definitly a location (matches with location name) then swap "company name" and "location"
$db->do("update relationships a join un_countries b on company_name = country_name set company_name = location, location = country_name");
$db->do("update relationships a join un_country_aliases b on company_name = country_name set company_name = location, location = country_name");
$db->do("update relationships a join un_country_subdivisions b on company_name = subdivision_name set company_name = location, location = subdivision_name");


#set up prepared statments in the db to make things run faster
my $sth = $db->prepare("update relationships set clean_company = ? where relationship_id = ?");
my $sth2 = $db->prepare("update cik_name_lookup set match_name = ? where row_id = ?");
my $sth3 = $db->prepare("update filers set match_name = ? where filer_id = ?");
#my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships where filing_id = 44202');
#my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships where company_name rlike "[^[:alnum:] ,\.\(\)[.hyphen.]&@\/\\%!\'\*\:\+~]" and relationship_id = 23818');

#try to remove non-ascii characters and do some substitutions to try to put names in standard forms
print "Cleaning relationships...\n";
my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships');
($x, $y) = 0;
$limit = int($#${relates}*.01);
foreach my $relate (@$relates) {
	my ($id, $company, $location) = @$relate;
    if ($x == $limit) { print "\r".++$y."%"; $x = 0; }
    #translate unicode to closest equivilent ascii
	$company = unidecode($company);  
	#substitute, strip puncucation, try to follow the SEC conform spec
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
    #substitute, strip puncucation, try to follow the SEC conform spec
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
    #substitute, strip puncucation, try to follow the SEC conform spec
	$name = &clean_for_match($name);
	if ($name) {
		$sth3->execute($name, $id);
	}
	$x++;
}
print "Matching relationships...\n";

#match the relationship companies against the master list of EDGAR CIK names to see if we can assign any ciks that way
#WARNING:  SOME MATCH AGAINST MULTIPLE NAMES, CIK CHOSEN RANDOMLY
$db->do("update relationships a join cik_name_lookup b on clean_company = match_name  set a.cik = b.cik where clean_company !=''");

