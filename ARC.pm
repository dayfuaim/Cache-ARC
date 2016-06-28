package Cache::ARC;
use strict;
use warnings;
use Storable qw/dclone freeze thaw/;
use DDP;
# use List::DoubleLinked;
# use Data::Dumper;

sub new {
	my ($class, $size) = @_;
	die('gimme size (>= 10) as a single argument')
		if (!$size || $size !~ /^\d+$/ || $size < 10);

	my $self = {};
	bless($self, $class);
	print "--> Size: $size\n";
	return $self->_init($size)
}

sub _init {
	my ($self, $size) = @_;
	$self->{'size'}     = $size;    # c
	$self->{DATA} = {}; # Hash for data
	$self->{'L1'} = [];           # L1 list = T1 . B1
	$#{$self->{'L1'}} = 3*$size/2-1;           # L1 list = T1 . B1
	$self->{'L2'} = [];           # L2 list = T2 . B2
	$#{$self->{'L2'}} = 3*$size/2-1;           # L1 list = T1 . B1
	$self->{'^'}        = 0;            # negative == T1, positive == T2
	$self->{'!'}        = 0;
	$self->{i} = { L1 => {}, L2 => {} }; # hash for keys' indices
	return $self
}

my $_descr = <<EOT;
T1, for recent cache entries.
T2, for frequent entries, referenced at least twice.
B1, ghost entries recently evicted from the T1 cache, but are still tracked.
B2, similar ghost entries, but evicted from T2.
T1 and B1 together are referred to as L1, a combined history of recent single references. Similarly, L2 is the combination of T2 and B2.

. . . [   B1  <-[     T1    <-!->      T2   ]->  B2   ] . .
      [ . . . . [ . . . . . . ! . .^. . . . ] . . . . ]
                [   fixed cache size (c)    ]

L1 is now displayed from right to left, starting at the top, indicated by the ! marker. ^ indicates the target size for T1, and may be equal to, smaller than, or larger than the actual size (as indicated by !).

New entries enter T1, to the left of !, and are gradually pushed to the left, eventually being evicted from T1 into B1, and finally dropped out altogether.
Any entry in L1 that gets referenced once more, gets another chance, and enters L2, just to the right of the central ! marker. From there, it is again pushed outward, from T2 into B2. Entries in L2 that get another hit can repeat this indefinitely, until they finally drop out on the far right of B2.

Entries (re-)entering the cache (T1,T2) will cause ! to move towards the target marker ^. If no free space exists in the cache, this marker also determines whether either T1 or T2 will evict an entry.

Hits in B1 will increase the size of T1, pushing ^ to the right. The last entry in T2 is evicted into B2.
Hits in B2 will shrink T1, pushing ^ back to the left. The last entry in T1 is now evicted into B1.
A cache miss will not affect ^, but the ! boundary will move closer to ^.
EOT

sub set {
	my ($self, $key, $val) = @_;
	die "No KEY given!" unless $key;
	# print "SET>>> $key\n";
	$self->{DATA}{$key} = $val;
	$self->_insert('L1', $key);
	$self->{'!'} += _sign($self->{'^'});
	return $key;
}

sub get {
	my ($self, $key) = @_;
	die "No KEY given!" unless $key;
	my $hit;

	# (B1, T1) -> $hit
	$hit = $self->_remove('L1', $key);
	if ($hit) {
		push @{$self->{L1}}, undef;
		$self->{'^'}++
	}

	# $hit -> (T2, B2)
	unless ($hit) {
		$hit = $self->_remove('L2', $key);
		if ($hit) {
			$self->{'^'}--
		}
	}

	if ($hit) {
		$self->_insert('L2', $hit)
	} else {
		push @{$self->{L2}}, undef;
		$self->{'!'} += _sign($self->{'^'});
		return
	}
	# print "OK \n";
	return $self->{DATA}->{$key}
}

sub _insert {
	my ($self, $list, $key) = @_;
	my $remove = pop @{$self->{$list}};
	if (defined $remove) {
		delete $self->{i}{$list}{$remove};
		delete $self->{DATA}{$remove};
	}
	$self->{i}{$list}{$_}++ foreach keys %{$self->{i}{$list}};
	unshift @{$self->{$list}}, $key;
	$self->{i}{$list}{$key} = 0;
	return
}

sub _remove {
	my ($self, $list, $key) = @_;
	my ($hit, $ind) = (undef, -1);
	$ind = $self->{i}{$list}{$key} if exists $self->{i}{$list}{$key};
	if ($ind != -1) {
		$hit = splice(@{$self->{$list}}, $ind, 1);
		delete $self->{i}{$list}{$hit};
		foreach my $k (keys %{$self->{i}{$list}}) {
			next if $self->{i}{$list}{$k} < $ind;
			$self->{i}{$list}{$k}--
		}
	}
	return $hit
}

sub dump {
	my ($self) = @_;
	return freeze($self);
}

sub load {
	my ($class, $dump) = @_;
	die('hey, gimme dump') unless ($dump);
	my $self = thaw($dump);
	return $self;
}

sub _sign {
	return ($_ < 0 ? -1 : ($_ > 0 ? 1 : 0));
}

1;
