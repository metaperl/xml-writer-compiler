#!/usr/bin/perl -w
use strict;

use t::lib::T;
use t::lib::U;


my $builder = XML::Writer::Compiler->new;

my $tree = XML::TreeBuilder->new({ 'NoExpand' => 0, 'ErrorContext' => 0 });
$tree->parse_file('sample.xml');


my $class = $builder->buildclass($tree);

done_testing;
