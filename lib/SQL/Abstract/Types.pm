use MooseX::Declare;
class SQL::Abstract::Types {
  use Moose::Util::TypeConstraints;
  use MooseX::Types -declare => [qw/NameSeparator QuoteChars AST ArrayAST HashAST/];
  use MooseX::Types::Moose qw/ArrayRef Str Int Ref HashRef/;

  subtype ArrayAST, as ArrayRef,
    where { is_Str($_->[0]) && substr($_->[0],0,1) eq '-' },
    message { "First key of arrayref must be a string starting with '-'"; };

  subtype HashAST, as HashRef,
    where { exists $_->{-type} && is_Str($_->{-type}) },
    message { "No '-type' key, or it is not a string" };

  subtype AST, as ArrayAST|HashAST; 

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
