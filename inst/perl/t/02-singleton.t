use Mojo::Base -strict, -signatures;

use Mojo::File qw(curfile);

use JSON::MaybeXS qw //;
use Test::More;
use Test::Mojo;
use Data::Printer;
use Time::HiRes qw /time/;

use Test::TempDir::Tiny;

my $data_dir = curfile->dirname->dirname->sibling('extdata')->to_string;

my $t = Test::Mojo->new('BiodiverseR');
$t->get_ok('/api_key');
my $api_key = $t->tx->res->json;
$t->get_ok('/' => {"api_key" => $api_key})->status_is(200)->content_like(qr/Mojolicious/i);

my $exp = {
    result => {
        SPATIAL_RESULTS => [
            [ qw/ELEMENT Axis_0 Axis_1 ENDC_CWE ENDC_RICHNESS ENDC_SINGLE ENDC_WE PD PD_P PD_P_per_taxon PD_per_taxon REDUNDANCY_ALL REDUNDANCY_SET1/ ],
            [ '250:250', '250', '250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333', '0.99992743983553', '0.99992743983553' ],
            [ '250:750', '250', '750', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333', '0.999910222647833', '0.999910222647833' ],
            [ '750:250', '750', '250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333', '0.999909793426948', '0.999909793426948' ],
            [ '750:750', '750', '750', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333', '0.999885974914481', '0.999885974914481' ],
        ]
    },
    error  => undef,
};


my $json_tree = '{"edge":[4,5,5,4,5,1,2,3],"edge.length":["NaN",1,1,2],"Nnode":2,"tip.label":["r1","r2","r3"]}';
my $tree = JSON::MaybeXS::decode_json ($json_tree);
# p $tree;
my %bd_setup_params = (
    name => 'blognorb',
    cellsizes => [ 500, 500 ],
);

my %analysis_args = (
    calculations => [ qw/calc_endemism_central calc_pd calc_redundancy/ ],
    tree         => $tree,
);

my $gp_lb = {
    '250:250' => {r1 => 13758, r2 => 13860, r3 => 13727},
    '250:750' => {r1 => 11003, r2 => 11134, r3 => 11279},
    '750:250' => {r1 => 10981, r2 => 11302, r3 => 10974},
    '750:750' => {r1 =>  8807, r2 =>  8715, r3 =>  8788},
};

my %file_type_args = (
    bd_params => {
        data => $gp_lb
    },
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
# @file_arg_keys = ($file_arg_keys[1]);

foreach my $file_type (@file_arg_keys) {
    # diag "File type is $file_type";
    my $bd_params = \%bd_setup_params;
    my $data_params = {
        $file_type => $file_type_args{$file_type},
    };
    my $t_msg_suffix = "default config, $file_type";
    $t->post_ok('/init_basedata' => {"api_key" => $api_key} => json => $bd_params)
        ->status_is(200, "status init, $t_msg_suffix")
        ->json_is('' => {result => 1, error => undef}, "json results, $t_msg_suffix");

    $t->post_ok('/bd_load_data' => {"api_key" => $api_key} => json => $data_params)
        ->status_is(200, "status load data, $t_msg_suffix")
        ->json_is('' => {result => 1, error => undef}, "json results, $t_msg_suffix");

    $t->post_ok('/bd_get_group_count' => {"api_key" => $api_key})
        ->status_is(200, "status gp count, $t_msg_suffix")
        ->json_is('' => {result => 4, error => undef}, "group count, $t_msg_suffix");
    $t->post_ok('/bd_get_label_count' => {"api_key" => $api_key})
        ->status_is(200, "status lb count, $t_msg_suffix")
        ->json_is('' => {result => 3, error => undef}, "label count, $t_msg_suffix");


    my $sp_name = "sp_" . time();
    $t->post_ok('/bd_run_spatial_analysis' => {"api_key" => $api_key} => json => {%analysis_args, name => $sp_name})
        ->status_is(200, "status run spatial, $t_msg_suffix")
        ->json_is('' => $exp, "json results, $t_msg_suffix");

    #  no need to test these more than once
    if ($file_type =~ /bd_params/) {
        my $sp_res = $t->tx->res->json;
        $t->post_ok('/bd_get_analysis_results' => {"api_key" => $api_key} => json => {name => $sp_name})
            ->status_is(200, "status get_analysis_results from already run sp analysis")
            ->json_is('' => $sp_res, "json results, get precalculated sp results");

        my $dir = tempdir();
        my $filename = Mojo::File->new($dir, "$file_type.bds");
        $t->post_ok('/bd_save_to_bds' => {"api_key" => $api_key} => json => {filename => $filename})
            ->status_is(200, "status save basedata, $t_msg_suffix")
            ->json_is('' => {result => 1, error => ''}, "json results, $t_msg_suffix");
        ok -e $filename, "$filename exists";
        my $bd = Biodiverse::BaseData->new(file => $filename);
        is $bd->get_group_count, 4, "saved basedata has expected group count";
        is $bd->get_label_count, 3, "saved basedata has expected label count";

        #  try a reload
        $t->post_ok('/init_basedata' => {"api_key" => $api_key} => json => {filename => $filename})
            ->status_is(200, "status load basedata from file, $t_msg_suffix")
            ->json_is('' => {result => 1, error => undef}, "results basedata file exists, $t_msg_suffix");

        my $err_fname = "$filename.zorb";
        my $exp_error = "Cannot initialise basedata, Unable to load basedata file $err_fname";
        $t->post_ok('/init_basedata' => {"api_key" => $api_key} => json => {filename => $err_fname})
            ->status_is(200, "status load basedata from file that does not exist, $t_msg_suffix");
            #->json_like('' => {result => 0, error => qr/$exp_error/}, "results basedata file does not exist, $t_msg_suffix");
        my $res = $t->tx->res->json;
        # p $res;
        ok !$res->{result}, "Got a non result";
        like $res->{error}, qr/\Q$exp_error\E/, "Got expected error text";

        my %aargs = %analysis_args;
        $aargs{definition_query} = '$x <= 250';
        $aargs{name} = 'with def query';
        local $exp->{result}{SPATIAL_RESULTS}[3] = ['750:250', '750', '250', (undef) x 10];
        local $exp->{result}{SPATIAL_RESULTS}[4] = ['750:750', '750', '750', (undef) x 10];
        $t->post_ok('/bd_run_spatial_analysis' => {"api_key" => $api_key} => json => \%aargs)
            ->status_is(200, "status run spatial with def query, $t_msg_suffix")
            ->json_is('' => $exp, "json results, $t_msg_suffix");
        # p $t->tx->res->json;

        my $exp_output_count = {error => undef, result => 2};
        $t->post_ok('/bd_get_analysis_count' => {"api_key" => $api_key})
            ->status_is(200, "number of outputs in basedata")
            ->json_is('' => $exp_output_count, "json results: number of outputs before deletion");

        my $exp_delete = {error => undef, result => 1};
        $t->post_ok('/bd_delete_analysis' => {"api_key" => $api_key} => json => {name => $aargs{name}})
            ->status_is(200, "status delete spatial analysis")
            ->json_is('' => $exp_delete, "json results from output deletion");
        # p $t->tx->res->json;

        $exp_output_count = {error => undef, result => 1};
        $t->post_ok('/bd_get_analysis_count' => {"api_key" => $api_key})
            ->status_is(200, "number of outputs in basedata")
            ->json_is('' => $exp_output_count, "json results: number of outputs after deletion");
        # p $t->tx->res->json;

        $exp_delete = {error => undef, result => 1};
        $t->post_ok('/bd_delete_all_analyses' => {"api_key" => $api_key})
            ->status_is(200, "status delete all analyses")
            ->json_is('' => $exp_delete, "json results from output deletion");
        # p $t->tx->res->json;

        $exp_output_count = {error => undef, result => 0};
        $t->post_ok('/bd_get_analysis_count' => {"api_key" => $api_key})
            ->status_is(200, "number of outputs in basedata")
            ->json_is('' => $exp_output_count, "json results: number of outputs after delete all");
        # p $t->tx->res->json;

    }
}


done_testing();
