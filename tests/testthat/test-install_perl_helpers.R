test_that("Perl installation helpers are available", {
  source(file.path("R", "install_perl_on_windows.R"))
  source(file.path("R", "install_perl_on_mac.R"))

  expect_true(exists("init_perlbrewr"))
  expect_true(exists("install_perl_deps"))
  expect_true(exists("install_strawberry_perl"))
  expect_true(exists("init_strawberry_perl"))
})
