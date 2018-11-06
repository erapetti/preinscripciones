use strict;
use utf8;

package alumno;

sub new {
  my $class = shift;
  my ($ci, $opc1, $opc2, $opc3, $deft, $vulnerabilidad, $tipodoc, $paisdoc, $tag) = @_;

  my $self = bless {}, $class;

  $self->{ci} = $ci;
  $self->{opc1} = $opc1;
  $self->{opc2} = $opc2;
  $self->{opc3} = $opc3;
  $self->{deft} = $deft;
  $self->{vulnerabilidad} = $vulnerabilidad;
  $self->{tipodoc} = $tipodoc;
  $self->{paisdoc} = $paisdoc;
  $self->{tag} = $tag;

  return $self;
}

sub ci {
  my $self = shift;

  return $self->{ci};
}

sub opcion {
  my $self = shift;
  my ($opc) = @_;

  return ($opc == 0 ? $self->{opc1} : ($opc == 1 ? $self->{opc2} : ($opc == 2 ? $self->{opc3} : ($opc == 3 ? $self->{deft} : undef))));
}

sub predeterminada {
  my $self = shift;

  return $self->{deft};
}

sub vulnerabilidad {
  my $self = shift;

  return $self->{vulnerabilidad};
}

sub tipodoc {
  my $self = shift;

  return $self->{tipodoc};
}

sub paisdoc {
  my $self = shift;

  return $self->{paisdoc};
}

sub tag {
  my $self = shift;

  return $self->{tag};
}

1;
