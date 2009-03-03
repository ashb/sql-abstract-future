use strict;
use warnings;

use inc::Module::Install 0.79;

name 'SQL-Abstract';
requires 'Moose' => '0.71';
requires 'MooseX::Method::Signatures' => '0.10';
requires 'MooseX::Declare' => '0.09';

test_requires 'Test::More';
test_requires 'Test::Differences';

WriteAll;
