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

#-----------------------------------------
#This script cleans the subsidiary relationships data that has been parsed from the 10-K Section 21 filings.  It also cleans the names in the filers and cik_name_lookup table.  The names of companies in each of the tables are normalized so that they can be matched, and the location codes are mapped to UN country codes where possible. 
#-----------------------------------------

require "./common.pl";
$| = 1;
our $db;
$db->{mysql_enable_utf8} = 1;
my $nuke = $ARGV[0];

#my $relates = $db->selectall_arrayref('select relationship_id, company_name, location from relationships where company_name rlike "[^[:alnum:] ,\.\(\)[.hyphen.]&@\/\\%!\'\*\:\+~]"');
print "Cleaning databases...\n";
#blank out matching fields if they have been set
#$db->do("update relationships set clean_company = ''");

#commenting out these steps for update
if ($nuke) {
	$db->do("update relationships set filer_cik = null, quarter = null, year = null, ");
	$db->do("update filers set incorp_country_code = null, incorp_subdiv_code = null");
}

#Fill in filer_cik, year and quarter on relationships from the original filer
$db->do("update relationships a join filings b using (filing_id) set a.filer_cik = b.cik, a.year = b.year, a.quarter = b.quarter where a.filer_cik is null");

print "Stripping out garbage strings\n";
my $strip_strings = $db->selectall_arrayref("select string from strip_company_strings");
foreach my $string (@$strip_strings) {
	$db->do("update relationships set company_name = replace(company_name, '$string->[0]', '')");
	$db->do("update relationships set clean_company = replace(clean_company, '$string->[0]', '')");
}
$db->do("delete from  relationships where company_name = '' or clean_company = ''");

#process the relationships and attept to tag each one with a country and subdiv  for locationscode
#&match_relationships_locations();

#Insert match names on filers
print "\nCleaning filer names...\n";
my $filers = $db->selectall_arrayref('select filer_id, conformed_name from filers where match_name is null');
my $count = 0;
my $total = $#${filers};
foreach my $filer (@$filers) {
	my ($id, $name) = @$filer;
	print "\r".int((++$count/$total)*100)."%";
    #substitute, strip puncucation, try to follow the SEC conform spec
	$name = &clean_for_match($name);
	if ($name) {
		my $sth = $db->prepare_cached("update filers set match_name = ? where filer_id = ?");
		$sth->execute($name, $id);
	}
}

#convert the filer EDGAR state codes into un country and subdiv codes
print "\nConverting Filer state of incorporation codes to un codes\n";
$db->do("update filers join region_codes on state_of_incorporation = code  set incorp_country_code = country_code, incorp_subdiv_code = subdiv_code where state_of_incorporation is not null");




sub match_relationships_locations() {
	#/* a) match all that have two capital letters, and are in the table of us state codes  */

	print "\tTagging US State codes\n";
	$db->do('update relationships join un_country_subdivisions on location = subdivision_code set relationships.subdiv_code = subdivision_code, relationships.country_code = "US" where un_country_subdivisions.country_code = "US"');

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
