#' Initialise a version of strawberry perl to run the server
#'
#' @examples
#' if(interactive()) {
#'   init_strawberry_perl()
#' }
init_strawberry_perl = function () {
  appdata = Sys.getenv('APPDATA')

  bd_path    = fs::path (appdata, 'BiodiverseR')
  extract_to = fs::dir_create (bd_path, 'sp5380')

  #  hard coded is suboptimal
  sp_url = 'https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_5380_5361/strawberry-perl-5.38.0.1-64bit-PDL.zip'
  sp_zip = fs::path(bd_path, 'strawberry-perl-5.38.0.1-64bit-PDL.zip')


  if (!fs::dir_exists (extract_to)) {
    fs::dir_create(extract_to)
  }

  oldtimeout = options()$timeout
  if (!fs::file_exists(sp_zip)) {
    tryCatch ({
      options (timeout = 180)
      #utils::download.file (sp_url, sp_zip)
      
      # httr::GET(sp_url, httr::write_disk(sp_zip, overwrite=TRUE))
      # utils::unzip (sp_zip, exdir = extract_to)

      req <- httr2::request(sp_url)
      response <- httr2::req_perform(req, sp_zip)
      utils::unzip (sp_zip, exdir = extract_to)

      options(timeout = oldtimeout)
    },
    error=function(err){
      message(paste("Issues downloading strawberry perl, possible timeout:  ", err))
      unlink(sp_zip)
      options(timeout = oldtimeout)
      stop()
    }
    )
  }

  old_path = Sys.getenv('PATH')
  old_wd = getwd()
  tryCatch ( {

      p <- Sys.getenv("PATH") |> strsplit(";") |> unlist() |> fs::path()
      #p <- p[!grepl("rtools", p)]
      p <- grep (pattern="rtools", p, invert=TRUE, value=TRUE)
      p <- c(
        fs::path (extract_to, c("c/bin", "perl/site/bin", "perl/bin")),
        unlist (p)
      )
      Sys.setenv(PATH = paste(p, collapse=";"))
      #paste(p, collapse=";")
      Sys.setenv(PERL_CPANM_HOME = fs::path(extract_to, "data"))
      #system ("where cpanm")
      system ("cpanm -v --notest Win32::LongPath")  #  test issues under 5.38.0
      bd_git_path = fs::path(bd_path, "biodiverse_git")
      if (!fs::dir_exists(bd_git_path)) {
        system2 (
          "git",
          args = c(
            "clone",
            "--depth", "1",
            "https://github.com/shawnlaffan/biodiverse.git",
            bd_git_path
          )
        )
      }
      setwd (bd_git_path)
      system ("git pull")  #  run regardless
      system ("cpanm --verbose --installdeps .")
      system ("cpanm --verbose .")
      setwd(old_wd)
      setwd (system.file("perl", package ="BiodiverseR"))
      system ("cpanm -v --installdeps .")
      Sys.setenv(PATH = old_path)
      setwd(old_wd)
    },
    error=function(err){
      message(paste("We hit an error:  ", err))
      Sys.setenv(PATH = old_path)
      setwd(old_wd)
      stop()
    },
    #  prob not needed now
    finally = function () {
      Sys.setenv(PATH = old_path)
      setwd(old_wd)
    }
  )


}
