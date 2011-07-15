#!/usr/bin/perl -w
use strict;

use t::lib::T;
use t::lib::U;

ok( my $compiler = XML::Writer::Compiler->new, 'XML::Writer::Compiler instance' );

my $tree = XML::TreeBuilder->new({ 'NoExpand' => 0, 'ErrorContext' => 0 });
$tree->parsefile("t/InvoiceAdd.xml");

my $firstdepth = 4;
my $prepend_lib = '';
my $class = 't::lib::InvoiceAdd';
my $pkg = $compiler->buildclass($class => $tree, $firstdepth, $prepend_lib);


my $exp =
'<shopping><item>bread</item><item>butter</item><item>beans</item></shopping>';

is( $pkg, $exp, 'test package generation' );
done_testing;

