package Visio::XML;
# $Header: /home/tomby/RCS/Visio.pm,v 1.6 2010/08/02 00:41:48 tomby Exp $
#
# XML.pm - XML handling for Visio.
# $Revision: 1.6 $, Copyright (C) 2010 Thomas McMeekin
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 2 of the License,
# or any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#
# History:
# $Log: Visio.pm,v ___join_line_here___ $
#use 5.014002;
use strict;
use warnings;
use vars qw/ $VERSION /;

use Carp qw(cluck confess);     # only use stack backtrace within class
use Data::Dumper;

use POSIX;
use XML::LibXML;
use Logfer qw/ :all /;


# ---- package constants ----
use constant FORMAT_NICE => 1; # seeXML::LibXML::Document toString;

use constant NS_VISIO_EXT  => "vx";

use constant URL_MS_SCHEMA => "http://schemas.microsoft.com/visio";

use constant URI_VISIO_CORE => join('/', URL_MS_SCHEMA, "2003", "core");
use constant URI_VISIO_EXT  => join('/', URL_MS_SCHEMA, "2006", "extension");

use constant XML_ENCODING  => "utf-8";


# ---- package globals ----
our $AUTOLOAD;
#our @ISA = qw();
$VERSION = "1.001";     # update this on new release


# ---- package locals ----
my $_n_objects = 0;     # counter of objects created.

my %attribute = (
	_n_objects => \$_n_objects,
	_log => get_logger("Visio::XML"),
	doc => undef,
	format => FORMAT_NICE,
	root => undef,
	_test_id => 0,
	_testing => 0,
	xpc => undef, 	# XPathContext (for searching nodes)
);


# Preloaded methods go here.
sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or confess "$self is not an object";

	my $name = $AUTOLOAD;
	$name =~ s/.*://;   # strip fully−qualified portion

	unless (exists $self->{_permitted}->{$name} ) {
		confess "no attribute [$name] in class [$type]";
	}

	if (@_) {
		return $self->{$name} = shift;
	} else {
		return $self->{$name};
	}
}


sub new {
	my ($class) = shift;
	#my $self = $class->SUPER::new(@_);
	my $self = { _permitted => \%attribute, %attribute };

	++ ${ $self->{_n_objects} };

	bless ($self, $class);

	my %args = @_;  # start processing any parameters passed
	my ($method,$value);
	while (($method, $value) = each %args) {

		confess "SYNTAX new(method => value, ...) value not specified"
			unless (defined $value);

		$self->_log->debug("method [self->$method($value)]");

		$self->$method($value);
	}

	return $self;
}


sub query {
	my $self = shift;
	my $node_name = shift;
	my $start_node = shift;	# node at which to start search
	my $xpath = shift; # relative XPath below start_node (optional)
	my $where_clause = shift;	# see below
	my $ar_return = shift;	# see below

#	the return value is a list of hashes of XML nodes, as follows:
#		node_addr1 => ( 
#			'address' => node address (see XML::LibXML::Node),
#			'name' => nodeName (see XML::LibXML::Node),
#			),
#		node_addr2 => ( 
#			'address' => node address (see XML::LibXML::Node),
#			'name' => nodeName (see XML::LibXML::Node),
#			)
#		);
#	ar_return is a list of attributes that you want returned, in
#	addition to those above, e.g. if $ar_return is ('attr1', 'attr2'),
#		node_addr1 => ( 
#			'address' => as above,
#			'name' => as above,
#			'attr1' => 'value1',
#			'attr2' => 'value2'
#			), ...
#	where_clause is additional matching criteria based on attribute,
#	expressed as attr=value, e.g. 'ID=3'.

	my $xp = (defined $xpath) ? $xpath : "";
	$xp .= 'node()';
	my $matched = 0;
	my @result;

	$self->_log->debug(sprintf "search from [%s] XPath [$xp] for [$node_name]", $start_node->getName);

	for my $node ($start_node->findnodes($xp)) {

		# name match
		next unless ($node->getName eq $node_name);

		# where match (attribute)
		if (defined $where_clause && $where_clause =~ /=/) {
			my ($a,$b) = split(/=/, $where_clause);

			if (defined $a && defined $b && $node->hasAttribute($a)) {

				next unless ($node->getAttribute($a) eq $b);
			}
		}

		$matched++;

		my $result = { 'name' => $node_name, 'address' => $node };

		# augment query result

		if (defined $ar_return) {

			$self->_log->debug(sprintf "augmenting results [%s]", Dumper($ar_return));

			for my $attr (@$ar_return) {

				if (defined $node->getAttribute($attr)) {

					$result->{$attr} = $node->getAttribute($attr);
				} else {
					$result->{$attr} = undef;
				}
			}
		}

		push @result, ( $result );
		$result = ();
	}
	$self->_log->debug(sprintf "matched [%d] result [%s]", $matched, Dumper(\@result));

	return \@result;
}


sub find {
	my $self = shift;
	my $parent = shift;
	my $name = shift;
	my $where = shift; # relative XPath expression below parent

	confess "SYNTAX find(parent,name,[where])"
		unless (defined $parent && defined $name);

	my $aname = 'ID';
	my $id = 0;
	my $xpath = (defined $where) ? $where : "";
	$xpath .= 'node()';

	$self->_log->debug("name [$name] xpath [$xpath]");

	my $node = undef;
	my $xcount = 0;

	$self->_log->debug(sprintf "searching under [%s] for [$name]", $parent->getName);
	for ($parent->findnodes($xpath)) {
		if ($_->getName eq $name) {
			$node = $_;
			$xcount++;

			# audit the max id for the node (if it exists).
			if (defined $node->getAttribute($aname)) {
				$id = $node->getAttribute($aname)
					if ($node->getAttribute($aname) > $id);
			}
		}
	}
	$self->_log->debug("matches [$xcount] id [$id]");

	return ($node, $id);
}


sub create {
	my $self = shift;
	my $parent = shift;
	my $name = shift;

	confess "SYNTAX create(parent,name)"
		unless (defined $parent && defined $name);

	my $node = XML::LibXML::Element->new($name);

	$node->setAttribute('_id', $self->{_test_id}++)
		if ($self->_testing);

	$self->_log->debug(sprintf "created node [%s]", $node->getName);

	$parent->appendChild($node);

	return $node;
}


sub find_or_create {
	my $self = shift;
	my $parent = shift;
	my $name = shift;
	my $where = shift;

	confess "SYNTAX find_or_create(parent,name,[where])"
		unless (defined $parent && defined $name);

	my ($element, undef) = $self->find($parent, $name, $where);

	$element = $self->create($parent, $name)
		unless (defined $element);

	return $element;
}


sub prepare {
	my $self = shift;
	my $name = shift;

	confess "SYNTAX prepare(document, section1, section2, ...)"
		unless (defined $name && scalar(@_) > 0);

	my $doc = XML::LibXML->createDocument;

	# not sure why this is done, but create the VisioDocument
	# using the extended namespace ...
	my $root = $doc->createElementNS(URI_VISIO_EXT,
		sprintf "%s:%s", NS_VISIO_EXT, $name);
	# ... and then reset it back to the core namespace!
	$root->setNamespace(URI_VISIO_CORE, "");
#	my $root = XML::LibXML::Element->new($name);

	$doc->setDocumentElement($root);
	$doc->setEncoding(XML_ENCODING);

	$self->doc($doc);
	$self->root($root);

#	my $xpc = XML::LibXML::XPathContext->new($doc);
#	$xpc->registerNs(NS_VISIO_EXT, URI_VISIO_EXT);
#	$self->xpc($xpc);

	for (@_) {
		$self->find_or_create($root, $_);
	}

	return $doc;
}


sub read {
	my $self = shift;
	my $filename = shift;

	confess "SYNTAX read(filename)" unless defined ($filename);

	$self->_log->debug("read() about to load [$filename]");

	my $doc = XML::LibXML->load_xml(location => $filename);
	my $root = $doc->documentElement;

#	my $xpc = XML::LibXML::XPathContext->new($root);
#	$xpc->registerNs(NS_VISIO_EXT, URI_VISIO_CORE);
#	$xpc->registerNs(NS_VISIO_EXT, URI_VISIO_EXT);
#	$root->setNamespace(URI_VISIO_CORE, "");

	$self->doc($doc);
	$self->root($root);

	#DEBUG sprintf("self [%s]", Dumper($self));

	return $self->root->nodeName;
}


sub write {
	my $self = shift;
	my $filename = shift;

	confess "SYNTAX write(filename)" unless defined ($filename);

	unless (defined $self->doc) {
		confess "cannot generate XML on empty document";
		return -1;
	}

	if (defined $filename) {

		$self->_log->debug("opening [$filename]");

		open(my $fh, ">$filename") || confess "open($filename) failed";

		$self->_log->debug("dumping XML to [$filename]");

		$self->doc->toFH($fh, $self->format);

		close($fh) || confess "close($filename) failed";
	}

	return 0;
}


sub set_property {
	my $self = shift;
	my ($section, $property, $value)=@_;

	confess "ERROR cannot set_property on empty document"
		unless defined ($self->root);

	$self->_log->debug("searching for [$section]");

	my $where = $self->find_or_create($self->root, $section);

	$self->_log->debug(sprintf 'where [%s]', $where->getName);

	$self->_log->debug("searching for [$property]");

	my $element = $self->find_or_create($where, $property);

	if ($element->hasChildNodes) {	# property may already be set

		for my $child ($element->childNodes) {

			$self->_log->debug(sprintf "removing pre-existing child [type=%s]", $child->nodeType);

			$element->removeChild($child);
		}
	}
	$element->appendText($value);
}


DESTROY {
        my $self = shift;

        -- ${ $self->{_n_objects} };
};


#END { }

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Visio::XML - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Visio::XML;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Visio::XML, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.


=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

B<Tom McMeekin>, tmcmeeki@cpan.org

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Tom McMeekin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
