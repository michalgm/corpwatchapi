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
    
#-----------------------------------   
# This script generates some HTML giving current stats on the database in terms of the numbers of companies parsed, etc.
#-----------------------------------

use CGI;
print CGI::header();
chdir "/home/dameat/edgarapi_live/backend/"; #This should be set to the full path of this script
require "./common.pl";
my $db = &dbconnect();
my $data;
print "<table><tr><th> </th>";
foreach my $year (@{$db->selectall_arrayref("select year from filings group by year")}) {
	$year = $year->[0];
print "<th>$year</th>";

my @queries = ( 
"select 'filing companies', count(*) from filers where year = $year",
"select 'filings w/ sec21', count(*)  from filings where has_sec21 =1 and year = $year",
"select 'filings with relationships parsed', count(distinct filing_id) from relationships join filings using(filing_id) where filings.year = $year",
"select 'percentage of filings parsed', num2/num1*100 from (select count(*) as num1 from filings a where has_sec21 =1  and year = $year) a  join (select  count(distinct filing_id) as num2 from relationships  join filings using(filing_id) where filings.year = $year) b",
"select 'filings with empty sec21', count(*) from filings a join no_relationship_filings using(filing_id) where code = 1 and year = $year",
"select 'percentage of true filings parsed', num2/(num1-num3)*100 from (select count(*) as num1 from filings a where has_sec21 =1 and year = $year) a  join (select  count(distinct filing_id) as num2 from relationships join filings using(filing_id) where filings.year = $year) b join (select count(*) as num3 from filings a join no_relationship_filings using(filing_id) where code = 1  and a.year = $year) c",
"select 'number of relationships', count(*) from relationships where year = $year",
#"select 'percentage of relationships w/ location', concat(num1/num2*100, ' ', num2-num1) from (select count(*) as num1 from relationships a where country_code is not null) a  join (select  count(*) as num2 from relationships) b",
"select 'number of companies', count(*) from company_info where year = $year",
"select 'number of company relationships', count(*) from company_relations where year = $year",
"select 'companies w/o parents or children' , count(distinct cw_id) from company_info a where num_children =0 and num_parents =0 and year = $year",
"select 'top-level companies', count(distinct cw_id) from company_info a left join company_relations b on cw_id = target_cw_id and a.year = b.year where relation_id is null and a.year = $year",
"select 'top-level companies with children', count(distinct cw_id) from company_info a join company_relations c on cw_id = c.source_cw_id and a.year = c.year left join company_relations b on cw_id = b.target_cw_id where b.relation_id is null and a.year = $year",
"select 'filers with hierarchy', count(*) from (SELECT c.cw_id FROM relationships a join filings b using (filing_id)  join company_info c on b.cik = c.cik and b.year = c.year where parent_cw_id != c.cw_id  and c.year = $year group by c.cw_id) a");
	foreach my $query (@queries) {
		$row = $db->selectrow_arrayref($query);
		push(@{$data->{$row->[0]}}, $row->[1]);
	}

}
foreach my $key (keys %$data ) {
	my @list = @{$data->{$key}};
	print "<tr><td>$key</td><td>".join("</td><td>", @list)."</td>";
}

print "</table>";
