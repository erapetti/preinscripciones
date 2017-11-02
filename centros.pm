use strict;
use utf8;

package centros;


sub new {
  my $class = shift;

  my $self = bless {}, $class;
  return $self;
}

# inicializa reserva y total en {cupos}
sub load_reserva {
  my $self = shift;
  my ($filename) = @_;

  if (!defined($self->{cupos})) {
    print "ERROR: load_reserva: Se requiere que los cupos estén cargados previamente\n";
    exit(1);
  }

	open(RESERVA,"<:utf8",$filename);
	while(<RESERVA>) {
    next if (/^#/);
		s/"//g;
		chop();
		@_ = split('\t');

    ($::soloCES) and next if ($_[0] =~ /-.*-/); # es CETP

    if (!defined($self->{cupos}{$_[0]})) {
      next if ($_[4] eq '0');
      print "ERROR: load_reserva: No existe el cupo para el centro $_[0] que tiene reserva definida\n";
      exit(1);
    }
    if (defined($self->{cupos}{$_[0]}{reserva}) && $self->{cupos}{$_[0]}{reserva}>0) {
      print "ERROR: load_reserva: Centro $_[0] repetido en $filename\n";
      exit(1);
    }
    $self->{cupos}{$_[0]}{reserva} = $_[4];
    $self->{cupos}{$_[0]}{total} = $self->{cupos}{$_[0]}{cupo} - $self->{cupos}{$_[0]}{reserva};
    if ($self->{cupos}{$_[0]}{total} < 0) {
      print "ATENCIÓN: load_reserva: El centro $_[0] ya empieza con ".$self->{cupos}{$_[0]}{total}." lugares libres porque tiene cupo para ".$self->{cupos}{$_[0]}{cupo}." y los lugares reservados son ".$self->{cupos}{$_[0]}{reserva}."\n";
    }
	}
	close(RESERVA);

}

# inicializa apg, grupos y cupo en {cupos}. También crea {alumnos}
sub load_cupos {
  my $self = shift;
  my ($filename) = @_;

  $self->{cupos} = {};

	open(CUPOS,"<:utf8",$filename);
	while(<CUPOS>) {
    next if (/^#/);
    next if (/^\s*$/);
    if (/,/) {
      print "load_cupos: Se encontraron comas en el archivo $filename y las cifras decimales hay que separarlas por puntos\n";
      exit(1);
    }
		s/"//g;
		chop();
		@_ = split('\t');

    ($::soloCES) and next if ($_[0] =~ /-.*-/); # es CETP

    if (!defined($self->{cupos}{$_[0]})) {
      # primera vez que aparece este centro en el archivo
      $self->{cupos}{$_[0]} = {apg=>$_[1], grupos=>$_[2], cupo=>$_[1]*$_[2], reserva=>0, total=>$_[1]*$_[2]};
      $self->{alumnos}{$_[0]} = {};
    } elsif ($_[2] > 0) {
      # acumulo los valores con lo que ya tenía
      $self->{cupos}{$_[0]}{grupos} += $_[2];
      $self->{cupos}{$_[0]}{cupo} += $_[1]*$_[2];
      $self->{cupos}{$_[0]}{apg} = $self->{cupos}{$_[0]}{cupo} / $self->{cupos}{$_[0]}{grupos};
      $self->{cupos}{$_[0]}{reserva} = 0; # nop
      $self->{cupos}{$_[0]}{total}  = $self->{cupos}{$_[0]}{cupo} - 0;
    }
	}
	close(CUPOS);

  # redondeo los decimales
  foreach $_ (keys %{$self->{cupos}}) {
    $self->{cupos}{$_}{cupo} = int($self->{cupos}{$_}{cupo});
  }
}

sub load_depto {
  my $self = shift;
  my ($filename) = @_;

  $self->{depto} = {};

  open(DEPTO,"<:utf8",$filename);
  while(<DEPTO>) {
    next if (/^#/);
    chop();
    @_ = split('\t');

    $self->{depto}{$_[0]} = $_[1];
  }
  close(DEPTO);
}

sub cupos {
  my $self = shift;
  my ($dependid) = @_;

  if (!defined($self->{cupos}{$dependid})) {
    print "ERROR:cupos: No está definido el cupo para el centro $dependid\n";
    exit(1);
  }
  return $self->{cupos}{$dependid}{cupo};
}

sub reserva {
  my $self = shift;
  my ($dependid) = @_;

  if (!defined($self->{cupos}{$dependid})) {
    print "ERROR:cupos: No está definido el cupo para el centro $dependid\n";
    exit(1);
  }
  return $self->{cupos}{$dependid}{reserva};
}

sub apg {
  my $self = shift;
  my ($dependid) = @_;

  if (!defined($self->{cupos}{$dependid})) {
    print "ERROR:apg: No está definido el cupo para el centro $dependid\n";
    exit(1);
  }
  return $self->{cupos}{$dependid}{apg};
}

sub grupos {
  my $self = shift;
  my ($dependid) = @_;

  if (!defined($self->{cupos}{$dependid})) {
    print "ERROR:grupos: No está definido el cupo para el centro $dependid\n";
    $self->{cupos}{$dependid} = {apg=>30, grupos=>100, cupo=>3000, reserva=>0, total=>3000};
    $self->{alumnos}{$dependid} = {};
    #exit(1);
  }
  return $self->{cupos}{$dependid}{grupos};
}

sub alumnos {
  my $self = shift;
  my ($dependid) = @_;

  if (!defined($self->{alumnos}{$dependid})) {
    print "ERROR:alumnos: No está definido el cupo para el centro $dependid\n";
    exit(1);
  }
  return $self->{alumnos}{$dependid};
}

sub libres {
  my $self = shift;
  my ($dependid) = @_;

  if (!defined($dependid)) {
    print "ERROR:libres: No se especificó centro: $dependid\n";
    exit(1);
  }
  if (!defined($self->{cupos}{$dependid})) {
    print "ERROR:libres: No está definido el cupo para el centro $dependid\n";
$self->{cupos}{$dependid} = {apg=>30, grupos=>100, cupo=>3000, reserva=>0, total=>3000};
$self->{alumnos}{$dependid} = {};
    #exit(1);
  }
  return int($self->{cupos}{$dependid}{total}) - (keys %{$self->{alumnos}{$dependid}});
}

sub asignar {
  my $self = shift;
  my ($ci,$dependid) = @_;

  if (!defined($self->{cupos}{$dependid})) {
    print "ERROR:asignar: No puedo asignar $ci a $dependid porque no tiene cupo definido\n";
    exit(1);
  }
  $self->{alumnos}{$dependid}{$ci} = 1;
}

sub mover {
  my $self = shift;
  my ($ci,$dependid_origen,$dependid_destino) = @_;

  if (!defined($self->{alumnos}{$dependid_origen}{$ci})) {
    print "ERROR: No puedo mover $ci desde $dependid_origen porque no está asignado a ese centro\n";
    exit(1);
  }
  delete $self->{alumnos}{$dependid_origen}{$ci};
  $self->asignar($ci,$dependid_destino);
}

sub centros {
  my $self = shift;
  return keys %{$self->{cupos}};
}

sub sobrecupos {
	my $self = shift;
	my @sobrecupos;

	foreach my $dependid (sort {$self->libres($a) <=> $self->libres($b)} $self->centros) {
		if ($self->libres($dependid) < 0) {
			push @sobrecupos, $dependid;
		} else {
      last;
    }
	}
	return @sobrecupos;
}

sub evaluar {
	my $self = shift;

	my $puntaje = 0;

  foreach my $dependid ($self->centros) {
    if ($self->libres($dependid) < 0) {
      return -1;
    } else {
      if ($self->{cupos}{$dependid}{grupos} == 0) {
        print "ERROR:evaluar: El centro $dependid no tiene grupos\n";
        exit(1);
      }
      my $apg = (keys %{$self->{alumnos}{$dependid}}) / $self->{cupos}{$dependid}{grupos};
      $puntaje += ($apg - $self->{cupos}{$dependid}{apg}) ** 2;
    }
  }

	return $puntaje;
}

sub depto {
  my $self = shift;
  my ($dependid) = @_;

  if (!defined($self->{depto}{$dependid})) {
    print "ERROR: nrodepto: no se encuentra el departamento del centro $dependid\n";
    exit(1);
  }
  return $self->{depto}{$dependid};
}


%::nrodepto = (
  'ARTIGAS'=>1, 'CANELONES'=>2, 'CERRO LARGO'=>3, 'COLONIA'=>4,'DURAZNO'=>5,
  'FLORES'=>6,'FLORIDA'=>7,'LAVALLEJA'=>8,'MALDONADO'=>9,'MONTEVIDEO'=>10,
  'PAYSANDU'=>11,'RIO NEGRO'=>12,'RIVERA'=>13,'ROCHA'=>14,'SALTO'=>15,
  'SAN JOSE'=>16,'SORIANO'=>17,'TACUAREMBO'=>18,'TREINTA Y TRES'=>19
);

sub nrodepto {
  my $self = shift;
	my ($dependid) = @_;

  if (!defined($self->{depto}{$dependid})) {
    print "ERROR: nrodepto: no se encuentra el departamento del centro $dependid\n";
    exit(1);
  }
  if (!defined($::nrodepto{$self->{depto}{$dependid}})) {
    print "ERROR: nrodepto: no se encuentra el número del departamento ".$self->{depto}{$dependid}."\n";
    exit(1);
  }
	return $::nrodepto{$self->{depto}{$dependid}};
}

sub depend2number {
  my $self = shift;
	my ($dependid) = @_;

	if (!defined($dependid)) {
		print "ERROR: depend2number: dependid sin definir\n";
		exit(1);
	}
	$dependid =~ /^(\d+(?:-\d+)?)(?:-(\d+)-([\d]+)\w*-(\d+))?$/ || print "ERROR: número de dependencia incorrecto $dependid\n";
	(defined($1)) || print "ERROR: formato incorrecto: $dependid\n";

	return sprintf "%02d%05d%05d%05d%05d",$self->nrodepto($dependid),$1,(defined($2) ? $2 : 0),(defined($3) ? $3 : 0),(defined($4) ? $4 : 0);
}

1;
