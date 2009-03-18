#!/usr/bin/perl -w
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
#print "\tTagging reverse country codes...\n";
#$db->do("update relationships a join un_countries b on company_name = country_name set company_name = location, location = country_name");
#print "\tTagging reverse country alias codes...\n";
#$db->do("update relationships a join un_country_aliases b on company_name = country_name set company_name = location, location = country_name");
#print "\tTagging reverse subdivision codes...\n";
#$db->do("update relationships a join un_country_subdivisions b on company_name = subdivision_name set company_name = location, location = subdivision_name");

#process the relationships and attept to tag each one with a country and subdiv  for locationscode
#&match_relationships_locations();

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

#convert the filer EDGAR state codes into un country and subdiv codes
print "\nConverting Filer state of incorporation codes to un codes\n";
$db->do("update filers join region_codes on state_of_incorporation = code  set incorp_country_code = country_code, incorp_subdiv_code = subdiv_code where state_of_incorporation is not null");




sub match_relationships_locations() {
	#/* a) match all that have two capital letters, and are in the table of us state codes  */

	print "\tTagging US State codes\n";
	$db->do('update relationships, un_country_subdivisions set relationships.subdiv_code = subdivision_code, relationships.country_code = "US" where location=subdivision_code and un_country_subdivisions.country_code = "US"');

	#/* b) tag as DE all that contain the string "Delaware"  misses some multiply tagged locations  */

	print "\tTagging Delware\n";
	$db->do('update relationships set subdiv_code = "DE", country_code = "US" where location like "%Delaware%"');

	#/*  c) match all state names (including "Georgia", which can be confused) */

	print "\tTagging US States\n";
	$db->do('update relationships,un_country_subdivisions set relationships.country_code = un_country_subdivisions.country_code, relationships.subdiv_code = un_country_subdivisions.subdivision_code where relationships.location = subdivision_name and un_country_subdivisions.country_code = "US" and relationships.country_code is null');

	#/* d) match all country names that are not confuseable (exclude georgia) */

	print "\tTagging countries\n";
	$db->do('update relationships,un_countries set relationships.country_code = un_countries.country_code where relationships.location = country_name and country_name != "Georgia" and relationships.country_code is null');

	#/* e) match alaised variants "caymen" "US", "USA", "U.S.A", "United States of America" tag caymen island varients */

	print "\tTagging countries\n";
	$db->do('update relationships, un_country_aliases set relationships.country_code = un_country_aliases.country_code, relationships.subdiv_code = un_country_aliases.subdiv_code where location = country_name');

	#/* f)  match where location in formate  "City Name, CA"  */

	print "\tTagging cities in states\n";
	#$db->do('update relationships, un_country_subdivisions set relationships.country_code = "US", relationships.subdiv_code = right(location,2) where location like "%, __" and right(location,2) in (select subdivision_code from un_country_subdivisions where country_code = "US")');
	$db->do('update relationships a join un_country_subdivisions b on right(location,2) = b.subdivision_code and b.country_code = "US" set a.country_code = "US", a.subdiv_code = right(location,2) where location like "%, __"');

	# /* f) match canadian proviences */

	print "\tTagging canadian provinces\n";
	$db->do('update relationships, un_country_subdivisions set relationships.country_code = "CA", subdiv_code = un_country_subdivisions.subdivision_code where relationships.country_code is null and location = subdivision_name and location in (select subdivision_name from un_country_subdivisions where country_code = "CA")');

	print "\tTagging countries from city,country\n";
	$db->do('update relationships a join un_country_aliases b on SUBSTRING_INDEX(location, ", ",-1) = country_name set a.country_code = b.country_code, a.subdiv_code = b.subdiv_code where  a.location like "%, %" and a.country_code is null');

	print "\tTagging countries from city,state\n";
	$db->do('update relationships a join un_country_subdivisions b on SUBSTRING_INDEX(location, ", ",1) = subdivision_name set a.country_code = b.country_code, a.subdiv_code = b.subdivision_code where  a.location like "%, %" and a.country_code is null');

	$db->do('update relationships a join un_countries b on SUBSTRING_INDEX(location, ", ",-1) = country_name set a.country_code = b.country_code where  a.location like "%, %" and a.country_code is null');

	print "\tTagging countries from state,country\n";
	$db->do('update relationships a join un_country_subdivisions b on SUBSTRING_INDEX(location, ", ",-1) = subdivision_name set a.country_code = b.country_code, a.subdiv_code = b.subdivision_code where  a.location like "%, %" and a.country_code is null');

	# /* g) tag entries that are definitly not geographies  $, %, incorporated in */

	# /*  strip out "a % corporation" and retag countries and states? */

}
