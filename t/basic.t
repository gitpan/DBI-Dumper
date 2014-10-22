#!/usr/bin/perl
# vim:ft=perl

use strict;
use warnings;

use DBI;
use DBI::Dumper;
use Test::More;
use File::Temp qw(tempfile);


$::RD_ERRORS = 1;
$::RD_WARN = 1;

my @tests = ( 
	q{
		export data 
		fields terminated by 'a'
		enclosed by 'c'
		escaped by '0'
		from select
	} => qr{^ cac a c00c a c0cc $}mx,

	q{
		export data 
		fields terminated by ','
		escaped by 'c'
		from select
	} => qr{^ a , 0 , cc $}mx,

	q{
		export data 
		fields terminated by '0'
		escaped by '\'
		from select
	} => qr{^ a 0 \\0 0 c $}mx,

	q{
		export data 
		fields terminated by ','
		enclosed by '"'
		from select
	} => qr{^ "a" , "0" , "c" $}mx,

	q{
		export data from
		select col1, col2, col3 from data
		where this = that
		and that = this
	} => qr{^ a \t 0 \t c $}mx,

	q{
		export data 
		fields enclosed by '"' and '"'
		from select
	} => qr{^ "a" \t "0" \t "c" $}mx,

	q{
		export data
		fields enclosed by '"'
		from select
	} => qr{^ "a" \t "0" \t "c" $}mx,

	q{
		export data
		fields terminated by X'00'
		from select
	} => qr{^ a \0 0 \0 c $}mx,

	q{
		export data
		fields terminated by X'09'
		enclosed by '"'
		from select
	} => qr{^ "a" \t "0" \t "c" $}mx,
);


plan tests => @tests / 2 * 6 * 2; # six tests per control file (done twice total)

my $CAN_USE_INLINE = 1;
eval { require Inline };
if($@) {
	$CAN_USE_INLINE = 0;
}

for my $i (0 .. $CAN_USE_INLINE) {
	$DBI::Dumper::USE_INLINE_C = $i;

	my @tests_copy = @tests;

#	warn "INLINE: $DBI::Dumper::USE_INLINE_C";
#	warn scalar(@tests_copy) . " tests remaining!";

	while(@tests_copy) {
		my($control_text, $test_regex) = (shift @tests_copy, shift @tests_copy);
		next unless $control_text;
		my $sth = DummySTH->new;

		my (undef, $tfn) = tempfile( UNLINK => 1 );
		my $dumper = DBI::Dumper->new(
			-control_text => $control_text, 
			-output => $tfn, 
			-silent => 1
		);
		ok(UNIVERSAL::isa($dumper => 'DBI::Dumper'), 'create');

		ok($dumper->prepare);

		#TODO move to grammar.t
		#like($dumper->{query} => qr{select col1, col2, col3 from data.*that = this}s);

		if(! ok(defined $dumper->execute($sth)) ) {
			die "Failed to execute for $control_text";
		}

		next unless ok(! -z $tfn);

		local $/;
		open my $tfh, "<", $tfn || die "Could not open file: $!";
		my $data = <$tfh>;
		close $tfn;

		like($data => qr/$test_regex/m);

		ok( ( my @a = split("\n", $data) ) == 11 );
	}
}

package DummySTH;
my $count;
sub new { $count = 0 ;return bless {}, shift };
sub fetchrow_arrayref {
	return if $count++ > 10;
	return [qw(a 0 c)];
};

0;

