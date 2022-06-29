package BiodiverseR;
use Mojo::Base 'Mojolicious', -signatures;

#  temporary - we need Biodiverse to be installed or in PERL5LIB
#use Mojo::File qw(curfile);
#use lib curfile->dirname->dirname->dirname->dirname->child('biodiverse/lib')->to_string;

use Ref::Util qw /is_ref is_arrayref/;
use Carp qw /croak/;

use BiodiverseR::SpatialAnalysisOneShot;
use BiodiverseR::Data;
use Biodiverse::BaseData;
use Biodiverse::ReadNexus;
use Biodiverse::Spatial;

#  should use Mojo::File
use Path::Tiny qw /path/;
use Data::Printer qw /p np/;

local $| = 1;

my $logname = path (sprintf ("./mojo_log_%s.txt", time()))->absolute;
say STDERR "log file is $logname";
my $log = Mojo::Log->new(path => $logname, level => 'trace');

#use JSON::Validator 5.08 ();

#has 'foo';

#has 'biodiverse_object' => sub {
#  Biodiverse::BaseData->new(NAME => 'some name');
#};


# This method will run once at server start
sub startup ($self) {

$log->debug("Called startup");

  # Load configuration from config file
  #my $config = $self->plugin('NotYAMLConfig');

  $self->helper(data => sub {state $data = BiodiverseR::Data->new});

  my $renderer = Mojolicious::Renderer->new;
  if ($ENV{PAR_INC}) {
    push @{$renderer->paths}, path ($ENV{PAR_INC}, 'templates');
  }
  
  # Configure the application
  #$self->secrets($config->{secrets});
  $self->secrets(rand());

  # Router
  my $r = $self->routes;

  #$self->renderer->default_format('json');

  # Normal route to controller
  $r->get('/')->to('Example#welcome');
  
  #  pass some data, get a result.  Or the broken pieces. 
  $r->post ('/analysis_spatial_oneshot' => sub ($c) {
    my $analysis_params = $c->req->json;

$log->debug("parameters are:");
$log->debug(np ($analysis_params));

    my $oneshot = BiodiverseR::SpatialAnalysisOneShot->new;
    my $table = $oneshot->run_analysis($analysis_params);

$log->debug("Table is:");
$log->debug(np ($table));

    return $c->render(json => $table);
  });
  
}

1;
