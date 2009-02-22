use strict;
use warnings;

use inc::Module::Install 0.79;

requires 'Moose' => '0.71';
requires 'MooseX::Method::Signatures' => '0.07';
requires 'MooseX::Declare' => '0.04';

test_requires 'Test::More';

WriteAll;
