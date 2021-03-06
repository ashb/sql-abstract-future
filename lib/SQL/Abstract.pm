use MooseX::Declare;

class SQL::Abstract {

  use Carp qw/croak/;
  use Data::Dump qw/pp/;

  use Moose::Util::TypeConstraints;
  use MooseX::Types::Moose qw/ArrayRef Str Int HashRef CodeRef/;
  use MooseX::AttributeHelpers;
  use SQL::Abstract::Types qw/NameSeparator QuoteChars AST/;
  use Devel::PartialDump qw/dump/;

  our $VERSION = '2.000000';

  our $AST_VERSION = '1';

  # Operator precedence for bracketing
  our %PRIO = (
    and => 10,
    or  => 50
  );

  our %BINOP_MAP = (

    '+' => '+',
    '-' => '-',
    '/' => '/',
    '*' => '*',

    '>' => '>',
    '>=' => '>=',
    '<' => '<',
    '<=' => '<=',
    '==' => '=',
    '!=' => '!=',
    # LIKE is always "field LIKE <value>"
    'like' => 'LIKE',
    'not_like' => 'NOT LIKE',
  );

  has expr_dispatch_table => (
    is => 'ro',
    lazy => 1,
    builder => '_build_expr_dispatch_table',
    isa => HashRef[CodeRef],
    metaclass => 'Collection::ImmutableHash',
    provides => {
      get => 'lookup_expr_dispatch'
    }
  );

  has binop_map => (
    is => 'ro',
    lazy => 1,
    builder => '_build_binops',
    isa => HashRef,
    metaclass => 'Collection::ImmutableHash',
    provides => {
      exists => 'is_valid_binop',
      get => 'binop_mapping',
      keys => 'binary_operators'
    }
  );

  # List of default binary operators (for in where clauses)
  sub _build_binops { return {%BINOP_MAP} };

  method _build_expr_dispatch_table {
    my $binop = $self->can('_binop') or croak "InternalError: $self can't do _binop!";
    return {
      map { $_ => $binop } $self->binary_operators
    }
  }

  has ast_version => (
    is => 'ro',
    isa => Int,
    required => 1
  );

  has ident_separator => ( 
    is => 'rw', 
    isa => NameSeparator,
    default => '.',
    required => 1,
  );

  has list_separator => ( 
    is => 'rw', 
    isa => Str,
    default => ', ',
    required => 1,
  );

  has quote_chars => (
    is => 'rw', 
    isa => QuoteChars,
    predicate => 'is_quoting',
    clearer => 'disable_quoting', 
    coerce => 1,
  );

  has binds => (
    isa => ArrayRef,
    is => 'ro',
    clearer => '_clear_binds',
    lazy => 1,
    default => sub { [ ] },
    metaclass => 'Collection::Array',
    provides => {
      push => 'add_bind',
    }
  );

  # TODO: once MXMS supports %args, use that here
  # TODO: improve this so you can pass other args
  method create(ClassName $class: Int $ver) {
    croak "AST version $ver is greater than supported version of $AST_VERSION"
      if $ver > $AST_VERSION;

    my $name = "${class}::AST::v$ver";
    Class::MOP::load_class($name);

    return $name->new(ast_version => $ver);
  }

  # Main entry point
  method generate(ClassName $class: AST $ast) {
    my $ver = $ast->{-ast_version};
    croak "SQL::Abstract AST version not specified"
      unless defined $ver;

    # TODO: once MXMS supports %args, use that here
    my $self = $class->create($ver);

    return ($self->dispatch($ast), $self->binds);
  }

  method reset() {
    $self->_clear_binds();
  }

  method dispatch (AST $ast) {

    my $tag = "_" . $ast->{-type};
    
    my $meth = $self->can($tag) || croak "Unknown tag '$tag'";
    return $meth->($self, $ast);
  }

};

__END__

=head1 NAME

SQL::Abstract - AST based re-implementation of SQL::Abstract

=head1 LICENSE

=head1 AUTHORS

Ash Berlin C<< <ash@cpan.org> >>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

