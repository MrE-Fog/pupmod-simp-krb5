# @summary Distribute Kerberos keytabs in a sane manner
#
# Users should feel free to do what they like, but this will be consistent
#
# @param keytab_source
#   The `File` resource compatible source for the system keytab
#
# @param owner
#   The keytab file owner
#
# @param group
#   The keytab file group
#
# @param mode
#   The keytab file mode
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class krb5::keytab (
  $keytab_source = "puppet:///modules/krb5_files/keytabs/${facts['networking']['fqdn']}",
  $owner         = 'root',
  $group         = 'root',
  $mode          = '0400'
){

  file { '/etc/krb5_keytabs':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    source  => $keytab_source,
    recurse => true
  }

  file { '/etc/krb5.keytab':
    ensure  => 'file',
    owner   => $owner,
    group   => $group,
    mode    => $mode,
    source  => 'file:///etc/krb5_keytabs/krb5.keytab',
    require => File['/etc/krb5_keytabs']
  }
}
