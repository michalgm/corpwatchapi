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
    
#-----------------------------------   
# The purpose of this script is to repopulate the companies_* tables using the information that has been parsed from the filings. 
#-----------------------------------
 
require "./common.pl";
our @years_available;
#reset the tables so that we can repopulate them without duplicating data
my $time = time();
&cleanTables();
print "\n\t**".(time() - $time)."\n"; $time = time();
#
#insert the companies that we have info about from the SEC
#Also merge together some of the filers
&insertFilers();
print "\n\t**".(time() - $time)."\n"; $time = time();

#check if the subsidary companies are also filers or 
&matchRelationships();
print "\n\t**".(time() - $time)."\n"; $time = time();
&createRelationshipCompanies();
print "\n\t**".(time() - $time)."\n"; $time = time();
&insertRelationships();
print "\n\t**".(time() - $time)."\n"; $time = time();
&updateCompanyInfo();
print "\n\t**".(time() - $time)."\n"; $time = time();
&insertNamesAndLocations();
print "\n\t**".(time() - $time)."\n"; $time = time();
&calcTopParents();
print "\n\t**".(time() - $time)."\n"; $time = time();
&setupFilings();
print "\n\t**".(time() - $time)."\n"; $time = time();
exit;

#in case we need to restore cw_id_lookup from backup
#insert into cw_id_lookup select c.cw_id, c.company_name, c.cik, timestamp, null, country_code, subdiv_code, 'original' from edgarapi_live.cw_id_lookup c left join edgarapi_live.companies a on a.cw_id = c.cw_id  left join edgarapi_live.company_locations b on c.cw_id = b.cw_id group by c.cw_id, c.company_name, c.cik, country_code, subdiv_code

#clear out the tables and preparse for receiving new data

sub cleanTables() {
	#FIXME get rid of these - for testing only
#	$db->do("delete from companies");
#	$db->do("delete from cw_id_lookup where timestamp > '2009-07-10'");

	print "Updating cw_id_lookup...\n";
	#store the association of names and cw_ids so that the ids can be re-matched when the table is repopulated
	$db->do("alter table cw_id_lookup auto_increment=0");
	$db->do("insert ignore into cw_id_lookup (cw_id, company_name, cik, country_code, subdiv_code, source) select a.cw_id, b.company_name, a.cik, c.country_code, c.subdiv_code, 'companies' from companies a join company_names b using (cw_id) join company_locations c using (cw_id) where (b.source = 'cik_former_name' or b.source = 'filer_match_name' or b.source = 'relationships_clean_company') group by a.cw_id, b.company_name, a.cik, c.country_code, c.subdiv_code");
	print "Resetting tables...\n";
	$db->do("delete from companies");
	$db->do("delete from company_info");
	$db->do("alter table company_info auto_increment=0");
	my $num = $db->selectrow_arrayref("select max(cw_id) + 1 from cw_id_lookup")->[0];
	if ($num) {
		$db->do("alter table companies auto_increment=$num");
	}
	$db->do("delete from company_relations");
	$db->do("alter table company_relations auto_increment=0");
	$db->do("update relationships set cw_id = NULL, parent_cw_id = null, cik = null");
	$db->do("update filers set cw_id = NULL");
	#Repair table state, if we lft it in a bad state
	$db->do("alter table relationships add key cw_id (cw_id)");
	$db->do("alter table companies enable keys");
	$db->do("alter table relationships add key parent_cw_id (parent_cw_id)");
	$db->do("delete from company_names");
	$db->do("alter table company_names auto_increment=0");
	$db->do("delete from company_locations");
	$db->do("alter table company_locations auto_increment=0");
	$db->do("delete from filings_lookup");
	$db->do("delete from company_filings");
	$db->do("optimize table filings");
	$db->do("optimize table filers");
	$db->do("optimize table cw_id_lookup");
	$db->do("optimize table cik_name_lookup");
	$db->do("optimize table relationships");
}

#The filers are the companies that we have at least some info from the SEC about, not just 10-k filers
sub insertFilers() {

	print "Inserting Filers...\n";

	# fill in cw_ids for filers from cw_id_lookup
	$db->do("update filers a join cw_id_lookup b on a.cik = b.cik set a.cw_id = b.cw_id where a.cik is not null");
	# This does nothing: $db->do("update filers a join cw_id_lookup b on company_name = match_name and a.cik is null and b.cik is null set a.cw_id = b.cw_id");
	# ---- make company entries for each of the filers ----
	$db->do("insert into companies (cw_id, row_id, cik, company_name, source_type, source_id) select cw_id, cw_id, cik, match_name, 'filers', filer_id from filers where cik is not null group by cik");
	$db->do("update companies set cw_id = row_id where cw_id is null");
	#re-update cw_id_lookup to enter new cw_ids from filers we just added
	$db->do("insert ignore into cw_id_lookup (cw_id, company_name, cik, country_code, subdiv_code, source) select a.cw_id, a.company_name, a.cik, incorp_country_code, incorp_subdiv_code, 'filers' from companies a join filers b using (cik) group by a.cw_id, a.company_name, a.cik, b.incorp_country_code, b.incorp_subdiv_code");
	$db->do("update filers a join cw_id_lookup b on a.cik = b.cik set a.cw_id = b.cw_id where a.cw_id is null");

	#TODO: need to collapse dupes, using irs id? Or collapse some of the match_name dupes?

}

#this section processes the companies that we have scraped out of the filer's section 21 filings, in many cases we don't have SEC info
sub matchRelationships() {
	#$db->do("update relationships a join cw_id_lookup b on a.cik = b.cik and a.cik is not null and a.cw_id is null set a.cw_id = b.cw_id");
	$db->do("update relationships a join cw_id_lookup b on clean_company = b.company_name and (a.subdiv_code = b.subdiv_code or (a.subdiv_code is null and b.subdiv_code = '')) and (a.country_code = b.country_code or a.country_code is null and b.country_code = '') and a.cik is null and b.cik = 0 and a.cw_id is null and b.country_code != '' set a.cw_id = b.cw_id");
	#----- create companies for the relationship companies -------
	#try to assign CIKs to relationship companies
	#WARNING: SOME NAMES HAVE MULTIPLE CIKs, and some CIKs have multiple names
	print "-----Matching relationship companies...\n";
	print "\tChecking against parent companies...\n";
	#TODO: WHY DO WE PRINT THIS OUT IF WE NOT ACTUALLY DOING THE MATCHING?
	#match cases where relationship company matches with filers name,cik, and location, these will be discarded later
	#$db->do("update relationships a join filers c on a.filing_id = c.filer_id and a.clean_company = c.match_name and a.country_code = c.incorp_country_code and (a.subdiv_code = c.incorp_subdiv_code or (a.subdiv_code is null and c.incorp_subdiv_code is null)) set a.cw_id = c.cw_id where a.cw_id is null and c.cw_id is not null");

	print "\tChecking against parent companies with no location...\n";
	#also tag the cases where filer has no location
	#$db->do("update relationships a join filers c on a.filing_id = c.filer_id and a.clean_company = c.match_name and c.incorp_country_code is null set a.cw_id=c.cw_id where a.cw_id is null");

	#this query gives a list of companies that we didn't match to parents, but maybe we should have if a human could verify:
	#select a.company_name,c.conformed_name,a.country_code,a.subdiv_code,c.incorp_country_code,c.incorp_subdiv_code,c.business_state from relationships a join filings b on a.filing_id = b.filing_id and b.has_sec21 =1 and a.cik is null join filers c on b.cik = c.cik and a.clean_company = c.match_name 
	# This query finds relationship companies that match to their filer on name and year, but nt on location and sets their cik to -1 - maybe someday we should enable this for human-review
	#$db->do("update relationships a join filers c on a.filer_cik = c.cik and a.year = c.year and a.clean_company = c.match_name and a.cik is null set a.cik = -1");

	# exact match against filers, assuming they are more recent, less dupes, and have locations to match  against
	print "\tMatching relationship companies against filers (some filers are confuseable on match_name)..\n";
	#chose randomly between filers with the same match name
	$db->do("update relationships a use index (clean_company) join filers b on clean_company = match_name and a.country_code = b.incorp_country_code and (a.subdiv_code = b.incorp_subdiv_code or (a.subdiv_code is null and b.incorp_subdiv_code is null)) and a.cw_id is null and a.year = b.year and b.cw_id is not null set a.cw_id = b.cw_id");
	#$db->do("update relationships a join filers b on clean_company = match_name and a.country_code = b.incorp_country_code and a.subdiv_code = b.incorp_subdiv_code and a.cik is null set a.cik = b.cik");

	#then exact match the relationship companies against the master list of EDGAR CIK names to see if we can assign any ciks that way
	#WARNING:  SOME MATCH AGAINST MULTIPLE NAMES, CIK CHOSEN RANDOMLY
	$db->do("update relationships a join cik_name_lookup b on clean_company = match_name and a.cw_id is null set a.cik = b.cik");
	#Fill in cw_ids for relationships from cw_id_lookup
	#this makes sure we re-establish the same cw_id if we had previously parsed it
	$db->do("update relationships a join cw_id_lookup b on a.cik = b.cik and a.cik is not null and a.cw_id is null set a.cw_id = b.cw_id");
	$db->do("update relationships a join cw_id_lookup b on a.cw_id = b.cw_id and a.cik is null and a.cw_id is not null set a.cik = b.cik");
	#insert relationship companies that were just matched from cw_id_lookup into the companies table (if they don't already exist)
	$db->do("insert ignore into companies (cik, row_id, company_name, source_type, source_id) select a.cik, cw_id, clean_company, 'relationships', relationship_id from relationships a where a.cw_id is not null group by a.cw_id");
}

sub createRelationshipCompanies() {
	#fuzzy matcch company names. 
	#resolve dupes on relationship companies
	print "creating relationship companies...\n";
	my $sth = $db->prepare("select cik, clean_company, relationship_id, country_code, subdiv_code from relationships where relationships.cw_id is null group by clean_company, country_code, subdiv_code");
	$sth->execute();
	#$db->do("alter table relationships drop key cw_id");
	$db->do("alter table companies disable keys");
	my $inserted_companies;

	my $date = $db->selectrow_arrayref("select NOW()")->[0];
	while (my $relate = $sth->fetchrow_hashref()) {
		my $existing_cw_id;
		#my $sth2 = $db->prepare_cached("select row_id from companies where company_name = ? and source_type = 'relationships' limit 1");
		#$sth2->execute($relate->{clean_company});
		#if ($inserted_companies->{uc($relate->{clean_company})}) {
		#	$existing_cw_id = $inserted_companies->{uc($relate->{clean_company})};
		#} else {
		#print "$relate->{cik}, $relate->{clean_company}, $relate->{relationship_id}\n";
			$db->prepare_cached("insert into companies (cik, company_name, source_type, source_id) values (?,?,'relationships',?)")->execute($relate->{cik}, $relate->{clean_company}, $relate->{relationship_id});
			$existing_cw_id = $db->last_insert_id(undef, 'edgarapi', 'companies', 'row_id');	
			#$inserted_companies->{uc($relate->{clean_company})} = $existing_cw_id;
			#Replace NULLs
			unless ($relate->{subdiv_code}) {$relate->{subdiv_code} = ''; }
			unless ($relate->{cik}) {$relate->{cik} = ''; }
			$db->prepare_cached("insert into cw_id_lookup (cw_id, company_name, cik, country_code, subdiv_code, source, timestamp) value (?, ?, ?, ?, ?, 'relationships', '$date')")->execute("$existing_cw_id",$relate->{clean_company}, $relate->{cik}, $relate->{country_code}, $relate->{subdiv_code}); 
		#}
		#print "$relate->{relationship_id} : $existing_cw_id\n";
		#$sth2->finish;
		#$db->prepare_cached("update relationships set cw_id = ? where relationship_id = ?")->execute("cw_".$existing_cw_id, $relate->{relationship_id});
	}
	#$db->do("insert into companies (row_id, cik, company_name, source_type, source_id) select null, cik, clean_company, 'relationships', relationship_id from relationships left join companies using (cik) where companies.cik is null group by clean_company,country_code,subdiv_code, cik");
	#$db->do("alter table relationships add key cw_id (cw_id)");
	$db->do("update companies set cw_id = row_id where cw_id is null or cw_id = ''");
	$db->do("alter table companies enable keys");
	$db->do("update relationships a join companies b using (cik) set a.cw_id = b.cw_id where a.cw_id is null and b.cik is not null");
	$db->do("update relationships a join cw_id_lookup b on clean_company = b.company_name and a.country_code = b.country_code and (a.subdiv_code = b.subdiv_code or (a.subdiv_code is null and b.subdiv_code = '')) set a.cw_id = b.cw_id where a.cw_id is null and b.source = 'relationships'");
}

sub insertRelationships() {
	# --- PUT THE RELATIONS IN THE COMPANY RELATIONS TABLE -------
	print "Setting up hierarchies...\n";
	$db->do("alter table relationships drop key parent_cw_id");
	$db->do("update relationships set hierarchy = 0 where hierarchy is null");
	my $filings = $db->selectall_arrayref('select filing_id from relationships group by filing_id having min(hierarchy) != max(hierarchy)');
	foreach my $filing (@$filings) {
		my ($filing_id) = @$filing;
		#print "$filing_id\n";
		my $relates = $db->selectall_arrayref("select cw_id, hierarchy from relationships where filing_id = '$filing_id' order by relationship_id");
		my $parents = [{hierarchy=>0, id=>0}];
		my $level = 0;
		foreach my $relate (@$relates) {
			my ($cw_id, $hierarchy) = @$relate;
			unless ($hierarchy) { 
				$hierarchy = 0; 
			}
			if ($hierarchy > $parents->[$level]->{'hierarchy'}) {
				$level++;
			} elsif ($hierarchy <= $parents->[$level]->{'hierarchy'}) {
				while ($hierarchy < $parents->[$level]->{'hierarchy'} && $level > 0) {
					$level--;
				}
			}
			$parents->[$level] = {id=>$cw_id, hierarchy=>$hierarchy};
			my $parent_id = $parents->[$level-1]->{id};
			if ($level == 0) { $parent_id = 0; } 
			if ($parent_id ne $cw_id && $parent_id ne 0) {	
				my $sth = $db->prepare_cached("update relationships set parent_cw_id = ? where cw_id = ? and filing_id = '$filing_id'");
				#print "\t$cw_id: $parent_id\n";
				$sth->execute($parent_id, $cw_id) || die "this died";
			}
		}
	}

	# Give relationships that have no parent_cw_id the cw_id of the filer as the parent
	$db->do("update relationships a join filings b using (filing_id) join companies c on b.cik = c.cik set parent_cw_id = c.cw_id where (parent_cw_id is null or parent_cw_id = '0' and b.cik is not null)");
	$db->do("alter table relationships add key parent_cw_id (parent_cw_id)");

	# Insert relationship into company_relations table, ignoring dupes
	print "inserting relationships...\n";
	$db->do("insert into company_relations (relation_id, source_cw_id, target_cw_id, relation_origin, origin_id, year) select null,parent_cw_id, cw_id, 'relationships', relationship_id, year from relationships where cw_id != parent_cw_id group by cw_id, parent_cw_id, year");


}


sub updateCompanyInfo() {
	#populate company_info
	print "populating company_info\n";
	$db->do("delete from company_info");
	$db->do("alter table company_info auto_increment=0");
	#$db->do("insert into company_info (cw_id, year) select * from (select target_cw_id, year from company_relations group by target_cw_id, year) a union distinct select * from (select a.cw_id, a.year from filers a join filings using (filing_id) where has_sec21 = 1 group by a.cw_id, a.year) b");
	#hopefully disabling keys for this section will speed thing up a bit
	$db->do("alter table company_info disable keys");
	$db->do("insert into company_info (cw_id, year) select * from (select target_cw_id, year from company_relations group by target_cw_id, year) a union distinct select * from (select a.cw_id, a.year from filers a where cw_id is not null group by a.cw_id, a.year ) b");

	print "updating company meta data...\n";

	#First enter filer meta data
	$db->do("update company_info a join (select cik, match_name, max(irs_number) as irs_number, max(sic_code) as sic_code, 'filers' as source_type, filer_id as source_id, year, cw_id from filers group by cw_id, year) b on a.year = b.year and a.cw_id = b.cw_id set a.cik = b.cik, a.irs_number = b.irs_number, a.sic_code = b.sic_code, a.source_type = b.source_type, a.source_id = b.source_id, company_name = match_name");
	#And now relationships meta data
	$db->do("update company_info a join (select cik, clean_company, 'relationships' as source_type, relationship_id as source_id, year, cw_id from relationships group by cw_id, year) b on a.year = b.year and a.cw_id = b.cw_id set a.cik = b.cik, a.source_type = b.source_type, a.source_id = b.source_id, company_name = clean_company where company_name is null");

		#TODO: copy the attribute info for each company into the company info table for each year
	# update the companies table with the counts of parents and children
	#TODO: needs to be done for each year

	$db->do("update company_info a, (select a.cw_id,
	 count(distinct parents.source_cw_id) num_parents ,count(distinct kids.target_cw_id) num_children , a.year
	from company_info a
	left join company_relations kids on a.cw_id = kids.source_cw_id and a.year = kids.year
	left join company_relations parents on a.cw_id = parents.target_cw_id and a.year = parents.year
	group by a.cw_id, a.year) relcount
	set a.num_parents = relcount.num_parents,
	a.num_children = relcount.num_children
	where a.cw_id = relcount.cw_id and a.year = relcount.year");

	#$db->do("update companies, (select companies.cw_id,
	# count(distinct parents.source_cw_id) num_parents ,count(distinct kids.target_cw_id) num_children 
	#from companies
	#left join company_relations kids on companies.cw_id = kids.source_cw_id
	#left join company_relations parents on companies.cw_id = parents.target_cw_id
	#group by companies.cw_id) relcount
	#set companies.num_parents = relcount.num_parents,
	#companies.num_children = relcount.num_children
	#where companies.cw_id = relcount.cw_id");

	#fill in the sic hierarchy where we have sic codes
	$db->do("update company_info, (select row_id,a.sic_code, sic_codes.industry_name, sic_sectors.sic_sector, sic_sectors.sector_name from company_info a join sic_codes on a.sic_code=sic_codes.sic_code join sic_sectors on sic_codes.sic_sector = sic_sectors.sic_sector) sic set company_info.industry_name = sic.industry_name, company_info.sic_sector = sic.sic_sector, company_info.sector_name = sic.sector_name where company_info.row_id = sic.row_id");

	#Update the most and least recent years fields
	$db->do("update company_info a join (select max(year) as myear, min(year) as lyear, cw_id from company_info b group by cw_id) b using (cw_id) set a.max_year = b.myear, a.min_year = b.lyear, most_recent = if(b.myear = a.year, 1, 0)");
	$db->do("alter table company_info enable keys");
}

sub insertNamesAndLocations() {
	print "cleaning names and locations...\n";
	$db->do("delete from company_names");
	$db->do("alter table company_names auto_increment=0");
	$db->do("delete from company_locations");
	$db->do("alter table company_locations auto_increment=0");
	$db->do("alter table company_names disable keys");
	$db->do("alter table company_locations disable keys");

	print "inserting names and locations...\n";
		#put the match names of the filers in the names table
	#TODO: shouldn't this grou pby both cik and match name, to deal with cases where match names has changed over the time period?
	print "\tFiler companies\n";
	$db->do("insert into company_names (name_id, cw_id, company_name, date, source, source_row_id, country_code, subdiv_code, min_year, max_year) select null,filers.cw_id, match_name, min(filing_date), 'filer_match_name', filer_id, incorp_country_code, incorp_subdiv_code, min(year(filing_date)), max(year(filing_date)) from filers join filings using (filing_id) join company_info on filers.cik = company_info.cik and company_info.year = filers.year and source_type= 'filers' group by filers.cw_id, match_name"); 

	#put in  the edgar "conformed" name if it is differnt from the match_name
	$db->do("insert into company_names (name_id, cw_id, company_name, date, source, source_row_id, country_code, subdiv_code, min_year, max_year) select null,filers.cw_id, conformed_name, min(filing_date), 'filer_conformed_name', filer_id, incorp_country_code, incorp_subdiv_code, year(min(filing_date)), year(max(filing_date)) from filers join filings using (filing_id) join company_info on filers.cik = company_info.cik and company_info.year = filers.year and source_type= 'filers' where conformed_name != match_name group by filers.cw_id, conformed_name"); 

	#insert cw_ids into cik_name_lookup 
	$db->do("update cik_name_lookup a join companies b  using (cik) set a.cw_id = b.cw_id where a.cw_id is null");
	#if we are using the html forms as the source, we won't have former names of filers.  So instead, get them from the cik_name_lookup.  Only problem is that we don't have the name change date :-(
	$db->do("insert into company_names (name_id, cw_id, company_name, date, source, source_row_id, min_year, max_year) select null,cw_id,cik_name_lookup.match_name,null as date,'cik_former_name',cik_name_lookup.row_id, min(company_info.year), max(company_info.year) from company_names join company_info using (cw_id) join cik_name_lookup using (cw_id) where source = 'filer_match_name' and company_names.company_name != cik_name_lookup.match_name and company_info.year between company_names.min_year and company_names.max_year group by cw_id,match_name");

	#now process the locations of the filers

	print "Inserting Filer Location and SIC info...\n";
	#/* put the biz address, mail address, and name state suffix in locations with id*/
  #TODO: only store locations that are differnt?  When locations are the same except date, just store the oldest date?
	$db->do('insert into company_locations (location_id, cw_id, date, type, raw_address, street_1, street_2, city, state, postal_code, max_year, min_year) select null,company_info.cw_id,filing_date,"business",business_raw_address raw, business_street_1, business_street_2,business_city,business_state,business_zip, max(filings.year), min(filings.year) from filers join company_info using (cw_id, year) join filings using (filing_id) where business_street_1 is not null group by company_info.cw_id, business_raw_address');
	$db->do('insert into company_locations (location_id, cw_id, date, type, raw_address, street_1, street_2, city, state, postal_code, max_year, min_year) select null,company_info.cw_id,filing_date,"mailing",mail_raw_address raw, mail_street_1, mail_street_2,mail_city,mail_state,mail_zip, max(filings.year), min(filings.year)  from filers join company_info using (cw_id, year) join filings using (filing_id) where mail_street_1 is not null group by company_info.cw_id, mail_raw_address');

#add in locations for the state of incorporation of filers.  This query maybe not quite correct, as info was scraped, not from filings?
    $db->do('insert into company_locations (location_id, cw_id, date, type, raw_address, country_code, subdiv_code, max_year, min_year) select null,company_info.cw_id,filing_date,"state_of_incorp",state_of_incorporation raw, incorp_country_code,incorp_subdiv_code, max(filings.year), min(filings.year)  from filers join company_info using (cik, year) join filings using (filing_id) where state_of_incorporation is not null group by company_info.cw_id, raw');

	print "\tRelatation companies\n";
	#put those names into the names table
	$db->do("insert into company_names (name_id, cw_id, company_name, date, source, source_row_id, country_code, subdiv_code, min_year, max_year) select null,b.cw_id, a.company_name, filing_date, 'relationships_company_name', relationship_id, country_code, subdiv_code, min(year(filing_date)), max(year(filing_date)) from relationships a join company_info b on b.cw_id = a.cw_id join filings c using(filing_id) where b.source_type = 'relationships' group by b.cw_id, a.company_name collate 'utf8_bin'");
   #if the original name is differnt than the clean name, put that in. 
	$db->do("insert into company_names (name_id, cw_id, company_name, date, source, source_row_id, country_code, subdiv_code, min_year, max_year) select null,b.cw_id, clean_company, filing_date, 'relationships_clean_company', relationship_id, country_code, subdiv_code, min(year(filing_date)), max(year(filing_date))  from relationships a join company_info b on b.cw_id = a.cw_id join filings c using(filing_id) where b.source_type = 'relationships' and a.company_name collate 'utf8_bin' != clean_company collate 'utf8_bin' group by b.cw_id, clean_company collate 'utf8_bin'");

	#put the relationships' locations that have been sucessfully tagged into the locations table
	$db->do("insert into company_locations (location_id,cw_id,date,type,raw_address,country_code,subdiv_code, max_year, min_year) select null,a.cw_id,filing_date,'relation_loc',location, country_code,subdiv_code, max(filings.year), min(filings.year) from company_info a join relationships on source_type = 'relationships' and a.cw_id = relationships.cw_id and location is not null join filings using (filing_id) group by a.cw_id, subdiv_code, country_code");

	$db->do("alter table company_names enable keys");
	$db->do("alter table company_locations enable keys");

	#/* fill in un country and subdiv codes o the filers where possible */
	#TODO; this should now be done in clean relationships script
	$db->do("update company_locations join region_codes on company_locations.state = region_codes.code set company_locations.country_code = region_codes.country_code, company_locations.subdiv_code = region_codes.subdiv_code");



	# --- FIGURE OUT WHAT THE BEST (MOST COMPLETE) ADDRESS INFO IS
	#first choice is business address, but if that is null, using mailing, if that is null, use the location with both country and state, if that is null use whatever is left. 
	for my $year (@years_available) { 
		$db->do("update company_info join
			(
				select cw_id,  
					if (max(biz_loc) is not null, max(biz_loc), 
						if (max(mail_loc) is not null,max(mail_loc),  
							if (max(rel_loc) is not null, max(rel_loc), 
								if (max(s_rel_loc) is not null, max(s_rel_loc), max(incorp_loc)
								)	 
							) 
						)
					) best_id 
				from  
				(select cw_id,if ((type = 'business' and street_1 is not null),location_id,null) biz_loc,  
					if ((type = 'mailing' and street_1 is not null),location_id,null) mail_loc, 
					if ((type = 'relation_loc' and subdiv_code is not null),location_id,null) rel_loc, 
					if ((type = 'relation_loc'),location_id,null) s_rel_loc, 
					if ((type = 'state_of_incorp' and country_code is not null),location_id,null) incorp_loc
					from company_locations where $year between min_year and max_year 
				) merged group by cw_id 
			) best_loc 
			using (cw_id) 
			set company_info.best_location_id = best_loc.best_id
			where company_info.year = $year	
		");
	}
	$db->do("update company_info a join company_locations b on best_location_id = location_id join company_locations c on a.cw_id = c.cw_id set a.best_location_id = c.location_id where b.country_code is null and c.country_code is not null");

	#Give all companies without locations a common 'No Location' best_location_id - this will avoid left joins in the api
	$db->do("insert into company_locations (location_id,cw_id,date,type,raw_address,country_code,subdiv_code, max_year, min_year) select null,null,null,'null location','No location available', null,null, $years_available[$#years_available], $years_available[0]");
	$null_location_id = $db->last_insert_id(undef, 'edgarapi', 'company_locations', 'row_id');	
	$db->do("update company_info set best_location_id = $null_location_id where best_location_id is null");

	#Set the most_recent flags
	$db->do("update company_names a join company_info b using (cw_id) set a.most_recent = 1 where a.max_year = b.year");	
	$db->do("update company_locations a join company_info b using (cw_id) set a.most_recent = 1 where a.max_year = b.year");	

	#Update cw_id_lookup with all names and locations
	$db->do("insert ignore into cw_id_lookup (cw_id, company_name, cik, country_code, subdiv_code, source) select a.cw_id, b.company_name, a.cik, c.country_code, c.subdiv_code, 'alt names/locations' from companies a join company_names b using (cw_id) join company_locations c using (cw_id) where (b.source = 'cik_former_name' or b.source = 'filer_match_name' or b.source = 'relationships_clean_company') group by a.cw_id, b.company_name, a.cik, c.country_code, c.subdiv_code");

	$db->do("update cw_id_lookup b set b.orphaned = 0 where b.orphaned != 0");
	$db->do("update cw_id_lookup b left join companies a using(cw_id) set b.orphaned = 1 where a.row_id is null");
}


#pre calculate the "topmost" parent relationship for each company
sub calcTopParents() {
	print "calculating topmost parent for each company\n";
	#set the top parent of each company to itself and record number of rows updated
    $prev_updated = $db->do("update company_info set top_parent_id = cw_id");
    $num_updated = 0;
    #repeat until the number of rows updated stops changing (indicating that we are in a loop
    $step = 0; #track so we don't do more than 100
    while ($step < 100){
   		 $num_updated = $db->do("update company_info a join company_relations b on b.target_cw_id = a.top_parent_id and a.year = b.year set top_parent_id = b.source_cw_id where target_cw_id != source_cw_id");
		
		print "$num_updated == $prev_updated\n";
		if ($num_updated == $prev_updated){
			last; #our work here is done
		}
		$prev_updated = $num_updated; 
		$step++;
		
		#debug
		print (" top parents updated $num_updated companies at step $step\n");
    
    }

	#Override any interlocking top-parent relationships to use one companies cw_id as both's top parent (and do the same for the children)
	$db->do("update company_info a join company_info b on a.top_parent_id = b.cw_id and b.top_parent_id = a.cw_id and a.cw_id > b.cw_id and a.year = b.year join company_info c on c.top_parent_id = b.cw_id and c.year = b.year set a.top_parent_id = a.cw_id, c.top_parent_id = a.cw_id");
	#Remove the child relationship of any company list as top_parent
	$db->do("delete from b using company_info a join company_relations b on a.top_parent_id = b.target_cw_id and a.year = b.year");
}

sub setupFilings() {
	$db->do("delete from filings_lookup");
	$db->do("delete from company_filings");
	$db->do("insert into filings_lookup select a.cw_id, b.filing_id, 1 from filers a join filings b using(cik) where type like '10-K%' group by b.filing_id, a.cw_id");
	$db->do("insert ignore into filings_lookup select cw_id, filing_id, 0 from relationships where cw_id != parent_cw_id");
	$db->do("insert into company_filings select a.filing_id, a.cik, a.year, a.quarter, period_of_report, filing_date, concat('http://www.sec.gov/Archives/',filename) as form_10k_url, sec_21_url  from filings a join filings_lookup using(filing_id) group by filing_id");
}
exit;

#$db->do("insert into company_relations (relation_id, source_cw_id, target_cw_id, relation_origin, origin_id) select null, c.cw_id, d.cw_id, 'relationships', a.relationship_id from relationships a join filings b using (filing_id) join companies c on b.cik = c.cik join companies d on a.cik = d.cik and a.cik is not null where c.cw_id != d.cw_id group by c.cw_id,d.cw_id");

#insert the rest of the relationships, matching against the clean company name
#make sure not to insert relations that have already been inserted
#TODO:  THIS QUERY IS WRONG, INSERTS TOO MANY COMPANIES!
#$db->do("insert into company_relations (relation_id, source_cw_id, target_cw_id, relation_origin, origin_id) select null,c.cw_id, d.cw_id, 'relationships', a.relationship_id from relationships a join filings b using (filing_id) join companies c on b.cik = c.cik join companies d on a.clean_company = d.company_name left join company_relations e on origin_id = relationship_id and relation_origin = 'relationships' where c.cw_id != d.cw_id and e.origin_id is null group by c.cw_id,d.cw_id");



# ------ SUBROUTINE FOR MATCHING RELATIONSHIP LOCATIONS ---

__END__;

#everything below is not run, notes  and cruft included here for reference
/* add locations to company names */

/* collapse all redundant company names entries */

/* put the stripped-off locations from the company names as locations also */

insert into company_locations select null,cw_id,filing_date,"name_state", null,null,null,null, (CASE
WHEN conformed_name like "%/__/"  THEN left(right(conformed_name,3),2)
WHEN conformed_name like "%\\\__\\"  THEN left(right(conformed_name, 3),2)
WHEN conformed_name like "%/__" THEN right(conformed_name, 2)
ELSE null
END) as state,null,null,null,null from filers join companies using (cik) join filings using (filing_id)  having state is not null;
