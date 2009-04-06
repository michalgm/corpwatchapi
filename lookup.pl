#!/usr/bin/perl -w

#my @cities = ('praha+13,+czech+Republic','pruhonice,+czech+Republic','Dob%C5%99ejovice+Prague+east,+Czech+Republic','Kamenice,+Prague-East,+Czech+Republic','tynec+nad+sazavou','Sob%C4%9B%C5%A1ovice,+chrastany,+Czech+Republic','neveklov','klimetice','kosova+hora','sedlcany','sedlec-prcice','Borot%C3%ADn,+T%C3%A1bor,+Czech+Republic','tabor,czech+republic','sezimovo+usti','%C5%BDele%C4%8D,+T%C3%A1bor,+Czech+Republic','Z%C3%A1l%C5%A1%C3%AD,+T%C3%A1bor,+Czech+Republic','veseli+nad+luznici','lomnice+nad+luznici','Hlubok%C3%A1+nad+Vltavou,+Budweis,+Czech+Republic','Budweis,+Budweis,+Czech+Republic','zlata+koruna','%C4%8Cesk%C3%BD+Krumlov,+%C4%8Cesk%C3%BD+Krumlov,+Czech+Republic','rozmital+na+sumave','rychnov+nad+malsi','benesov+nad+cernou','Dobr%C3%A1+Voda,+horni+Stropnice,+Czech+Republic','Nov%C3%A9+Hrady,+Budweis,+Czech+Republic','kojakovice','Doman%C3%ADn,+Jind%C5%99ich%C5%AFv+Hradec,+Czech+Republic','trebon','novosedly+nad+nezarkou','Jem%C4%8Dina,+Hat%C3%ADn,+Jind%C5%99ich%C5%AFv+Hradec,+Czech+Republic','Jind%C5%99ich%C5%AFv+Hradec,+Jind%C5%99ich%C5%AFv+Hradec,+Czech+Republic','nova+bystrice','Kl%C3%A1%C5%A1ter,+Nov%C3%A1+Byst%C5%99ice,+Jind%C5%99ich%C5%AFv+Hradec,+Czech+Republic','stare+mesto+pod+landstejnem','slavonice','pisecne','Uher%C4%8Dice,+Znojmo,+Czech+Republic','podhradi+nad+Dyji','Satov','vranov+nad+dyji','safov','chvalovice','strachotice','jaroslavice','hevlin','novy+prerov','mikulov','valtice','schrattenberg,Austria','poysdorf,Austria','Mistelbach,+Austria','ladendorf,Austria','niederkreuzstetten,Austria','Wolkersdorf+im+Weinviertel,+Austria','wien,Austria');
#my @cities = ('wien', 'tulln', 'Krems', 'Spitz', 'melk', 'ybbs', 'grein', 'mauthausen', 'linz', 'aschach', 'schlogen', 'passau,germany' );
#my @cities = ( 'Passau,Germany', 'Scharding', 'Obernberg am Inn,Austria', 'Braunau', 'Burghausen', 'Tittmoning', 'Oberndorf b. Salzburg', 'salzburg', 'hallein', 'Pass Lueg', 'Werfen', 'Bischofshofen', 'St.Johann im Pongau', 'Schwarzach im Pongau', 'Lend', 'Taxenbach', 'Kaprun', 'Piesendorf', 'Mittersill', 'Neukirchen am Grossvenediger', 'Krimml', 'Gerlos', 'hainzenberg', 'zell am ziller', 'erlach am ziller', 'kaltenbach', 'uderns', 'fugen', 'schlitters', 'strass im zillertal', 'sankt margarethen', 'schwaz', 'Pill', 'kolsass', 'volders', 'Hall in Tirol', 'Innsbruck', 'Hall in Tirol', 'volders', 'kolsass', 'Pill', 'schwaz', 'sankt margarethen', 'jenbach', 'fischl,tirol', 'Eben am achensee', 'Maurach', 'Buchau', 'Achensee', 'Achenkirch', 'Achenwald', 'Fall, Germany', 'hohenwiesen, germany', 'bad tolz, germany', 'Gelting Geretsried, Bad Tölz-Wolfratshausen, Bavaria, Germany', 'wolfratshausen, Germany', 'schaftlarn, germany', 'munich, germany'  );
require('common.pl');
use XML::Simple;
use WWW::Mechanize;
use Time::HiRes;
our $db;
#$db->do("update un_country_subdivisions set latitude=null, longitude=null");
$db->do("update un_countries set latitude=null, longitude=null");

my @queries = (
#	'select subdivision_name, subdivision_code, country_code, "sub" from un_country_subdivisions a join un_countries b using (country_code) where a.latitude is null',
	'select country_name, null, country_code, "country" from un_countries b where latitude is null',
#	'select subdivision_code, subdivision_code, country_code, "sub" from un_country_subdivisions a join un_countries b using (country_code) where a.latitude is null',
	'select country_code, null, country_code, "country" from un_countries b where latitude is null'
);

foreach my $query (@queries) {
	$cities = $db->selectall_arrayref($query);
	my $address = "";
	foreach my $location (@$cities) {
		my ($lat, $long) = &getlats(@$location);
		if ($lat && $long) { 
			#$db->do("update un_country_subdivisions set latitude=$lat, longitude=$long where subdivision_code='$location->[1]' and country_code='$location->[2]'");
			if ($location->[3] eq 'country') {
				$db->do("update un_countries set latitude=$lat, longitude=$long where country_code='$location->[2]'");
			} else {
				$db->do("update un_country_subdivisions set latitude=$lat, longitude=$long where subdivision_code = '$location->[1]' and country_code='$location->[2]'");
			}
			$db->do("update un_countries set latitude=$lat, longitude=$long where country_code='$location->[2]'");
		}
		Time::HiRes::sleep(.1);
	}
}

sub getlats() {
		my ($city,$code,$country) = @_;	
		#unless ($city =~ /czech/i || $city =~ /austria/i || $city =~ /germany/i) { $city.= ',+austria'; }
		if ($code) {
			$city = "$city,$country";
			$city =~ s/\[[^\]]+\]//g;
		} else { $city = $country; }
		$query = "&q=$city&gl=$country";
		print "\n$query: ";
		my $geocodelink = "http://maps.google.com/maps/geo?output=xml&key=ABQIAAAAZ17RZRttqznNPz0vgpzhzxT2EXyjnpwOg92RRtC8aoVZI4PCTRSF7ZctknyuxjupmswgvQ0mhTqevw$query";
		my $agent2 = WWW::Mechanize->new();
		$agent2->agent('Mozilla 5.0');
		$agent2->get($geocodelink);
		unless ($agent2->success) {
			print "HTTP Status: ".$agent2->status." for google map";
			return ($agent2->status);
		}
		#if (my $uncompressed = Compress::Zlib::memGunzip( $agent2->content )) { $agent2->update_html($uncompressed); }
		#&log(Dumper($agent->content));
		my $xml = XML::Simple->new(ForceArray=>['Placemark']);
		#print $agent2->content;
		my $xmldata = $xml->XMLin($agent2->content);
		#&log(Dumper($xmldata));
		my $status;
		if ($xmldata) {
			$status = $xmldata->{'Response'}->{Status}->{code};
		}
		if( $status != 200) { 
			print $geocodelink;
			print " Bad google status: $status";
			return 'NOLAT1'; 
		}
		#&log(Data::Dumper::Dumper($xmldata));
		my $accuracy = $xmldata->{'Response'}->{Placemark}->{p1}->{AddressDetails}->{Accuracy};
		my $address = $xmldata->{'Response'}->{Placemark}->{p1}->{address};
		my ($long, $lat) = split(/,/, $xmldata->{'Response'}->{Placemark}->{p1}->{Point}->{coordinates});
		my $foundcountry = $xmldata->{'Response'}->{Placemark}->{p1}->{AddressDetails}->{Country}->{CountryNameCode};
		#my $address = $xmldata->{'Response'}->{Placemark}->{p1}->{AddressDetails}->{Country}->{AdministrativeArea}->{SubAdministrativeArea}->{Locality}->{Thoroughfare}->{ThoroughfareName};
		#my $city = $xmldata->{'Response'}->{Placemark}->{p1}->{AddressDetails}->{Country}->{AdministrativeArea}->{SubAdministrativeArea}->{Locality}->{LocalityName};
		#if (!$city) { $city =  $xmldata->{'Response'}->{Placemark}->{p1}->{AddressDetails}->{Country}->{AdministrativeArea}->{SubAdministrativeArea}->{SubAdministrativeAreaName} };
		#my $state = $xmldata->{'Response'}->{Placemark}->{p1}->{AddressDetails}->{Country}->{AdministrativeArea}->{AdministrativeAreaName};
		#my $zip = $xmldata->{'Response'}->{Placemark}->{p1}->{AddressDetails}->{Country}->{AdministrativeArea}->{SubAdministrativeArea}->{Locality}->{PostalCode}->{PostalCodeNumber};
		#if( $accuracy < 7) { 
			#&log("Geocode too inaccurate: $accuracy");
			#	return 'BADADDY'; 
			#	}
		if ($foundcountry ne $country) {
			print "Bad Country: $foundcountry != $country]\n"; 
			return "BADCOUNTRY";
		}
		unless( $lat && $long) {
			&log("missing lat and long: ".$agent2->content);
			return 'NOLAT2'; 
		}
		print " $address: $lat, $long ($accuracy)\n";
		#$address=~s/\&amp\;/\&/; #converts address format
		#unless ($address) { $address = ""; }
		#return($address,$city,$state,$zip,$lat,$long);	
		return($lat, $long);
		
}

