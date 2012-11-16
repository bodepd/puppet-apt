class apt::update {
  include apt::params

  exec { 'apt_update':
    command     => "${apt::params::provider} update",
    logoutput   => 'on_failure',
    refreshonly => true,
  }

  # After updating the package list we may or may not want to update packages that
  # we've already installed
  Exec["apt_update"] -> Package <| |>
}
