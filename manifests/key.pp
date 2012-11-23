define apt::key (
  $key = $title,
  $ensure = present,
  $key_content = false,
  $key_source = false,
  $key_server = 'keyserver.ubuntu.com',
  $proxy = false,
) {

  include apt::params

  $upkey = upcase($key)

  if $key_content {
    $method = 'content'
  } elsif $key_source {
    $method = 'source'
  } elsif $key_server {
    $method = 'server'
  } else {
    fail("Unknown method")
   }

  # This is a hash of the parts of the key definition that we care about.
  # It is used as a unique identifier for this instance of apt::key. It gets
  # hashed to ensure that the resource name doesn't end up being pages and
  # pages (e.g. in the situation where key_content is specified).
  $digest = sha1("${upkey}/${key_content}/${key_source}/${key_server}/")

  # Allow multiple ensure => present for the same key to account for many
  # apt::source resources that all reference the same key.
  case $ensure {
    present: {

      anchor { "apt::key/${title}": }

      if defined(Exec["apt::key ${upkey} absent"]) {
        fail("Cannot ensure Apt::Key[${upkey}] present; ${upkey} already ensured absent")
      }

      if !defined(Anchor["apt::key ${upkey} present"]) {
        anchor { "apt::key ${upkey} present": }
      }

       if $proxy {
          $proxy_pfx="env http_proxy=${proxy} https_proxy=${proxy} "
      } else {
          $proxy_pfx=""
      }

      if !defined(Exec[$digest]) {
        $digest_command = $method ? {
          'content' => "echo '${key_content}' | /usr/bin/apt-key add -",
          'source'  => "${proxy_pfx}wget -q '${key_source}' -O- | apt-key add -",
          'server'  => "${proxy_pfx}apt-key adv --keyserver '${key_server}' --recv-keys '${upkey}'",
        }
        exec { $digest:
          command   => $digest_command,
          path      => '/bin:/usr/bin',
          unless    => "/usr/bin/apt-key list | /bin/grep `/bin/echo ${upkey} | /bin/sed -e 's/.*\\(........\\)$/\\1/' `",
          logoutput => 'on_failure',
          before    => Anchor["apt::key ${upkey} present"],
        }
      }

      Anchor["apt::key ${upkey} present"] -> Anchor["apt::key/${title}"]

    }
    absent: {

      if defined(Anchor["apt::key ${upkey} present"]) {
        fail("Cannot ensure Apt::Key[${upkey}] absent; ${upkey} already ensured present")
      }

      exec { "apt::key ${upkey} absent":
        command   => "apt-key del '${upkey}'",
        path      => '/bin:/usr/bin',
        onlyif    => "apt-key list | grep '${upkey}'",
        user      => 'root',
        group     => 'root',
        logoutput => 'on_failure',
      }
    }

    default: {
      fail "Invalid 'ensure' value '${ensure}' for aptkey"
    }
  }
}
