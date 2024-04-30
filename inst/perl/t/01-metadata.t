use Mojo::Base -strict, -signatures;
use 5.010;

use Test::More;
use Test::Mojo;
use Data::Printer;

my $t = Test::Mojo->new('BiodiverseR');
$t->get_ok('/api_key');
my $api_key = $t->tx->res->json;
# p $api_key;
$t->post_ok('/calculations_metadata' => {"api_key" => $api_key})->status_is(200);

#  pretty basic
$t->json_has ('/result/calc_phylo_rpe2/description');
$t->json_has ('/result/calc_endemism_whole/indices/ENDW_CWE');
$t->json_has ('/result/calc_phylo_rpd2/required_args');
$t->json_has ('/result/calc_phylo_rpe2/indices/PHYLO_RPE_DIFF2/description');

$t->get_ok('/valid_cluster_linkage_functions' => {"api_key" => $api_key})->status_is(200);
my $res = $t->tx->res->json;
my %linkages;
@linkages{@{$res->{result}}} = (1..5);
foreach my $fn (qw/average recalculate average_unweighted minimum maximum/) {
    my $linkage_fn = "link_$fn";
    ok exists ($linkages{$linkage_fn}), "Got $linkage_fn";
}

# $t->get_ok('/valid_cluster_indices')->status_is(200);
# $res = $t->tx->res->json;
# my %indices;
# @indices{@{$res->{result}}} = ();
# foreach my $index (qw/SORENSON S2 PHYLO_RW_TURNOVER/) {
#     ok exists $indices{$index}, $index;
# }


$t->post_ok('/valid_cluster_tie_breaker_indices' => {"api_key" => $api_key})->status_is(200);
$res = $t->tx->res->json;
my %tie_breakers;
@tie_breakers{@{$res->{result}}} = ();
foreach my $index (qw/none random ENDW_WE PD_P PE_WE/) {
    ok exists $tie_breakers{$index}, $index;
}

# use Data::Printer;
# p $t->tx->res->json;
# p $res;



done_testing();
