package BiodiverseR::IndicesMetadata;
use strict;
use warnings;
use English qw { -no_match_vars };
use Ref::Util qw /is_arrayref is_hashref is_regexpref/;

use Mojo::Base 'Mojolicious', -signatures;


sub get_indices_metadata ($self, %args) {
    my $bd = $self->_get_dummy_basedata;

    # my $label_props = get_label_properties();
    # eval {
    #     $bd->assign_element_properties (
    #         type              => 'labels', # plural
    #         properties_object => $label_props,
    #     )
    # };
    # warn $@ if $@;

    # my $group_props = get_group_properties();
    # eval {
    #     $bd->assign_element_properties (
    #         type              => 'groups', # plural
    #         properties_object => $group_props,
    #     )
    # };
    # warn $@ if $@;

    my $indices = Biodiverse::Indices->new(BASEDATA_REF => $bd);
    my $list = $indices->get_calculations_as_flat_hash;

    my $metadata;
    #  plenty repeated scanning here - maybe should go recursive
    foreach my $calculation (sort keys %$list) {
        my %required_args;
        my @precalcs = ($calculation);
        my %checked;
        while (my $subname = shift @precalcs) {
            next if $checked{$subname};
            $checked{$subname}++;
            next if $subname =~ /^calc_abc[123]$/;

            my $meta = $indices->get_metadata(sub => $subname);

            foreach my $dep_base (qw/pre_calc_global post_calc_global pre_calc post_calc_global/) {
                my $method = "get_${dep_base}_list";
                my $precalc_list = $meta->$method;
                next if !$precalc_list;
                push @precalcs, @$precalc_list;
            }
            my $reqd_args = $meta->get_required_args;

            if (is_arrayref $reqd_args) {
                my @arr = grep {not is_regexpref($_)} @$reqd_args;
                @required_args{@arr} = ();
            }
            elsif (is_hashref $reqd_args) {
                @required_args{keys %$reqd_args} = ()
            }
            elsif ($reqd_args and not is_regexpref($reqd_args)) {
                $required_args{$reqd_args} = undef;
            }
        }
        my @keys = map {$_ =~ s/_ref$//r} sort keys %required_args;
        $metadata->{$calculation}{required_args} = \@keys;
        my $meta = $indices->get_metadata(sub => $calculation)->clone; #  clone for safety
        $metadata->{$calculation}{description} = $meta->get_description;
        $metadata->{$calculation}{indices} = $meta->get_indices;
        $metadata->{$calculation}{uses_nbr_lists} = $meta->get_uses_nbr_lists;
    }

    return _recursive_unbless($metadata);
}

sub _recursive_unbless ($data) {
    use Ref::Util qw/is_hashref is_arrayref/;
    use Scalar::Util qw /blessed/;
    use Data::Structure::Util qw /unbless/;
    if (is_hashref ($data)) {
        foreach my $v (values %$data) {
            unbless $v if blessed $v;
            _recursive_unbless($v);
        }
    }
    elsif (is_arrayref $data) {
        foreach my $v (@$data) {
            unbless $v if blessed $v;
            _recursive_unbless($v);
        }
    }
    return $data;
}

sub get_label_properties {
    my $data = <<'END_LABEL_PROPS'
ax1,ax2,example_prop1,example_prop2
a,b,1,1,1
END_LABEL_PROPS
    ;

    element_properties_from_string($data);
}

sub get_group_properties {
    my $data = <<'END_LABEL_PROPS'
ax1,ax2,example_gprop1,example_gprop2
1,1,1,1,1
END_LABEL_PROPS
    ;

    element_properties_from_string($data);
}

sub get_valid_cluster_indices ($self, %args) {
    my $bd = $self->_get_dummy_basedata;

    my $indices = Biodiverse::Indices->new(BASEDATA_REF => $bd);
    my $list = $indices->get_valid_cluster_indices;
    return $list;
}

sub get_valid_cluster_tie_breaker_indices ($self, %args) {
    my $bd = $self->_get_dummy_basedata;

    my $indices = Biodiverse::Indices->new(BASEDATA_REF => $bd);
    my $cl_indices = $indices->get_valid_cluster_indices;
    my $rg_indices = $indices->get_valid_region_grower_indices;
    return ['none', 'random', sort (keys %$cl_indices, keys %$rg_indices)];
}

sub _get_dummy_basedata {
    my $bd = Biodiverse::BaseData->new (
        CELL_SIZES => [1,1],
    );
    $bd->add_element (
        label => 'a:b',
        group => '1:1',
        count => 1,
    );
    my $lb_ref = $bd->get_labels_ref;
    $lb_ref->set_param (CELL_SIZES => [-1,-1]);

    return $bd;
}

1;