# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 000-element.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 16;
use Logfer qw/ :all /;

BEGIN { use_ok('Visio::XML') };

use constant ELEMENT => 'XML::LibXML::Element';

#########################
my $g_log = get_logger(__FILE__);


# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# seed an XML document for testing purposes
my $doc1 = XML::LibXML->createDocument;
my $root = $doc1->createElement("mydoc");

$doc1->setDocumentElement($root);
$doc1->setEncoding("utf-8");


# -------- TESTS --------
my $vx1 = Visio::XML->new(_testing => 1);
isa_ok($vx1, 'Visio::XML',	'new');

# ---- node creation and search; uniqueness ----

isa_ok($vx1->find_or_create($root, "first"), ELEMENT,	'foc c1');
like($doc1->toString(), qr/mydoc.*first.*mydoc/, 'xml c1');

isa_ok($vx1->find_or_create($root, "second"), ELEMENT,	'foc c2');
like($doc1->toString(), qr/mydoc.*first.*second.*mydoc/, 'xml c2');

my $first = $vx1->find_or_create($root, "first");
isa_ok($first, ELEMENT, 	'foc f1');

my $third = $vx1->find_or_create($root, "third");
isa_ok($third, ELEMENT, 	'foc c3');
like($doc1->toString(), qr/mydoc.*first.*second.*third.*mydoc/, 'xml c3');
is($third, $vx1->find_or_create($root, "third"),	'foc f3');


# ---- embedded node creation and search ----

# create a subordinate to the third element, called "fourth"
my $fourth = $vx1->find_or_create($third, "fourth");
isa_ok($fourth, ELEMENT,	'foc c34');
like($doc1->toString(), qr/mydoc.*second.*third.*fourth.*mydoc/, 'xml c34');

# create another "fourth" under the root, should have a different id
isnt($fourth, $vx1->find_or_create($root, "fourth"),	'foc c4');
like($doc1->toString(), qr/third.*fourth.*third.*fourth/, 'xml c4');
is($fourth, $vx1->find_or_create($third, "fourth"),	'foc cmp1');
is($fourth, $vx1->find_or_create($root, "fourth", "/mydoc/third/"),	'foc cmp2');

$g_log->debug($doc1->toString);
