package Gestinanna::ContentProvider::Document;

use base qw(Gestinanna::ContentProvider);

use Time::Local ();

sub content {
    my $self = shift;

    if($self -> {content}) {
        my $data = $self -> {content} -> data;
        return \$data;
    }
    return;
}

sub mtime {
    my $self = shift;

    return $self -> {mtime} if defined $self -> {mtime};

    my $ts = $self -> {content} -> modify_timestamp;

    my($year, $month, $day, $hour, $minute, $second) = $ts =~ m{^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$};

    return $self -> {mtime} = Time::Local::timegm($second, $minute, $hour, $day, $month, $year - 1900);
}

1;

__END__
