use strict;
use warnings;

use inc::Module::Install 0.79;

name 'SQL-Abstract';
requires 'Moose' => '0.71';
requires 'MooseX::Method::Signatures' => '0.13_804d1448';
requires 'MooseX::Declare' => '0.09';
requires 'MooseX::Types::Structured' => '0.9';
requires 'Devel::PartialDump' => '0.9';

test_requires 'Test::More';
test_requires 'Test::Differences';
test_requires 'Sub::Exporter';

auto_provides_class();
WriteAll;
