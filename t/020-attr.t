# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 020-attr.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Logfer qw/ :all /;
use Test::More tests => 7;

BEGIN { use_ok('Visio::XML') };

use constant ATTR => 'XML::LibXML::Attr';

#########################
my $g_log = get_logger(__FILE__);


# -------- TESTS --------
my $vx1 = Visio::XML->new(_testing => 1);

# ---- create ----
my $doc = $vx1->prepare("top", "sec1", "sec2", "sec3");
isa_ok($doc, 'XML::LibXML::Document',	'prepare 1');
like($doc->toString(), qr/top.*sec1.*sec2.*sec3.*top/, 'xml p1');



# ---- dump to screen and file ----
$g_log->debug($vx1->doc->toString);
my $fn_out = "020-attr.xml";
ok($vx1->write($fn_out) == 0,   'write 1');
ok(-f $fn_out,          'write 2');


