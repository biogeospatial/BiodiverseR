use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('BiodiverseR');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);

#$t->get_ok('/results/joel.json')
#  ->json_is({name => 'Joel Berger', status => 'nice'});
  
my $ua = Mojo::UserAgent->new;
$ua->post(
  'http://127.0.0.1:3000/basedata',
  {
    params => {name => 'blognorb', cellsizes => [100,100]},
    data   => {
      label1 => '50:50',
      label1 => '150:50',
      label2 => '50:50',
      label2 => '150:50',
    },
  },
  'some binary content'
);

my $bd_as_json = {
  params => {name => 'blognorb', cellsizes => [100,100]},
  data   => {a => '50:50', b => '150:50'},
}; 
$t->post_ok ('/basedata' => json => $bd_as_json)
  ->status_is(200)
  ->json_is(undef);
#$t->get_ok ('/basedata' => {Accept => '*/*'} => json => {a => 'b'})
#  ->json_is ({});

done_testing();
