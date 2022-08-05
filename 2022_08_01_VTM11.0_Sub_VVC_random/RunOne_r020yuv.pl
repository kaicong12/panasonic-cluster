#!/usr/bin/perl

use strict;

use File::Copy;
use Cwd;
my $Cwd = cwd();

#print "\ncwd_local   = $Cwd\n"; #haiwei, debug

my $opt_v = 0;

$opt_v and print "cwd = $Cwd\n";

my $opt_use_tmpdir = 1;

# my $opt_add = "-dqd 1 -aq 1 -aqr 12";

my $opt_add = "";

#####
sub mysystem
{
    my($aa) = @_;
    
    $opt_v and print "sys> $aa\n";
    system $aa;
}
sub mycopy
{
    print "copy> @_\n";
    copy (@_);
}

#####

# first argument sepecify 8bit or 10bit
# 2nd argument is a flag to indicate whether to run encoding and decoding.
#   0: no operation
#   1: encoding only
#   2: decoding only
#   3: both encoding and decoding
# 3rd argument and 3rd argument are to be a path of decoder and decoder
# other arguments are additional information may be used
#

my($yuv_out, $csApartNum, $command, $decbin, $encbin, $outputfolder, $task_name, @more) = @ARGV;

my $do_enc=0; 
my $do_dec=0;

if   ($command == 1){ $do_enc = 1;              }
elsif($command == 2){              $do_dec = 1; }
elsif($command == 3){ $do_enc = 1; $do_dec = 1; }

$opt_v and print "command = $command, do_enc = $do_enc, do_dec = $do_dec\n";
$opt_v and print "decbin = $decbin\n";
$opt_v and print "encdin = $encbin\n";
$opt_v and print "more   = @more\n";

my $mode = 2;

my $common_fname;
my $log_fname;
my $bin_fname;
my $rec_fname;
my $dec_fname;
my $cfg_fname;

foreach my $x(@more)
{
    if($x =~ /.bin$/)
    {
        $bin_fname = $x;
        $common_fname = $x;
        $common_fname =~ s/.bin$//;
        $log_fname = $common_fname . ".log";
        $rec_fname = $common_fname . "_rec.yuv";
        $dec_fname = $common_fname . ".yuv";
        $cfg_fname = $common_fname . ".cfg";
    }
}


## temporally filename is defined based on localhostname, process id ($$) and random number.
use Sys::Hostname;
my $hostname = hostname();
my $pid = $$;
srand(time ^ ($pid + ($pid << 15)));
my $rr = int(rand(100000));
my $x = $common_fname; $x =~ s|/|_|mg;

my $tmp_common_dir;
my $tmp_common_fname;

$tmp_common_dir   = "/tmp/tmp_${hostname}_${pid}_${rr}_${x}";
$tmp_common_fname = "/tmp/tmp_${hostname}_${pid}_${rr}_${x}";

if($opt_use_tmpdir)
{
    $tmp_common_dir   = "/tmp/tmp_${hostname}_${pid}_${rr}_${x}";
    $tmp_common_fname = "/tmp/tmp_${hostname}_${pid}_${rr}_${x}/";
    
    mkdir $tmp_common_dir;
    chdir $tmp_common_dir;
    my $cwd_2 = cwd();
    $opt_v and print "cwd_2 = $cwd_2\n";

}
else
{
    $tmp_common_dir   = "";
    $tmp_common_fname = "/tmp/tmp_${hostname}_${pid}_${rr}_${x}";
}



$opt_v and print "tmp_common_fname = ${tmp_common_fname}\n";





#print "log_fname = $log_fname\n";



if($do_enc)
{
    my $local_rec_fname = "${tmp_common_fname}.rec.yuv";
    my $com;

#        $com = "$encbin -c $cfg_fname $opt_add -b $bin_fname  --SEIDecodedPictureHash=1  >> $log_fname";                      # encodeのYUVはサーバへ出力。（IO負荷＝中。最大20~40並列が限度。数値は要精査）
#        $com = "$encbin -c $cfg_fname $opt_add -b $bin_fname  --SEIDecodedPictureHash=1  >> $log_fname";                                          # encodeのYUVファイルは config記載の場所へ出力。/home/shibahara へ出る場合もある
        $com = "$encbin -c $cfg_fname $opt_add -b $bin_fname  --SEIDecodedPictureHash=1 --PrintHexPSNR >> $log_fname";                      # encodeのYUVはローカルへ出力。Encode後削除。   


    open  L, ">${log_fname}";
    print L "$com\n";
    print L "hostname=$hostname\n";
    close L;

    mysystem ($com);

    unlink "$local_rec_fname"; 
    
}

if($do_dec and (-s $bin_fname > 0))
{
    my $com;
    if ($yuv_out==2){
    	$dec_fname = "${tmp_common_fname}dec.yuv";						# decodeのYUVはローカルへ出力。（IO負荷＝小） Decode後削除。
    }elsif($yuv_out==1){
    	$dec_fname = "${outputfolder}/DecoderLOG/${task_name}.yuv";		# decodeのYUVはサーバへ出力。（IO負荷＝大）
    }
#    print "$dec_fname\n";
    if ($yuv_out==0){
    $com = "$decbin -b $bin_fname >> ${outputfolder}/DecoderLOG/${task_name}.log";    # decodeのYUVはローカルへ出力。cleaningにて削除. 
	}elsif($csApartNum ==0 ){
	$com = "$decbin -b $bin_fname -d 8 -o $dec_fname >> ${outputfolder}/DecoderLOG/${task_name}.log";    # 10bit出力
    }else{
    $com = "$decbin -b $bin_fname -d 10 -o $dec_fname >> ${outputfolder}/DecoderLOG/${task_name}.log";    # 8bit出力
    }       

    open  L, ">${outputfolder}/DecoderLOG/${task_name}.log";
    print L "$com\n";
    print L "hostname=$hostname\n";    
    close L;

    mysystem ($com);
    
    unlink "${tmp_common_fname}.yuv";
    unlink "${tmp_common_fname}_dec.log";

        -f "TraceDec.txt" and mysystem("mv TraceDec.txt ${common_fname}_TraceDec.txt"); # TraceDec.txtをローカルへ移動

    if($yuv_out==1){
    	my $MD5_fname = $dec_fname . ".md5";
    	my $md5_com = `md5sum $dec_fname`;
    	my @md5_out = split(/\s+/, $md5_com);
		open (FILE, ">", $MD5_fname) or die "$!";
		print FILE $md5_out[0];
		close (FILE);
	}
}

if($opt_use_tmpdir)
{
    my $com = "rm -rf $tmp_common_dir";
    mysystem ($com);    
}
