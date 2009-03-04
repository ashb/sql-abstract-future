use MooseX::Declare;


class SQL::Abstract {

  use Carp qw/croak/;
  use Data::Dump qw/pp/;

  use Moose::Util::TypeConstraints;
  use MooseX::Types -declare => [qw/NameSeparator/];
  use MooseX::Types::Moose qw/ArrayRef Str Int HashRef CodeRef/;
  use MooseX::AttributeHelpers;

  clean;

  subtype NameSeparator,
    as ArrayRef[Str];
    #where { @$_ == 1 ||| @$_ == 2 },
    #message { "Name separator must be one or two elements" };

  coerce NameSeparator, from Str, via { [ $_ ] };

  our $VERSION = '2.000000';

  our $AST_VERSION = '1';

  # Operator precedence for bracketing
  our %PRIO = (
    and => 10,
    or  => 50
  );

  our %BINOP_MAP = (
    '>' => '>',
    '<' => '<',
    '==' => '=',
    '!=' => '!=',
    # LIKE is always "field LIKE <value>"
    '-like' => 'IN',
    '-not_like' => 'NOT LIKE',
  );

  has where_dispatch_table => (
    is => 'ro',
    lazy_build => 1,
    isa => HashRef[CodeRef],
    metaclass => 'Collection::ImmutableHash',
    provides => {
      get => 'lookup_where_dispatch'
    }
  );

  has binop_map => (
    is => 'ro',
    lazy_build => 1,
    isa => HashRef,
    metaclass => 'Collection::ImmutableHash',
    provides => {
      exists => 'is_valid_binop',
      get => 'binop_mapping',
      keys => 'binary_operators'
    }
  );

  sub _build_binop_map { return {%BINOP_MAP} };

  method _build_where_dispatch_table {
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
  method create(ClassName $class: Int $ver) {
    croak "AST version $ver is greater than supported version of $AST_VERSION"
      if $ver > $AST_VERSION;

    my $name = "${class}::AST::v$ver";
    Class::MOP::load_class($name);

    return $name->new(ast_version => $ver);
  }

  # Main entry point
  method generate(ClassName $class: ArrayRef $ast) {
    croak "SQL::Abstract AST version not specified"
      unless ($ast->[0] eq '-ast_version');

    my (undef, $ver) = splice(@$ast, 0, 2);

    # TODO: once MXMS supports %args, use that here
    my $self = $class->create($ver);

    return ($self->dispatch($ast), $self->binds);
  }

  method reset() {
    $self->_clear_binds();
  }

  method dispatch (ArrayRef $ast) {

    local $_ = $ast->[0];
    s/^-/_/ or croak "Unknown type tag '$_'";
    
    my $meth = $self->can($_) || croak "Unknown tag '$_'";
    return $meth->($self, $ast);
  }

};
