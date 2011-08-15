#!/usr/bin/perl -w
use strict;

use t::lib::T;
use t::lib::U;

my $compiler = XML::Writer::Compiler->new;

my $tree = XML::TreeBuilder->new( { 'NoExpand' => 0, 'ErrorContext' => 0 } );
$tree->parse_file('t/InvoiceAdd.xml');

my $class = 't::lib::InvoiceAdd';
my $firstdepth=4;
my $extends='';
my $class_src = $compiler->buildclass( $class, $tree, $firstdepth, $extends );

Class::MOP::load_class($class);

my %data = (
  CustomerRef => {
    FullName => 'Bob'
   }
);


my $xmlclass = $class->new(data => \%data);


my $xml = $xmlclass->xml->string->value;

use File::Slurp;

my $exp = read_file('t/InvoiceAdd.xml.expected');

is_xml( $xml, $exp, 'test xml generation' );
done_testing;
