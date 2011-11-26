package Slic3r::Surface;
use Moo;

has 'contour' => (
    is          => 'ro',
    #isa         => 'Slic3r::Polyline::Closed',
    required    => 1,
);

has 'holes' => (
    traits  => ['Array'],
    is      => 'rw',
    #isa     => 'ArrayRef[Slic3r::Polyline::Closed]',
    default => sub { [] },
);

has 'surface_type' => (
    is      => 'rw',
    #isa     => enum([qw(internal internal-solid bottom top)]),
);

# this integer represents the thickness of the surface expressed in layers
has 'depth_layers' => (is => 'ro', default => sub {1});

has 'bridge_angle' => (is => 'ro');

sub cast_from_polygon {
    my $class = shift;
    my ($polygon, %args) = @_;
    
    return $class->new(
        contour      => Slic3r::Polyline::Closed->cast($polygon),
        %args,
    );
}

sub cast_from_expolygon {
    my $class = shift;
    my ($expolygon, %args) = @_;
    
    if (ref $expolygon eq 'HASH') {
        $expolygon = Slic3r::ExPolygon->new($expolygon);
    }
    
    return $class->new(
        contour => $expolygon->contour->closed_polyline,
        holes   => [ map $_->closed_polyline, $expolygon->holes ],
        %args,
    );
}

# static method to group surfaces having same surface_type, bridge_angle and depth_layers
sub group {
    my $class = shift;
    my $params = ref $_[0] eq 'HASH' ? shift(@_) : {};
    my (@surfaces) = @_;
    
    my $unique_type = sub {
        ($params->{merge_solid} && $_[0]->surface_type =~ /top|bottom|solid/
            ? 'solid' : $_[0]->surface_type) . "_" . ($_[0]->bridge_angle || '')
            . "_" . $_[0]->depth_layers;
    };
    my @unique_types = ();
    foreach my $surface (@surfaces) {
        my $type = $unique_type->($surface);
        push @unique_types, $type unless grep $_ eq $type, @unique_types;
    }
    
    my @groups = ();
    foreach my $type (@unique_types) {
        push @groups, [ grep { $unique_type->($_) eq $type } @surfaces ];
    }
    return @groups;
}

sub add_hole {
    my $self = shift;
    my ($hole) = @_;
    
    push @{ $self->holes }, $hole;
}

sub id {
    my $self = shift;
    return $self->contour->id;
}

sub encloses_point {
    my $self = shift;
    my ($point) = @_;
    
    return 0 if !$self->contour->encloses_point($point);
    return 0 if grep $_->encloses_point($point), @{ $self->holes };
    return 1;
}

sub clipper_polygon {
    my $self = shift;
    
    return {
        outer => $self->contour->p,
        holes => [
            map $_->p, @{$self->holes}
        ],
    };
}

sub p {
    my $self = shift;
    return ($self->contour->p, map $_->p, @{$self->holes});
}

sub expolygon {
    my $self = shift;
    return Slic3r::ExPolygon->new($self->contour->p, map $_->p, @{$self->holes});
}

sub lines {
    my $self = shift;
    return @{ $self->contour->lines }, map @{ $_->lines }, @{ $self->holes };
}

1;
