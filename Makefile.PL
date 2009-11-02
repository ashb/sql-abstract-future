use strict;
use warnings;

use inc::Module::Install 0.79;

name 'SQL-Abstract';
requires 'Moose' => '0.71';
requires 'MooseX::Declare' => '0.22';
requires 'MooseX::Types::Structured' => '0.09';
requires 'Devel::PartialDump' => '0.07';

test_requires 'Test::More';
test_requires 'Test::Differences';
test_requires 'Sub::Exporter';

auto_provides_class();
json_meta();
auto_install;

tests_recursive 't';

WriteAll;
