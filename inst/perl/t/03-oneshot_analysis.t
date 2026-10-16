use Mojo::Base -strict, -signatures;

use Mojo::File qw(curfile);

use JSON::MaybeXS qw //;
use Test::More;
use Test::Mojo;
use Data::Printer;

my $data_dir = curfile->dirname->dirname->sibling('extdata')->to_string;

my $t = Test::Mojo->new('BiodiverseR');
$t->get_ok('/api_key');
my $api_key = $t->tx->res->json;
$t->get_ok('/' => {"api_key" => $api_key})->status_is(200)->content_like(qr/Mojolicious/i);

my $json_tree = '{"edge":[4,5,5,4,5,1,2,3],"edge.length":["NaN",1,1,2],"Nnode":2,"tip.label":["r1","r2","r3"]}';
my $tree = JSON::MaybeXS::decode_json ($json_tree);

my $gp_lb = {
    '250:250' => {r1 => 13758, r2 => 13860, r3 => 13727},
    '250:750' => {r1 => 11003, r2 => 11134, r3 => 11279},
    '750:250' => {r1 => 10981, r2 => 11302, r3 => 10974},
    '750:750' => {r1 =>  8807, r2 =>  8715, r3 =>  8788},
};
my %common_args = (
    bd => {
        params       => { name => 'blognorb', cellsizes => [ 500, 500 ] },
    },
    analysis_config => {
        calculations => [qw /calc_endemism_central calc_pd calc_local_sample_count_lists/],
    },
    tree => $tree,
);

my %file_type_args = (
    gplb_params => $gp_lb,
    raster_params => {
        files => [ "$data_dir/r1.tif", "$data_dir/r2.tif", "$data_dir/r3.tif" ]
    },
    shapefile_params => {
        files => [ "$data_dir/r1.shz", "$data_dir/r2.shz", "$data_dir/r3.shz" ],
        group_field_names      => [ qw/:shape_x :shape_y/ ],
        label_field_names      => [ 'label' ],
        sample_count_col_names => [ 'count' ]
    },
    delimited_text_params => {
        files => [ "$data_dir/r1.csv", "$data_dir/r2.csv", "$data_dir/r3.csv" ],
        group_columns        => [ 1, 2 ],
        label_columns        => [ 4 ],
        sample_count_columns => [ 3 ],
    },
    spreadsheet_params => {
        files                  => [ "$data_dir/r1.xlsx", "$data_dir/r2.xlsx", "$data_dir/r3.xlsx" ],
        group_field_names      => [ qw/X Y/ ],
        label_field_names      => [ 'label' ],
        sample_count_col_names => [ 'count' ]
    },
);

my @file_arg_keys = sort keys %file_type_args;

my $sp_results = [
    [ qw/ELEMENT Axis_0 Axis_1 ENDC_CWE ENDC_RICHNESS ENDC_SINGLE ENDC_WE PD PD_P PD_P_per_taxon PD_per_taxon/ ],
    [ '250:250', '250', '250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333' ],
    [ '250:750', '250', '750', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333' ],
    [ '750:250', '750', '250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333' ],
    [ '750:750', '750', '750', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333' ],
];
my %exp = (
    2 => $sp_results,
    3 => $sp_results,
    4 => $sp_results,
);

my %exp_sample_counts;
for my $n (2..4) {
    my $arr = $exp_sample_counts{$n} = [];
    push @$arr, [qw/ELEMENT Axis_0 Axis_1 r1 r2 r3/];
    foreach my $elt (qw /250:250 250:750 750:250 750:750/) {
        my $subarr = [$elt, split /:/, $elt];
        foreach my $label (qw/r1 r2 r3/) {
            push @$subarr, $n * $gp_lb->{$elt}{$label};
        }
        push @$arr, $subarr;
    }
}
# p %exp_sample_counts;

    #  should be part of the main loop
# JUST_GPLB_DATA: {
#     my $oneshot_data = {
#         %common_args,
#         bd => {
#             params => {name => 'blognorb', cellsizes => [500,500]},
#             data   => $gp_lb,
#         },
#     };
#     my $exp = {
#         SPATIAL_RESULTS  => [
#             [ qw/ELEMENT Axis_0 Axis_1 ENDC_CWE ENDC_RICHNESS ENDC_SINGLE ENDC_WE PD PD_P PD_P_per_taxon PD_per_taxon REDUNDANCY_ALL REDUNDANCY_SET1/ ],
#             [ '250:250', '250', '250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333', '0.99992743983553', '0.99992743983553' ],
#             [ '250:750', '250', '750', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333', '0.999910222647833', '0.999910222647833' ],
#             [ '750:250', '750', '250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333', '0.999909793426948', '0.999909793426948' ],
#             [ '750:750', '750', '750', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333', '0.999885974914481', '0.999885974914481' ],
#         ],
#     };
#
#     my $t_msg_suffix = 'default config, gplb data only';
#     $t->post_ok('/analysis_spatial_oneshot' => json => $oneshot_data)
#         ->status_is(200, "status, $t_msg_suffix")
#         ->json_is('' => $exp, "json results, $t_msg_suffix");
# }

#  We only need to assess 2, 3 and 4 of the file types
#  Singles are already done in t/02-oneshot_analysis.t
#  There is also no need to test all possible combinations

foreach my $n (2..4) {

    foreach my $i ($n-1 .. $#file_arg_keys) {
        my @keys = @file_arg_keys[($i - $n + 1) .. $i];
        my $ftypes = join ' ', @keys;
        #  kludgy workaround until gplb data are "first class" types
        my $have_gplb_data = grep {/gplb/} @keys;
        if ($have_gplb_data) {
            @keys = grep {$_ !~ /gplb/} @keys;
        }
        # diag "testing $ftypes";
        # diag @keys;
        my $oneshot_data = {
            %file_type_args{@keys},
            %common_args,
        };
        #  needs to be localised
        local $oneshot_data->{bd}{data} = $file_type_args{gplb_params}
            if $have_gplb_data;

        my $expected = {
            SPATIAL_RESULTS  => $exp{$n},
            ABC3_LABELS_SET1 => $exp_sample_counts{$n},
        };
        # diag $expected;
        my $t_msg_suffix = "file types: $ftypes";
        $t->post_ok('/analysis_spatial_oneshot' => {"api_key" => $api_key} => json => $oneshot_data)
            ->status_is(200, "status, $t_msg_suffix")
            ->json_is('' => $expected, "numeric results, $t_msg_suffix");
        # use Data::Printer;
        # p $t->tx->res->json;
    }

}



done_testing();
