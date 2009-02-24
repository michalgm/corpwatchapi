#!/usr/bin/perl 
require "./common.pl";
our $db;
my $sth = $db->prepare("

select count(*)  from filings where has_sec21 =1 union select  count(distinct filing_id) from relationships union select num2/num1*100 from (select count(*) as num1 from filings a where has_sec21 =1) a  join (select  count(distinct filing_id) as num2 from relationships) b union select count(*) from relationships union select concat(num1/num2*100, ' ', num2-num1) from (select count(*) as num1 from relationships a where country_code is not null) a  join (select  count(*) as num2 from relationships) b

");
$sth->execute;
print "content-type: text/html\n\n";
print "<table>";
while (my $row = $sth->fetchrow_arrayref) {
	print "<tr>";
	foreach my $cell (@$row) {
		print "<td>$cell</td>";
	}
	print "</tr>";
}

print "</table>";
