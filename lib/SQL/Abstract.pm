use MooseX::Declare;
use MooseX::Method::Signatures;


class SQL::Abstract {

  use Carp qw/croak/;
  use Data::Dump qw/pp/;

  use Moose::Util::TypeConstraints;
  use MooseX::Types -declare => ['NameSeparator'];
  use MooseX::Types::Moose qw/ArrayRef Str/;
  use MooseX::AttributeHelpers;

  use namespace::clean -except => ['meta'];

  subtype NameSeparator,
    as ArrayRef[Str];
    #where { @$_ == 1 ||| @$_ == 2 },
    #message { "Name separator must be one or two elements" };

  coerce NameSeparator, from Str, via { [ $_ ] };

  our $VERSION = '2.000000';

  our $AST_VERSION = '1';

  has name_separator => ( 
    is => 'rw', 
    isa => NameSeparator,
    default => sub { ['.'] },
    coerece => 1,
    required => 1,
  );

  has list_separator => ( 
    is => 'rw', 
    isa => Str,
    default => ', ',
    required => 1,
  );

  has binds => (
    isa => ArrayRef,
    default => sub { [ ] },
    metaclass => 'Collection::Array',
    provides => {
      push => 'add_bind',
      get => 'binds'
    }
  );

  method generate (ArrayRef $ast) {
    $self = new $self unless blessed($self);

    local $_ = $ast->[0];
    s/^-/_/ or croak "Unknown type tag '$_'";
    my $meth = $self->can($_) || \&_generic_func;
    return $meth->($self, $ast);
  }

  method _select(ArrayRef $ast) {
    
  }

  method _name(ArrayRef $ast) {
    my (undef, @names) = @$ast;

    my $sep = $self->name_separator;

    return $sep->[0] . 
           join( $sep->[1] . $sep->[0], @names ) . 
           $sep->[1]
              if (@$sep > 1);

    return join($sep->[0], @names);
  }

  method _list(ArrayRef $ast) {
    my (undef, @items) = @$ast;

    return join(
      $self->list_separator,
      map { $self->generate($_) } @items);
  }

  method _alias(ArrayRef $ast) {
    my (undef, $alias, $as) = @$ast;

    return $self->generate($alias) . " AS $as";

  }

  method _value(ArrayRef $ast) {
    my ($undef, $value) = @$ast;

    $self->add_bind($value);
    return "?";
  }

  method _where(ArrayRef $ast) {
    my (undef, @clauses) = @$ast;

    my @output;

    foreach (@clauses) {
      my $op = $_->[0];

      unless (substr($op, 0, 1) eq '-') {
        # A simple comparison op (==, >, etc.)
        croak "Binary operator $op expects 2 children, got " . $#$_
          if @{$_} > 3;

        push @output, $self->generate($_->[1]), 
                      $op,
                      $self->generate($_->[2]);
      }
    }

    return join(' ', 'WHERE', @output);
  }

  method _generic_func(ArrayRef $ast) {
  }


};
