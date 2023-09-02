package BiodiverseR;
use Mojo::Base 'Mojolicious', -signatures;

#  temporary - we need Biodiverse to be installed or in PERL5LIB
#use Mojo::File qw(curfile);
#use lib curfile->dirname->dirname->dirname->dirname->child('biodiverse/lib')->to_string;

use Ref::Util qw /is_ref is_arrayref is_hashref/;
use Carp qw /croak/;

use BiodiverseR::SpatialAnalysisOneShot;
use BiodiverseR::Data;
use BiodiverseR::IndicesMetadata;
use BiodiverseR::BaseData;

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

  $r->get('/calculations_metadata' => sub ($c) {
      my $metadata = BiodiverseR::IndicesMetadata->get_indices_metadata();
      return $c->render(json => $metadata);
  });

    #  pass some data, get a result.  Or the broken pieces.
    $r->post ('/analysis_spatial_oneshot' => sub ($c) {
        my $analysis_params = $c->req->json;

        $log->debug("parameters are:");
        $log->debug(np ($analysis_params));

        my $oneshot = BiodiverseR::SpatialAnalysisOneShot->new;
        my $results = $oneshot->run_analysis($analysis_params);

        $log->debug("Table is:");
        $log->debug(np ($results));

        return $c->render(json => $results);
    });

    #  initialise a basedata.
    $r->post ('/init_basedata' => sub ($c) {
        my $analysis_params = $c->req->json;

        $log->debug("parameters are:");
        $log->debug(np ($analysis_params));

        my $result = eval {
            BiodiverseR::BaseData->init_basedata ($analysis_params);
            1;
        };
        my $e = $@;
        return error_as_json ($c,  "Cannot initialise basedata, $e")
            if $e;

        return success_as_json ($c, $result);
    });

    $r->post ('/bd_load_data' => sub ($c) {
        my $analysis_params = $c->req->json;

        $log->debug("parameters are:");
        $log->debug(np ($analysis_params));
        $log->debug("About to call load_data");

        my $result = eval {
            BiodiverseR::BaseData->load_data ($analysis_params);
            1;
        };
        my $e = $@;
        $log->debug ($e) if $e;
        return error_as_json ($c, "Cannot load data into basedata, $e")
          if $e;
        # my $bd = BiodiverseR::BaseData->get_basedata_ref;
        # say STDERR "LOADED, result is $result, group count is " . $bd->get_group_count;
        #  should just return success or failure
        return success_as_json ($c, $result);
    });

    $r->post ('/bd_get_group_count' => sub ($c) {
        my $bd = BiodiverseR::BaseData->get_basedata_ref;
        my $result = $bd ? $bd->get_group_count : undef;
        return success_as_json ($c, $result);
    });

    $r->post ('/bd_get_label_count' => sub ($c) {
        my $bd = BiodiverseR::BaseData->get_basedata_ref;
        my $result = $bd ? $bd->get_label_count : undef;
        return success_as_json ($c, $result);
    });

    $r->post ('/bd_run_spatial_analysis' => sub ($c) {
        my $analysis_params = $c->req->json;

        $log->debug("parameters are:");
        $log->debug(np ($analysis_params));
        $log->debug("About to call run_spatial_analysis");

        return error_as_json($c,
            ('analysis_params must be a hash structure, got '
            . reftype($analysis_params)))
          if !is_hashref ($analysis_params);

        my $result = eval {
            BiodiverseR::BaseData->run_spatial_analysis ($analysis_params);
        };
        my $e = $@;
        return error_as_json($c, "Cannot run spatial analysis\n$e")
            if $e;

        return success_as_json($c, $result);
    });

    $r->post ('/bd_save_to_bds' => sub ($c) {
        my $args = $c->req->json;
        my $filename = $args->{filename};
        my $result = eval {
            my $bd = BiodiverseR::BaseData->get_basedata_ref;
            return $c->render(json => undef)
                if !$bd || !defined $filename;
            $bd->save(filename => $filename);
        };
        my $e = $@;
        return $c->render(json => {error => $e, result => defined $result});
    });

    sub success_as_json ($c, $result) {
        return $c->render(
            json => {
                error  => undef,
                result => $result,
            }
        );
    }

    sub error_as_json ($c, $error) {
        return $c->render(
            json => {
                error  => $error,
                result => undef
            }
        );
    }

}


1;
