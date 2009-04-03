#!/usr/bin/perl 
use CGI;
print CGI::header();
chdir("/home/dameat/edgarapi/backend/"); 
require "./common.pl";
my $db = &dbconnect();
my @queries = ( 
"select 'filing companies', count(*) from filers",
"select 'filings w/ sec21', count(*)  from filings where has_sec21 =1",
"select 'filings with relationships parsed', count(distinct filing_id) from relationships",
"select 'percentage of filings parsed', num2/num1*100 from (select count(*) as num1 from filings a where has_sec21 =1) a  join (select  count(distinct filing_id) as num2 from relationships) b",
"select 'filings with empty sec21', count(*) from filings a join no_relationship_filings using(filing_id) where code = 1 ",
"select 'percentage of true filings parsed', num2/(num1-num3)*100 from (select count(*) as num1 from filings a where has_sec21 =1) a  join (select  count(distinct filing_id) as num2 from relationships) b join (select count(*) as num3 from filings a join no_relationship_filings using(filing_id) where code = 1) c",
"select 'number of relationships', count(*) from relationships",
"select 'percentage of relationships w/ location', concat(num1/num2*100, ' ', num2-num1) from (select count(*) as num1 from relationships a where country_code is not null) a  join (select  count(*) as num2 from relationships) b",
"select 'number of companies', count(*) from companies",
"select 'number of company relationships', count(*) from company_relations",
"select 'companies w/o parents or children' , count(distinct cw_id) from companies a where num_children =0 and num_parents =0",
"select 'top-level companies', count(distinct cw_id) from companies a left join company_relations b on cw_id = target_cw_id where relation_id is null",
"select 'top-level companies with children', count(distinct cw_id) from companies a join company_relations c on cw_id = c.source_cw_id left join company_relations b on cw_id = b.target_cw_id where b.relation_id is null",
"select 'filers with hierarchy', count(*) from (SELECT c.cw_id FROM relationships a join filings b using (filing_id)  join companies c on b.cik = c.cik where parent_cw_id != c.cw_id group by c.cw_id) a");
print "<table>";
foreach my $query (@queries) {
	$row = $db->selectrow_arrayref($query);
	print "<tr>";
	foreach my $cell (@$row) {
		print "<td>$cell</td>";
	}
	print "</tr>";
}


print "</table>";

