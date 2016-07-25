package Data::Sah::Util::Subschema;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Data::Sah::Normalize qw(normalize_schema);
use Data::Sah::Resolve   qw(resolve_schema);

use Exporter qw(import);
our @EXPORT_OK = qw(extract_subschemas);

my %clausemeta_cache; # key = TYPE.CLAUSE

sub extract_subschemas {
    my $opts = ref($_[0]) eq 'HASH' ? shift : {};
    my $sch = shift;
    my $seen = shift // {};

    $seen->{"$sch"}++ and return ();

    unless ($opts->{schema_is_normalized}) {
        $sch = normalize_schema($sch);
    }

    my $res = resolve_schema(
        {schema_is_normalized => 1},
        $sch);

    my $typeclass = "Data::Sah::Type::$res->[0]";
    (my $typeclass_pm = "$typeclass.pm") =~ s!::!/!g;
    require $typeclass_pm;

    # XXX handle def and/or resolve schema into builtin types. for now we only
    # have one clause set because we don't handle those.
    my @clsets = @{ $res->[1] };

    my @res;
    for my $clset (@clsets) {
        for my $clname (keys %$clset) {
            next unless $clname =~ /\A[A-Za-z][A-Za-z0-9_]*\z/;
            my $cache_key = "$sch->[0].$clname";
            my $clmeta = $clausemeta_cache{$cache_key};
            unless ($clmeta) {
                my $meth = "clausemeta_$clname";
                $clmeta = $clausemeta_cache{$cache_key} =
                    $typeclass->${\("clausemeta_$clname")};
            }
            next unless $clmeta->{subschema};
            my $op = $clset->{"$clname.op"};
            my @clvalues;
            if (defined($op) && ($op eq 'or' || $op eq 'and')) {
                @clvalues = @{ $clset->{$clname} };
            } else {
                @clvalues = ( $clset->{$clname} );
            }
            for my $clvalue (@clvalues) {
                my @subsch = $clmeta->{subschema}->($clvalue);
                push @res, @subsch;
                push @res, map { extract_subschemas($opts, $_, $seen) } @subsch;
            }
        }
    }

    @res;
}

1;
# ABSTRACT: Extract subschemas from a schema

=head1 SYNOPSIS

 use Data::Sah::Util::Subschema qw(extract_subschemas)

 my $subschemas = extract_subschemas([array => of=>"int*"]);
 # => ("int*")

 $subschemas = extract_subschemas([any => of=>["int*", [array => of=>"int"]]]);
 # => ("int*", [array => of=>"int"], "int")


=head1 DESCRIPTION


=head1 FUNCTIONS

=head2 extract_subschemas([ \%opts, ] $sch) => list

Extract all subschemas found inside Sah schema C<$sch>. Schema will be
normalized first, then schemas from all clauses which contains subschemas will
be collected recursively.

Known options:

=over

=item * schema_is_normalized => bool (default: 0)

When set to true, function will skip normalizing schema and assume input schema
is normalized.

=back


=head1 SEE ALSO

L<Sah>, L<Data::Sah>

=cut
