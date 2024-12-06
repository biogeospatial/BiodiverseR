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
use POSIX ();
use Time::HiRes qw /time/;

use Digest::SHA qw(sha256_base64);

use File::stat;
use Time::localtime;

use Date::Calc qw(Delta_Days);

local $| = 1;

#  maybe should save mac logs to ~/Library/BiodiverseR
my $logdir  = path (($^O eq 'MSWin32' ? $ENV{APPDATA} : $ENV{HOME}), "BiodiverseR/logs")->mkdir;
#  Looks nasty but gets us a lexically sorting, human comprehensible time stamp
#  that should have low risk of overlap across parallel runs
my $timestamp = POSIX::strftime( "%Y%m%d_%H%M%S", gmtime())
              . (sprintf ("%.6f", POSIX::fmod (Time::HiRes::time(), 1)) =~ s/^0//r);
my $logname = path (sprintf ("$logdir/BiodiverseR_log_%s_%s.txt", $timestamp, $$))->absolute;
while (-e $logname) {
    $logname =~ s/.txt$//;
    $logname .= 'x.txt';
}
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

  # Removing old log files
  my @all_log_files = glob($logdir . "/*.txt");
  foreach my $file (@all_log_files){
    if (-M $file > 7) {
     unlink $file;
    }
  }

  # Load configuration from config filesecrets
  #my $config = $self->plugin('NotYAMLConfig');

  $self->helper(data => sub {state $data = BiodiverseR::Data->new});

  my $renderer = Mojolicious::Renderer->new;
  if ($ENV{PAR_INC}) {
    push @{$renderer->paths}, path ($ENV{PAR_INC}, 'templates');
  }
  
  # Configure the application
  #$self->secrets($config->{secrets});
  $self->secrets(rand());
  
  # Creating an api key for the server
  my @valid_chars = ("A".."Z", "a".."z");
  my $random_str;
  $random_str .= $valid_chars[rand @valid_chars] for 1..20;
  # $log->debug("RANDOM STR");
  # $log->debug($random_str);
  state $api_key = sha256_base64($random_str);
  # $log->debug("API KEY");
  # $log->debug($api_key);

  # Router
  my $r = $self->routes;

  #$self->renderer->default_format('json');

  # Normal route to controller
  $r->get('/')->to('Example#welcome');

    my %metadata_route_factory = (
        calculations_metadata             => {
            method => 'get_indices_metadata',
        },
        valid_cluster_indices             => {},
        valid_cluster_tie_breaker_indices => {}
    );

    foreach my $route (keys %metadata_route_factory) {
        my $method = $metadata_route_factory{$route}{method}
          // "get_${route}";

        $r->post ("/$route" => sub ($c) {
            #  drop calls with invalid api key
            return $c->render(json => undef)
                if !is_valid_api_key($c);

            my $metadata;
            my $success = eval {
                $metadata = BiodiverseR::IndicesMetadata->$method();
                1;
            };
            my $e = $@;
            return error_as_json($c, $e)
                if $e;
            return success_as_json($c, $metadata);
        });
    }

    #  does not yet fit into a factory
    $r->get('/valid_cluster_linkage_functions' => sub ($c) {
        #  drop calls with invalid api key
        return $c->render(json => undef)
            if !is_valid_api_key($c);

        my $metadata;
        use Biodiverse::Cluster;
        my $success = eval {
            $metadata = 'Biodiverse::Cluster'->get_linkage_functions();
            1;
        };
        my $e = $@;
        return error_as_json($c, $e)
            if $e;
        return success_as_json($c, $metadata);
    });

    #  pass some data, get a result.  Or the broken pieces.
    $r->post ('/analysis_spatial_oneshot' => sub ($c) {
        #  drop calls with invalid api key
        return $c->render(json => undef)
            if !is_valid_api_key($c);

        my $analysis_params = $c->req->json;

        $log->debug("parameters are:");
        $log->debug(np ($analysis_params));

        my $oneshot = BiodiverseR::SpatialAnalysisOneShot->new;
        my $results = $oneshot->run_analysis($analysis_params);

        $log->debug("Table is:");
        $log->debug(np ($results));

        return $c->render(json => $results);
    });

    $r->post ('/bd_get_analysis_count' => sub ($c) {
        #  drop calls with invalid api key
        return $c->render(json => undef)
            if !is_valid_api_key($c);

        my $result = BiodiverseR::BaseData->get_output_count;
        return success_as_json ($c, $result);
    });

    # a reasonably complex factory
    my %bd_route_factory = (
        init_basedata       => {
            route  => 'init_basedata',
            method => 'init_basedata',
            error  => 'Cannot initialise basedata, %{error}',
        },
        load_data           => {
            method => 'load_data',
            error  => 'Cannot load data into basedata, %{error}'
        },
        delete_analysis     => {
            method => 'delete_output',
            error  => "Cannot delete %{name} from basedata, %{error}"
        },
        delete_all_analyses => {
            method  => 'delete_all_outputs',
            error   => 'Cannot delete all analyses from basedata, %{error}',
            no_args => 1,
        },
    );

    foreach my $stub (keys %bd_route_factory) {
        my %rprops = %{$bd_route_factory{$stub}};
        my $route    = $rprops{route} // "bd_$stub";
        my $method   = $rprops{method} // $stub;
        my $error    = $rprops{error} // '';
        my $has_args = !$rprops{no_args};

        my $name_template = '%{name}';
        my $err_template  = '%{error}';

        $r->post ($route => sub ($c) {
            #  drop calls with invalid api key
            return $c->render(json => undef)
                if !is_valid_api_key($c);

            my $analysis_params = $c->req->json;

            $log->debug("bd_$stub parameters are:");
            $log->debug(np ($analysis_params));
            $log->debug("About to call $method");

            #  for debug
            BiodiverseR::BaseData->set_logger ($log);

            my $result = eval {
                BiodiverseR::BaseData->$method ($has_args ? $analysis_params : ());
                1;
            };

            if (my $e = $@) {
                $log->debug ($e);
                my $msg = $error;
                $msg =~ s/\Q$err_template\E/$e/;
                if ($msg =~ /\Q$name_template\E/) {
                    my $name = $analysis_params->{name} // '';
                    $msg =~ s/\Q$name_template\E/$name/;
                }
                return error_as_json($c, $msg);
            }

            # $log->debug("No error");
            # my $bd = BiodiverseR::BaseData->get_basedata_ref;
            # $log->debug(np $bd);

            return success_as_json ($c, $result);
        });
    }


    #  some simple ones
    foreach my $stub (qw /label_count group_count cell_sizes cell_origins/) {
        my $method = "get_$stub";
        $r->post ("/bd_$method" => sub ($c) {
            #  drop calls with invalid api key
            return $c->render(json => undef)
                if !is_valid_api_key($c);

            my $bd = BiodiverseR::BaseData->get_basedata_ref;
            my $result = $bd ? $bd->$method : undef;
            return success_as_json ($c, $result);
        });
    }

    #  analysis factory
    foreach my $stub (qw /spatial cluster randomisation/) {
        my $method = "run_${stub}_analysis";
        $r->post ("/bd_$method" => sub ($c) {
            return analysis_call ($c, $method);
        });
    }


    $r->post ('/bd_get_analysis_results' => sub ($c) {
        #  drop calls with invalid api key
        return $c->render(json => undef)
            if !is_valid_api_key($c);

        my $analysis_params = $c->req->json;

        $log->debug("parameters are:");
        $log->debug(np ($analysis_params));
        $log->debug("About to call get_analysis_results");

        return error_as_json($c,
            ('analysis_params must be a hash structure, got '
                . reftype($analysis_params)))
            if !is_hashref ($analysis_params);

        my $result = eval {
            BiodiverseR::BaseData->get_analysis_results ($analysis_params->{name});
        };
        my $e = $@;
        return error_as_json($c, "Failed to get analysis results\n$e")
            if $e;

        return success_as_json($c, $result);
    });

    $r->post ('/bd_save_to_bds' => sub ($c) {

        #  drop calls with invalid api key
        return $c->render(json => undef)
            if !is_valid_api_key($c);

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

    # Sends the api key to the R server
    $r->get ('/api_key' => sub ($c) {
        state $already_checked = 0;
        return $c->render(json => undef)
            if $already_checked;
        #  could track the count, but we only really need a boolean
        $already_checked = 1;
        return $c->render(json => $api_key);
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

    # Check if the api_key sent with the call is the same as api_key stored.
    #  Returns true on match.
    sub is_valid_api_key ($c, @rest) {
        my $sent_api_key = $c->req->headers->header('api_key') // 1;

        return $sent_api_key eq ($api_key // 2);
    }

    sub analysis_call ($c, $method){
        #  drop calls with invalid api key
        return $c->render(json => undef)
            if !is_valid_api_key($c);

        my $analysis_params = $c->req->json;

        $log->debug("Analysis parameters are:");
        $log->debug(np ($analysis_params));
        $log->debug("About to call $method");

        return error_as_json($c,
            ('analysis_params must be a hash structure, got '
                . reftype($analysis_params)))
            if !is_hashref ($analysis_params);

        my $result = eval {
            BiodiverseR::BaseData->$method ($analysis_params);
        };
        my $e = $@;
        return error_as_json($c, "Failed to get analysis results\n$e")
            if $e;

        return success_as_json($c, $result);
    }

}


1;
