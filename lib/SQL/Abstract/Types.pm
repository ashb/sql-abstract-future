use MooseX::Declare;
class SQL::Abstract::Types {
  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/ArrayRef Str Int Ref HashRef/;

  clean;

  use MooseX::Types -declare => [qw/NameSeparator QuoteChars AST/];

  subtype AST, as HashRef,
    where { exists $_->{-type} && is_Str($_->{-type}) },
    message { "No '-type' key, or it is not a string" };

  subtype NameSeparator,
    as Str,
    where { length($_) == 1 };


  subtype QuoteChars,
    as ArrayRef[Str];
    where { @$_ == 1 || @$_ == 2 },
    message { "Quote characters must be one or two elements" };

  coerce QuoteChars, from Str, via { [ split //, $_ ] };

}

1;
