# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 020-query.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Data::Dumper;
use Logfer qw/ :all /;
use Test::More tests => 48;

BEGIN { use_ok('Visio::XML') };

use constant ELEMENT => 'XML::LibXML::Element';

# ---- globals ----
my $g_log = get_logger(__FILE__);


# ---- sub-routines ----
sub dump_xml {
	my ($vxd)=@_;
#	 ---- dump to screen ----
	$g_log->debug($vxd->doc->toString);
}

sub mkelement {
	my ($parent, $n, $name)=@_;

	$g_log->debug("creating $n [$name] children");

	my ($child, @children);
	my $id = 0;

	for (my $ss = 0; $ss < $n; $ss++) {
		$child = XML::LibXML::Element->new($name);

		for (qw/ _id attr1 attr2 /) { $child->setAttribute($_, $id++);}
		push @children, $parent->appendChild($child);
		$child = ();
	}
	return @children;
}

# -------- TESTS --------
my $vx1 = Visio::XML->new(_testing => 1);


# ---- create ----
my $doc = $vx1->prepare("top", "sec1", "sec2", "sec3", "sec4");
dump_xml $vx1;
isa_ok($doc, 'XML::LibXML::Document',	'prepare 1');
like($doc->toString(), qr/top.*sec1.*sec2.*sec3.*top/, 'xml 1');


# ---- single row with no additional results ----
my $result = $vx1->query("sec1", $vx1->root);
is(scalar(@$result), 1,				'result 1 size');

ok(exists($result->[0]->{'name'}) == 1,		'result 1 structure 1');
ok(exists($result->[0]->{'address'}) == 1,	'result 1 structure 2');

ok($result->[0]->{'name'} eq 'sec1',		'result 1 data 1');
my $parent = $result->[0]->{'address'};
isa_ok($parent, ELEMENT,			'result 1 data 2');


# ---- single row with additional results ----
$parent->setAttribute('attr1', 'value1');
$parent->setAttribute('attr2', 'value2');
dump_xml $vx1;

$result = $vx1->query("sec1", $vx1->root, undef, undef, [ qw/ attr1 attr2 / ]);

ok(exists($result->[0]->{'name'}) == 1,		'result 2 structure 1');
ok(exists($result->[0]->{'address'}) == 1,	'result 2 structure 2');
ok(exists($result->[0]->{'attr1'}) == 1,	'result 2 structure 3');
ok(exists($result->[0]->{'attr2'}) == 1,	'result 2 structure 4');

ok($result->[0]->{'name'} eq 'sec1',		'result 2 data 1');
ok($result->[0]->{'attr1'} eq 'value1',		'result 2 data 2');
ok($result->[0]->{'attr2'} eq 'value2',		'result 2 data 3');


$result = $vx1->query("sec1", $vx1->root, undef, undef, [ qw/ attr1 / ]);

ok(exists($result->[0]->{'name'}) == 1,		'result 3 structure 1');
ok(exists($result->[0]->{'address'}) == 1,	'result 3 structure 2');
ok(exists($result->[0]->{'attr1'}) == 1,	'result 3 structure 3');
ok(exists($result->[0]->{'attr2'}) == 0,	'result 3 structure 4');

ok($result->[0]->{'name'} eq 'sec1',		'result 3 data 1');
ok($result->[0]->{'attr1'} eq 'value1',		'result 3 data 2');


$result = $vx1->query("sec1", $vx1->root, undef, undef, [ qw/ attr2 / ]);

ok(exists($result->[0]->{'name'}) == 1,		'result 4 structure 1');
ok(exists($result->[0]->{'address'}) == 1,	'result 4 structure 2');
ok(exists($result->[0]->{'attr1'}) == 0,	'result 4 structure 3');
ok(exists($result->[0]->{'attr2'}) == 1,	'result 4 structure 4');

ok($result->[0]->{'name'} eq 'sec1',		'result 4 data 1');
ok($result->[0]->{'attr2'} eq 'value2',		'result 4 data 2');


# ---- multiple row with no additional results ----
my $cycles = 5;
my $tag = "sec11";
mkelement($result->[0]->{'address'}, $cycles, $tag);
dump_xml $vx1;

$result = $vx1->query($tag, $parent);
is(scalar(@$result), $cycles,			"result 5 size");

for (my $ss = 0; $ss < $cycles; $ss++) {
	ok(exists($result->[$ss]->{'name'}) == 1,	"result 5-$ss structure 1");
	ok(exists($result->[$ss]->{'address'}) == 1,	"result 5-$ss structure 2");

	ok($result->[$ss]->{'name'} eq $tag,		"result 5-$ss data 1");
	$parent = $result->[$ss]->{'address'};
	isa_ok($parent, ELEMENT,			"result 5-$ss data 2");
}



