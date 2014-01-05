# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 010-fileop.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Logfer qw/ :all /;
use Test::More tests => 7;

BEGIN { use_ok('Visio::XML') };

use constant ELEMENT => 'XML::LibXML::Element';

#########################
my $g_log = get_logger(__FILE__);


# -------- TESTS --------
my $vx1 = Visio::XML->new(_testing => 1);

# ---- create ----
my $doc = $vx1->prepare("top", "sec1", "sec2", "sec3");
isa_ok($doc, 'XML::LibXML::Document',	'prepare 1');
like($doc->toString(), qr/top.*sec1.*sec2.*sec3.*top/, 'xml p1');


# ---- write ----
my $fn_out = "010-fileop.xml";
ok($vx1->write($fn_out) == 0,	'write 1');
ok(-f $fn_out,		'write 2');


# ---- read ----
my $vx2 = Visio::XML->new(_testing => 1);
ok($vx2->read($fn_out),	'read 1');
like($vx2->doc->toString, qr/top.*sec1.*sec2.*sec3.*top/s, 'read 1 check');
my $found = $vx2->find_or_create($vx2->root, "sec1");

$g_log->debug($vx2->doc->toString);

unlink($fn_out);

#my $vx3 = Visio::XML->new;
#ok($vx3->read('../Visio/Visio_design.vdx'),	'read 2');
#$found = $vx3->find_or_create($vx3->root, "DocumentProperties");



# ---- set_property ----
#my $doc1 = XML::LibXML->createDocument;
#my $root = $doc1->createElement("xxx");
#$doc1->setDocumentElement($root);
#$vx2->root($root);
$found = $vx1->find_or_create($vx1->root, "sec2");
$vx1->set_property("sec2", "fu", "bar");
$g_log->debug($vx1->doc->toString);

$g_log->debug($vx2->doc->toString);
$g_log->debug(sprintf "name of root [%s]", $vx2->root->getName);
$found = $vx2->find_or_create($vx2->root, "sec1");
$found = $vx2->find_or_create($vx2->root, "sec1");
$g_log->debug(sprintf "FoC [%s]", $found->getName);
#printf "vx1 [%s]\n", Dumper($vx1);

$vx2->set_property("sec1", "foo", "bar");

$g_log->debug($vx2->doc->toString);

