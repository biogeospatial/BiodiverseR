use Mojo::Base -strict, -signatures;

use Mojo::File qw(curfile);

use JSON::MaybeXS qw //;
use Test::More;
use Test::Mojo;
use Data::Printer;

my $data_dir = curfile->dirname->dirname->sibling('extdata')->to_string;

my $t = Test::Mojo->new('BiodiverseR');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);

#  plenty repetition below - could do with a refactor
my $json_tree = '{"edge":[4,5,5,4,5,1,2,3],"edge.length":["NaN",1,1,2],"Nnode":2,"tip.label":["r1","r2","r3"]}';
my $tree = JSON::MaybeXS::decode_json ($json_tree);
my $oneshot_data = {
  bd => {
    params => {name => 'blognorb', cellsizes => [500,500]},
    raster_files => ["$data_dir/r1.tif", "$data_dir/r2.tif", "$data_dir/r3.tif"],
  },
  analysis_config => {
    calculations => ['calc_endemism_central', 'calc_pd'],
  },
  tree => $tree,
};

my $exp = {
  SPATIAL_RESULTS => [
    [qw /ELEMENT Axis_0 Axis_1 ENDC_CWE ENDC_RICHNESS ENDC_SINGLE ENDC_WE PD PD_P PD_P_per_taxon PD_per_taxon/],
    ['250:-250', '250', '-250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333'],
    ['250:250',  '250',  '250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333'],
    ['750:-250', '750', '-250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333'],
    ['750:250',  '750',  '250', '0.25', 3, '0.75', '0.75', 4, 1, '0.333333333333333', '1.33333333333333'],
  ]
};
my $t_msg_suffix = 'default config';
$t->post_ok ('/analysis_spatial_oneshot' => json => $oneshot_data)
  ->status_is(200, "status, $t_msg_suffix")
  ->json_is ('' => $exp, "json results, $t_msg_suffix");

done_testing();
