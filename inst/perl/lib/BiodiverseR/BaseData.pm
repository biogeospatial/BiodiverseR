package BiodiverseR::BaseData;

use 5.026;
use strict;
use warnings;
use Carp;
use Ref::Util qw/is_ref is_arrayref is_hashref/;

use Mojo::Base 'Mojolicious', -signatures;

use Data::Printer;

use Biodiverse::BaseData;

#  A bare bones class to handle a single basedata.
#  Implemented as a singleton class - maybe not such a good idea but we'll see.

sub get_instance {
    my $class = shift;
    state $instance = bless {basedata => undef}, $class;
    return $instance;
}

sub init_basedata ($class, $args) {
    my $self = $class->get_instance;
    my %params = (
        NAME         => ($args->{name} // ('BiodiverseR ' . localtime())),
        CELL_SIZES   => $args->{cellsizes},
        CELL_ORIGINS => $args->{cellorigins},
    );

    my $bd = Biodiverse::BaseData->new (%params);
    $self->{basedata} = $bd;
    return defined $self->{basedata};
}

sub get_basedata_ref {
    my $self = get_instance();
    $self->{basedata};
}

sub delete_output ($self, $args) {
    my $name = $args->{name};
    my $bd = $self->get_basedata_ref;
    my %existing = map {$_->get_name => $_} $bd->get_output_refs;
    # use Data::Printer;
    # my @keys = sort keys %existing;
    # p @keys;
    croak qq{Cannot delete output "$name", it is not in the basedata}
      if !$existing{$name};
    return $bd->delete_output (output => $existing{$name});
}

sub _as_arrray_ref {
    return is_ref ($_[0]) ? $_[0] : [$_[0]];
}

sub load_data ($class, $args) {
    my $bd = get_basedata_ref();

    if (my $bd_data = $args->{bd_params}) {
        my $data = $bd_data->{data};
        # say STDERR "Loading bd_data";
        # p $bd_data;
        #  needs to be a more general call
        my $csv_object = $bd->get_csv_object(
            quote_char => $bd->get_param('QUOTES'),
            sep_char   => $bd->get_param('JOIN_CHAR')
        );
        eval {
            $bd->add_elements_collated_simple_aa($data, $csv_object, 1);
        };
        my $e = $@;
        # say STDERR "Error is '$e'";
        # my $lb = $bd->get_labels_ref;
        # p $lb;
        croak $e if $e;
        # # say STDERR "LOADED GPLB DATA";
        # _dump_sample_counts ($bd);
    }

    #need to check if files in the raster exist
    if ($args->{raster_params}{files}) {
        my $params = $args->{raster_params};
        my $files = $params->{files} // croak 'raster_params must include an array of files';
        if (!is_ref($files)) {
            $files = [$files];
        }
        my %in_options_hash = (
            labels_as_bands   => 1,
            #  these should already be set
            # raster_origin_e   => ($bd_params->{cellorigins}[0] // 0),
            # raster_origin_n   => ($bd_params->{cellorigins}[1] // 0),
            # raster_cellsize_e => $bd_params->{cellsizes}[0],
            # raster_cellsize_n => $bd_params->{cellsizes}[1],
        );
        my $success = eval {
            $bd->import_data_raster (
                input_files => $files,
                %in_options_hash,
                labels_as_bands => ($params->{labels_as_bands} // 1),
            );
        };
        croak $@ if $@;
        # say STDERR "LOADED RASTER DATA";
        #_dump_sample_counts ($bd);
    }

    #  some shapefiles
    if ($args->{shapefile_params}{files}) {
        my $params = $args->{shapefile_params};
        # p $params;
        my $files = $params->{files} // croak 'shapefile_params must include an array of files';
        if (!is_ref($files)) {
            $files = [$files];
        }
        # p $bd_params;
        my %in_options_hash
            = map {$_ => _as_arrray_ref($params->{$_})}
            (qw /group_field_names label_field_names sample_count_col_names/);
        #  add croaks for missing field names groups and labels
        # p %in_options_hash;
        my $success = eval {
            $bd->import_data_shapefile (
                input_files => $files,
                %in_options_hash,
            );
        };
        my $e = $@;
        croak $e if $e;
        # say STDERR "LOADED SHAPEFILE DATA";
        # _dump_sample_counts ($bd);
    }
    #  some delimited text files
    # p $analysis_params;
    if ($args->{delimited_text_params}{files}) {
        # say STDERR "LOADING CSV DATA";
        my $params = $args->{delimited_text_params};
        # p $params;
        my $files = $params->{files} // croak 'delimited_text_params must include an array of files';
        if (!is_ref($files)) {
            $files = [$files];
        }
        my %in_options_hash
            = map {$_ => _as_arrray_ref($params->{$_})}
            (qw /group_columns label_columns sample_count_columns/);

        #  add croaks for missing field names groups and labels
        my $success = eval {
            $bd->import_data (
                input_files => $files,
                %in_options_hash,
            );
        };
        my $e = $@;
        say STDERR $e if $e;
        croak $e if $e;
        # say STDERR "LOADED CSV DATA";
        # _dump_sample_counts ($bd);
    }
    #  some spreadsheets
    if ($args->{spreadsheet_params}{files}) {
        my $params = $args->{spreadsheet_params};
        # p $files;
        my $files = $params->{files} // croak 'spreadsheet_params must include an array of files';
        if (!is_ref($files)) {
            $files = [$files];
        }
        # p $bd_params;
        my %in_options_hash
            = map {$_ => _as_arrray_ref($params->{$_})}
            (qw /group_field_names label_field_names sample_count_col_names/);

        #  add croaks for missing field names groups and labels
        # p %in_options_hash;
        my $success = eval {
            $bd->import_data_spreadsheet (
                input_files => $files,
                %in_options_hash,
            );
        };
        my $e = $@;
        # p $e;
        croak $e if $e;
        # say STDERR "LOADED SPREADSHEET DATA";
        # _dump_sample_counts ($bd);
    }

    return 1;
}

sub run_spatial_analysis ($self, $analysis_params) {

    #  rjson converts single item vectors to scalars
    #  so need to handle both scalars and arrays
    my $spatial_conditions
        = $analysis_params->{spatial_conditions} // ['sp_self_only()'];
    if (is_ref($spatial_conditions) && !is_arrayref($spatial_conditions)) {
        croak 'reftype of spatial_conditions must be array';
    }
    elsif (!is_ref($spatial_conditions)) {
        $spatial_conditions = [$spatial_conditions];
    }

    my $def_query = $analysis_params->{definition_query};

    my $calculations
        = $analysis_params->{calculations} // ['calc_richness'];
    if (is_ref($calculations) && !is_arrayref($calculations)) {
        croak 'reftype of spatial_conditions must be array';
    }
    elsif (!is_ref($calculations)) {
        $calculations = [$calculations];
    }

    my $result_lists
        = $analysis_params->{result_lists} // ['SPATIAL_RESULTS'];
    croak 'result_lists must be an array reference'
        if !is_arrayref($result_lists);

    my $bd = $self->get_basedata_ref;
    croak "Data not yet loaded"
        if !$bd->get_group_count;

    #  ensure unique names aross all output types
    my $sp_name = $analysis_params->{name} // localtime();
    my %existing = map {$_->get_name => 1} $bd->get_output_refs;
    croak "Basedata already contains an output with name $sp_name"
      if $existing{$sp_name};

    my $tree;
    if ($analysis_params->{tree}) {
        my $readnex = Biodiverse::ReadNexus->new;
        $readnex->import_data(data => $analysis_params->{tree});
        my @results = $readnex->get_tree_array;
        $tree = shift @results;
    }
    #p $bd->{LABELS};
    #p $analysis_params->{tree};
    #p $tree->{TREE_BY_NAME};
    my $sp = $bd->add_spatial_output(name => $sp_name);
    $sp->run_analysis (
        spatial_conditions => $spatial_conditions,
        definition_query   => $def_query,
        calculations       => $calculations,
        tree_ref           => $tree,
    );
    #p $sp;
    my @list_names = $sp->get_hash_list_names_across_elements(no_private => 1);
    #p @list_names;
    my %results;
    foreach my $listname (@list_names) {
        my $table = $sp->to_table (list => $listname, symmetric => 1);
        $results{$listname} = $table;
    }
    # p %results;
    return \%results;
}

1;
