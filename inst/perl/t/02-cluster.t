use Mojo::Base -strict, -signatures;

use Mojo::File qw(curfile);

use JSON::MaybeXS qw //;
use Test::More;
use Test::Mojo;
use Data::Printer;
use Time::HiRes qw /time/;

use Test::TempDir::Tiny;

use Biodiverse::Indices;
use BiodiverseR::IndicesMetadata;

my $t = Test::Mojo->new('BiodiverseR');
$t->get_ok('/api_key');
my $api_key = $t->tx->res->json;
$t->get_ok('/' => {"api_key" => $api_key})->status_is(200)->content_like(qr/Mojolicious/i);

my $bd = BiodiverseR::IndicesMetadata::_get_dummy_basedata();
my $indices = Biodiverse::Indices->new(BASEDATA_REF => $bd);
my $cluster_indices = $indices->get_valid_cluster_indices;

my $expected_cluster_indices = {
    error  => undef,
    result => $cluster_indices,
};

$t->post_ok('/valid_cluster_indices' => {"api_key" => $api_key})
    ->status_is(200, "status valid cluster indices")
    ->json_is('' => $expected_cluster_indices, "results valid cluster indices");


my $exp_linkages = {
    error => undef,
    result => [
        'link_average', 'link_average_unweighted', 'link_maximum',
        'link_minimum', 'link_recalculate',
    ],
};
$t->get_ok('/valid_cluster_linkage_functions' => {"api_key" => $api_key})
    ->status_is(200, "status valid cluster linkage functions")
    ->json_is('' => $exp_linkages, "json results valid cluster linkage functions");
# use Data::Dumper::Compact qw/ddc/;
# print STDERR ddc $t->tx->res->json;



my $json_tree = '{"edge":[4,5,5,4,5,1,2,3],"edge.length":["NaN",1,1,2],"Nnode":2,"tip.label":["r1","r2","r3"]}';
my $tree = JSON::MaybeXS::decode_json ($json_tree);
# p $tree;
my %bd_setup_params = (
    name      => 'blognorb',
    cellsizes => [ 500, 500 ],
);

my %analysis_args = (
    linkage_function     => undef,
    spatial_conditions   => undef,
    definition_query     => undef,
    spatial_calculations =>  [ qw/calc_endemism_central calc_pd calc_redundancy/ ],
    tree                 => $tree,
    cluster_tie_breaker  => undef,  #  support
);

my $gp_lb = {
    '250:250' => {r1 => 13, r2 => 13, r3 => 13},
    '250:750' => {r2 => 11, r3 => 11, r4 => 10},
    '750:250' => {r3 => 10},
    '750:750' => {r1 =>  8, r3 =>  8},
};

my %data_params = (
    bd_params => {
        data => $gp_lb
    },
);

my $t_msg_suffix = "cluster analysis";
$t->post_ok('/init_basedata'  => {"api_key" => $api_key} => json => \%bd_setup_params)
    ->status_is(200, "status init, $t_msg_suffix")
    ->json_is('' => {result => 1, error => undef}, "basedata init, $t_msg_suffix");

$t->post_ok('/bd_load_data'  => {"api_key" => $api_key} => json => \%data_params)
    ->status_is(200, "status load data, $t_msg_suffix")
    ->json_is('' => {result => 1, error => undef}, "basedata load, $t_msg_suffix");

$t->post_ok('/bd_get_group_count' => {"api_key" => $api_key})
    ->status_is(200, "status gp count, $t_msg_suffix")
    ->json_is('' => {result => 4, error => undef}, "group count, $t_msg_suffix");
$t->post_ok('/bd_get_label_count' => {"api_key" => $api_key})
    ->status_is(200, "status lb count, $t_msg_suffix")
    ->json_is('' => {result => 4, error => undef}, "label count, $t_msg_suffix");

my $exp = {
    error => undef,
    result => {
        NODE_VALUES => [
            [
                'ELEMENT', 'Axis_0', 'COLOUR', 'LENGTHTOPARENT', 'NAME',
                'NODE_NUMBER', 'PARENTNODE', 'TREENAME',
            ],
            [ 1, 1, undef, 0, '2___', 1, 0, 'TREE' ],
            [ 2, 2, undef, '0.0611111111111111', '1___', 2, 1, 'TREE' ],
            [ 3, 3, undef, '0.216666666666667', '0___', 3, 2, 'TREE' ],
            [ 4, 4, undef, '0.2', '250:250', 4, 3, 'TREE' ],
            [ 5, 5, undef, '0.2', '750:750', 5, 3, 'TREE' ],
            [ 6, 6, undef, '0.416666666666667', '750:250', 6, 2, 'TREE' ],
            [ 7, 7, undef, '0.477777777777778', '250:750', 7, 1, 'TREE' ],
        ],
        dendrogram  => {
            Nnode         => 3,
            edge          => [ 5, 6, 7, 7, 5, 6, 1, 2, 3, 4, 6, 7 ],
            'edge.length' => [
                '0.477777777777778', '0.416666666666667', '0.2', '0.2',
                '0.0611111111111111', '0.216666666666667',
            ],
            'node.label'  => [ '1___', '0___' ],
            'root.edge'   => 0,
            'tip.label'   => [ '250:750', '750:250', '250:250', '750:750' ],
        },
        lists       => {},
    },
};

my $cl_name = "cl_" . time();
$t->post_ok('/bd_run_cluster_analysis' => {"api_key" => $api_key} => json => {%analysis_args, name => $cl_name})
    ->status_is(200, "status run cluster, $t_msg_suffix")
    ->json_is('' => $exp, "results, $t_msg_suffix");

$t->post_ok('/bd_get_analysis_results' => {"api_key" => $api_key} => json => {%analysis_args, name => $cl_name})
    ->status_is(200, "status get cluster results, $t_msg_suffix")
    ->json_is('' => $exp, "results posthoc, $t_msg_suffix");



# use Data::Printer;
# p $t->tx->res->json;
# use Data::Dumper::Compact qw/ddc/;
# print STDERR ddc $t->tx->res->json;

done_testing();

