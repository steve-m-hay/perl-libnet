##
## Package to read/write on ASCII data connections
##

package Net::FTP::A;

use vars qw(@ISA $buf);
use Carp;

require Net::FTP::dataconn;

@ISA = qw(Net::FTP::dataconn);

sub read
{
 my    $data 	= shift;
 local *buf 	= \$_[0]; shift;
 my    $size 	= shift || croak 'read($buf,$size,[$offset])';
 my    $offset 	= shift || 0;
 my    $timeout = $data->timeout;

 croak "Bad offset"
	if($offset < 0);

 $offset = length $buf
	if($offset > length $buf);

 ${*$data} ||= "";
 my $l = 0;

 READ:
  {
   $data->can_read($timeout) or
	croak "Timeout";

   my $n = sysread($data, ${*$data}, $size, length ${*$data});

   return $n
	unless($n >= 0);

   ${*$data} =~ s/(\015)?(?!\012)\Z//so;
   my $lf = $1 || "";

   ${*$data} =~ s/\015\012/\n/sgo;

   substr($buf,$offset) = ${*$data};

   $l += length(${*$data});
   $offset += length(${*$data});

   ${*$data} = $lf;
   
   redo READ
     if($l == 0 && $n > 0);

   if($n == 0 && $l == 0)
    {
     substr($buf,$offset) = ${*$data};
     ${*$data} = "";
    }
  }

 return $l;
}

sub write
{
 my    $data 	= shift;
 local *buf 	= \$_[0]; shift;
 my    $size 	= shift || croak 'write($buf,$size,[$timeout])';
 my    $timeout = @_ ? shift : $data->timeout;

 $data->can_write($timeout) or
	croak "Timeout";

 # What is previous pkt ended in \015 or not ??

 my $tmp;
 ($tmp = $buf) =~ s/(?!\015)\012/\015\012/sg;

 # If the remote server has closed the connection we will be signal'd
 # when we write. This can happen if the disk on the remote server fills up

 local $SIG{PIPE} = 'IGNORE';

 my $len = $size + length($tmp) - length($buf);
 my $wrote = syswrite($data, $tmp, $len);

 if($wrote > 0)
  {
   $wrote = $wrote == $len ? $size
			   : $len - $wrote
  }

 return $wrote;
}

1;