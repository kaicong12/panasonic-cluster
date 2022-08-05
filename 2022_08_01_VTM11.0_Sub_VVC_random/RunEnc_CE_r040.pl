#!/usr/bin/perl

#use strict;
use List::Util qw(min);
# Version: written for JEM7.0

use Class::Struct;
struct Set => {
    Dir     => '$',
    Encoder => '$',
    Decoder => '$',
    Param   => '@',
    misc    => '@', 
};

##################################################################
###############################SETTING############################
# ==Option==
my $opt_encdec = 3;   # 0: nop, 1: enc only, 2: dec only, 3: enc and dec, 4: dec only(bitstream concatenation and decode) 	# bin files are needed for "dec only"

my $opt_nooverwrite         = 1;
my $opt_debug               = 0;
my $opt_debug_config_only   = 0;
my $opt_use_etime           = 0;
my $opt_addlevel            = 1;
my $opt_print_qp            = 0;
my $opt_cfg                 = 0;    # 0:VTM, 1:BMS
my $opt_ClassF_TGM_IBC      = 1;    # 0:IBC=0, 1:IBC=1 in class F and TGM. (for VTM4.0)
my $opt_ClassF_TGM_HashME   = 1;    # 0:HashME=0 && BDPCM=0, 1:HashME=1 && BDPCM=1 in class F and TGM. (for VTM4.0 && VTM5.0)
my $opt_inter_MTS           = 0;    # 0:interMTS off(Normal), 1:interMTS on in All Class. (for CE6)
my $opt_IBC                 = 0;    # 0:none, 1:IBC=1 in All Class. (for CE8)
my $opt_LowQP               = 0;    # 0:LowQP off(Normal), 1:LowQP on (QP=2,7,12,17)

# ==Sequence Set==
my @seq_CE_A1      = (  1,  2,  3 );
my @seq_CE_A2      = (  4,  5,  6 );
my @seq_CE_B       = (  7,  8,  9, 10, 11 );
my @seq_CE_C       = ( 12, 13, 14, 15 );
my @seq_CE_D       = ( 16, 17, 18, 19 );
my @seq_CE_E       = ( 20, 21, 22 );
my @seq_CE_F       = ( 23, 24, 25, 26 );
my @seq_CE_A1_2K   = ( 27, 28, 29);
my @seq_CE_A2_2K   = ( 30, 31, 32);
my @seq_CE_TGM     = ( 33, 34, 35, 36 );

#JY
my @seq_CE_HiEve1     = ( 37, 38, 41, 42, 43, 44, 45, 46, 47, 49 );
my @seq_CE_HiEve2     = ( 39, 40, 48 );

sub SetNew(@_); 

# ==Sequences==
#my @seq_AI=(@seq_CE_C, @seq_CE_D, @seq_CE_A1, @seq_CE_A2, @seq_CE_B, @seq_CE_E, @seq_CE_F, @seq_CE_TGM);   # AI
my @seq_AI=(@seq_CE_HiEve1, @seq_CE_HiEve2);
my @seq_RA=(@seq_CE_C, @seq_CE_D, @seq_CE_A1, @seq_CE_A2, @seq_CE_B,            @seq_CE_F, @seq_CE_TGM);   # RA
my @seq_LD=(@seq_CE_C, @seq_CE_D,                         @seq_CE_B, @seq_CE_E, @seq_CE_F, @seq_CE_TGM);   # LDB, LDP
#my @seq_RA=(@seq_CE_F, @seq_CE_TGM);


# ==Condition==
# M:HM8bit , H:HM10bit, J:JEM10bit / I:All intra, R:Random Access, L:Low Delay B, P:Low Delay P
#JY
my @cstr        = ("JI");
#my @cstr        = ("JR", "JL", "JI");
#my @cstr        = ("JI", "JR", "JL", "JP");

# ==Coding QP==
set_qps();

# ==QP increment frame==
set_qp_inc_frm();

# ==Sequence Minimum Number==
my $sid_min = 1;

# ==Frame Numbers to be Encoded==
#my $nfrm_is = "full";       # Common Test Condition
my $nfrm_is = "short";       # 1sec
#my $nfrm_is = "fns";     # full length coding w/o split sequence using intra period
#my $nfrm_is = 100;

# ==Fast Re-encoding Mode(for QPIncrementFrame)==
my $FastReEnc = 0;  # 0: disable(default:encode all frames) , 1: enable(encode only GOP included QPIncrementFrame)
#my $FastReEnc = 1;  # 0: disable(default:encode all frames) , 1: enable(encode only GOP included QPIncrementFrame)

# ==Output YUV==
my $yuv_out = 0; # 0: no YUV output, 1: YUV output, 2:YUV output(to local disk and remove)
#my $yuv_out = 1; # 0: no YUV output, 1: YUV output(to file server), 2:YUV output(to local disk and remove)

# ==Input File Path==
my $OrgPath = "/home/ubuntu/CTC_yuv/"; #haiwei, client PC

# ==Cfg File Path==
my $CfgPath = "cfg"; #haiwei, server PC @ current path/cfg

# ==Executable file name for bitstream concatenation==
my $Cwd = cwd();
my $ConcatExe = "$Cwd/parcatStatic"; #haiwei, to update for full len, server PC @ current path/cfg

# ==PC usage==
# The configuration file to specify the simulation PCs. Automatically reloaded in about 3 minutes.
my $runenc_cfg = "cfg_pc_work.cfg"; #haiwei, server PC @ current path

# ==Config File Adjustment==
#Class Dependent Parameter Settings [KEY => STR]
#KEY must start with "CDP"

my %ClassDependentParam = (
#  "CDP00_A" => "NumTileColumnsMinus1=1,ColumnWidthArray=30,NumTileRowsMinus1=1,RowHeightArray=20",
);

#Common Parameter Settings [KEY => STR]
#In STR, by using CDP, above ClassDependentParam setting is applied.

my %CommonParam =
(
  "DBF0"   => "LoopFilterDisable=1",
  "SAO0"    => "SAO=0",
  "TSR1"	=> "TemporalSubsampleRatio=1",
  "MSSSIM1"	=> "PrintMSSSIM=1",  
);

# ==Software==
my @set = (
	SetNew("_VTM13.0"),
);


# A new job shall not be started at the PC whose free memory is less than $min_mem_size_MB
my $min_mem_size_MB = 1800;

##################################################################
##################################################################

## global parameters

my %sid2fname;
my %sid2fps;
my %sid2width;
my %sid2height; 
my %sid2nfr;
my %sid2nfr1;
my %sid2nfr2;
my %sid2shortname;
my %sid2level;
my %qp2id;

my %sidqp2etime;    
my %sid2ipr;
my %pc2core_decrement;
my %pc2core;
my %job2etime_per_frame;

my %pc2remain;

my $last_cfg_read_time = 0;
my $cfg_read_interval  = 180;

my $num_core;
my @simpc = ();
my @simpc_rand = ();

my %cs2cfg;

## common setting (assumed not changed frequently)

# M:HM8bit, H:HM10bit, J:JEM10bit
# I:All intra, R:Random Access, L:Low Delay B, P:Low Delay P
if($opt_cfg == 0) # VTM
{
    %cs2cfg = 
                (
                    "MI" => "$CfgPath/encoder_intra_vtm.cfg"          ,
                    "HI" => "$CfgPath/encoder_intra_vtm.cfg"          ,
                    "JI" => "$CfgPath/encoder_intra_vtm.cfg"          ,
                    "MR" => "$CfgPath/encoder_randomaccess_vtm.cfg"   ,
                    "HR" => "$CfgPath/encoder_randomaccess_vtm.cfg"   ,
                    "JR" => "$CfgPath/encoder_randomaccess_vtm.cfg"   ,
                    "ML" => "$CfgPath/encoder_lowdelay_vtm.cfg"       ,
                    "HL" => "$CfgPath/encoder_lowdelay_vtm.cfg"       ,
                    "JL" => "$CfgPath/encoder_lowdelay_vtm.cfg"       ,
                    "MP" => "$CfgPath/encoder_lowdelay_P_vtm.cfg"     ,
                    "HP" => "$CfgPath/encoder_lowdelay_P_vtm.cfg"     ,
                    "JP" => "$CfgPath/encoder_lowdelay_P_vtm.cfg"     ,
                );
}
else
{
    %cs2cfg = 
                (
                    "MI" => "$CfgPath/encoder_intra_bms.cfg"          ,
                    "HI" => "$CfgPath/encoder_intra_bms.cfg"          ,
                    "JI" => "$CfgPath/encoder_intra_bms.cfg"          ,
                    "MR" => "$CfgPath/encoder_randomaccess_bms.cfg"   ,
                    "HR" => "$CfgPath/encoder_randomaccess_bms.cfg"   ,
                    "JR" => "$CfgPath/encoder_randomaccess_bms.cfg"   ,
                    "ML" => "$CfgPath/encoder_lowdelay_bms.cfg"       ,
                    "HL" => "$CfgPath/encoder_lowdelay_bms.cfg"       ,
                    "JL" => "$CfgPath/encoder_lowdelay_bms.cfg"       ,
                    "MP" => "$CfgPath/encoder_lowdelay_P_bms.cfg"     ,
                    "HP" => "$CfgPath/encoder_lowdelay_P_bms.cfg"     ,
                    "JP" => "$CfgPath/encoder_lowdelay_P_bms.cfg"     ,
                );
}

my  %csApart2path =
(
     "M" => "0",
     "H" => "1",
     "J" => "2",
       );

my  %csBpart2path =
(
     "I" => "0",
     "R" => "1",
     "L" => "2",
     "P" => "3",
       );

## sub functions

sub SetNew(@_) 
{ 
    my($x) = Set->new(); 
    
    my($bin, @prmKey) = @_;
        $bin =~ s/^EncoderAppStatic//;
        $bin =~ s/^DecoderAppStatic//;    
        $x->Encoder("EncoderAppStatic$bin"); 
        $x->Decoder("DecoderAppStatic$bin");        
    
    my $dir = "";
    
    my $i=0;
    foreach my $p(@prmKey)
    {
        $x->Param($i, $p); $i++;   
    }

    my @ppp = @{$x->Param()};

    # folder name (bin_p1_p2_p3 style)
    $x->Dir($bin . "_x_" . join("_", @ppp));

    # folder name (p1_p2_p3_bin style)
    $x->Dir(join("_", @ppp) . "x" . $bin );
		
    return $x; 
}



sub GetParamStr
{
    my ($class, @prmKey) = @_;

    my @prmStr;
    foreach my $k(@prmKey)
    {
        my $val;
        if($class=~/[A-Z]/ and $CommonParam{$k} =~ /(CDP.*)/)
        {
            $val = $ClassDependentParam{"$1_$class"};
            (length($val) < 1) and $val = "ERROR: CDP: [$k][$CommonParam{$k}] [$1][$class]\n";
        }
        else
        {
        

            $val = $CommonParam{$k};
            (length($val) < 1) and $val = "ERROR: CMN: key=[$k]\n";            
        }
        push @prmStr, $val;
    }
    return join(",", @prmStr);
}

sub GetPictSizeClass
{
    my $sid = $_[0];
    
    ($sid <= 4) and return "A";
    ($sid <= 8) and return "A"; 
    ($sid <= 13) and return "B";
    ($sid <= 17) and return "C";
    ($sid <= 21) and return "D";
    ($sid <= 24) and return "E";
    ($sid <= 28) and return "F";
    ($sid <= 36) and return "A";
}


sub GetNumJob
{
    my $pcname = shift(@_);
    my $com = "ssh $pcname vmstat 1 2";
    my $com = "ssh $pcname vmstat";    
    my @res;
    $opt_debug or @res = `$com`;
    my $wcnt = -1;
    my $wmem = 0;
    shift(@res); shift(@res);
    
    my $opt_v_cc = 0;
            
    foreach (@res)
    {
        $_ =~ s/^\s+//;
        my(@aaa)=split(/\s+/, $_);
        my $r = $aaa[0];
        my $b = $aaa[1];
		#printf "r=%d, b=%d\n", $r, $b;
        my $cnt = $r + ($b*10);
        $wcnt = ($cnt > $wcnt) ? $cnt : $wcnt;

        my $free  = $aaa[3]/1000;
        my $buff  = $aaa[4]/1000;
        my $cache = $aaa[5]/1000;
        my $mem = $free + $buff + $cache;
        $wmem = ($mem > $wmem) ? $mem : $wmem;
    }   

	$EncDecNum = `ssh $pcname ps auxw | egrep 'EncoderApp|DecoderApp' | grep -v grep | grep '/usr/bin/perl' | wc -l`;
    #$EncNum = `ssh $pcname ps auxw | grep TApp | grep -v grep | grep -v '/usr/bin/perl' | grep -v 'sh -c' | wc -l`;
	#$EncNum = `ssh $pcname -t top n1 | grep TApp | grep -v grep | grep -v perl | grep -v sh | wc -l`;
	#printf "EncDecNum=%d\n", $EncDecNum;
    $wcnt = $EncDecNum;

    if($wmem < $min_mem_size_MB) 
    { 
        $opt_v_cc and print "free memory size is smaller than the min_mem_size\n";
        return 50;
    }
    if($wcnt < 0) { return 50; }
    
    return $wcnt;
}

my $num_core;
my @simpc = ();
sub FreadRunEncCfg
{
    my $curr_time = time();
    if($curr_time < $last_cfg_read_time + $cfg_read_interval){ return; }
    $last_cfg_read_time = $curr_time;

    open C, "$runenc_cfg" or print "run enc cfg file [$runenc_cfg] is not found\n";
    @simpc = ();
    foreach my $x(<C>)
    {
        chomp($x);
        $x =~ s/\n//;
        $x =~ s/\r//;
        $x =~ s/^\s+//;
        $x =~ s/\s+$//;
        if($x =~ /^#/) { next; }    
        if($x =~ /__END__/){ last; }    
        if($x =~ /^\s*$/) { next; }

        
        my @words = split(/\s+/,$x);
        

        my $nc_beg;
        my $nc_end;

	if($words[0] =~ /d(\d+)-d(\d+)/)

        {
            $nc_beg = $1; $nc_end = $2;
        }
        elsif($words[0] =~ /d(\d+)/)
        {
            $nc_beg = $nc_end = $1;
        }

        #print "$nc_beg,$nc_end,$x\n";

        for(my $nn=$nc_beg;$nn<=$nc_end;$nn++)
        {

            my $pc = sprintf "d%02d", $nn;
            push(@simpc, $pc);
            if($words[1] < 0){ $words[1]=0; }
            $pc2core_avail{$pc} = $words[1];
        }
        
        
#        print "pc=$words[0], decrement=$words[1]\n";
        
    }
    close C;
    
    my %simpc_hash; # used for eliminating duplicated
    foreach my $x(@simpc)
    { 
        $simpc_hash{$x} = 1;
    }    
    @simpc = sort keys % simpc_hash;

    
#   sub ConfigureNumberOfCores
    {
        my $n; my $pc;
      
        for($n= 1;$n<=99;$n++) { $pc = sprintf "d%02d", $n; $pc2core{$pc} = 0; }

 
        foreach my $pc (@simpc)
        {
            if($pc2core_avail{$pc}>0){ $pc2core{$pc} = $pc2core_avail{$pc}; }
        }


        if(0)
        {
            print "simpc = ";   
            foreach my $pc (@simpc)
            {
                print "$pc($pc2core{$pc}) ";
            }
            print "\n";
        }
    }

    $num_core=0;
    foreach my $x(@simpc)
    { 
        $num_core += $pc2core{$x}; 
    }    
    
    my @simpc_rand = ();
    
    my @tmp = @simpc;
    while(@tmp)
    {
        my $i = int rand (@tmp);
        push(@simpc_rand, splice(@tmp, $i, 1));
    }
    
    undef %pc2remain;
    foreach my $x(@simpc)
    { 
        $pc2remain{$x} = int(rand(10))/10;
    }    
    $last_cfg_read_time = time();
}

sub ReadDataTable
{
my $data_mode = "image";
foreach my $data (<DATA>)
{
    if($data eq "/---IMAGE---/"){ $data_mode = "image"; next; }
    if($data eq "/---PC---/")   { $data_mode = "pc"   ; next; }
    if($data eq "/---ETIME---/"){ $data_mode = "etime"; next; }
    
    if($data eq "/^#/") { next; }

    if($data_mode eq "image")
    {
        chomp;
        my ($sid, $nfr1, $nfr2, $fname, $short, $level) = split(/\s+/, $data); 
        
        $fname =~ s/\.yuv$//;
        my ($w,$h,$fps) = ($fname =~ /(\d+)x(\d+)_(\d+)/);   
        
        $sid2fname {$sid} = $fname;
        $sid2fps   {$sid} = $fps;
        $sid2width {$sid} = $w;
        $sid2height{$sid} = $h;
        $sid2nfr1  {$sid} = $nfr1;   
        $sid2nfr2  {$sid} = $nfr2;   
        $sid2shortname{$sid} = $short;   
        $sid2level {$sid} = $level;

    
        my $intra_period;
        if   ($fps<=30){ $intra_period = 32; }
        elsif($fps<=60){ $intra_period = 64; }  
        else           { $intra_period = 96; }

        $sid2ipr   {$sid} = $intra_period;   
    }       
}
}

sub paramSplit()
{
    my ($x)=@_;
    my @ppp = split(/,/, $x);
    return join("\n", @ppp);
}

sub paramSplit()
{
    my ($x)=@_;
    my @ppp = split(/,/, $x);
    return join("\n", @ppp);
}

# ==Coding QP== (set 0 is disable.)
sub set_qps()
{
    if($opt_LowQP)
    {
        @qps_i = (
            [   2,   7,  12,  17],   # seq=1
            [   2,   7,  12,  17],   # seq=2
            [   2,   7,  12,  17],   # seq=3
            [   2,   7,  12,  17],   # seq=4
            [   2,   7,  12,  17],   # seq=5
            [   2,   7,  12,  17],   # seq=6
            [   2,   7,  12,  17],   # seq=7
            [   2,   7,  12,  17],   # seq=8
            [   2,   7,  12,  17],   # seq=9
            [   2,   7,  12,  17],   # seq=10
            [   2,   7,  12,  17],   # seq=11
            [   2,   7,  12,  17],   # seq=12
            [   2,   7,  12,  17],   # seq=13
            [   2,   7,  12,  17],   # seq=14
            [   2,   7,  12,  17],   # seq=15
            [   2,   7,  12,  17],   # seq=16
            [   2,   7,  12,  17],   # seq=17
            [   2,   7,  12,  17],   # seq=18
            [   2,   7,  12,  17],   # seq=19
            [   2,   7,  12,  17],   # seq=20
            [   2,   7,  12,  17],   # seq=21
            [   2,   7,  12,  17],   # seq=22
            [   2,   7,  12,  17],   # seq=23
            [   2,   7,  12,  17],   # seq=24
            [   2,   7,  12,  17],   # seq=25
            [   2,   7,  12,  17],   # seq=26
            [   2,   7,  12,  17],   # seq=27
            [   2,   7,  12,  17],   # seq=28
            [   2,   7,  12,  17],   # seq=29
            [   2,   7,  12,  17],   # seq=30
            [   2,   7,  12,  17],   # seq=31
            [   2,   7,  12,  17],   # seq=32
            [   2,   7,  12,  17],   # seq=33
            [   2,   7,  12,  17],   # seq=34
            [   2,   7,  12,  17],   # seq=35
            [   2,   7,  12,  17],   # seq=36
            [   2,   7,  12,  17],   # seq=37
            [   2,   7,  12,  17],   # seq=38
            [   2,   7,  12,  17],   # seq=39
            [   2,   7,  12,  17],   # seq=40
            [   2,   7,  12,  17],   # seq=41
            [   2,   7,  12,  17],   # seq=42
            [   2,   7,  12,  17],   # seq=43
            [   2,   7,  12,  17],   # seq=44
            [   2,   7,  12,  17],   # seq=45
            [   2,   7,  12,  17],   # seq=46
            [   2,   7,  12,  17],   # seq=47
            [   2,   7,  12,  17],   # seq=48
            [   2,   7,  12,  17],   # seq=49
        );
        @qps_r = (
            [   2,   7,  12,  17],   # seq=1
            [   2,   7,  12,  17],   # seq=2
            [   2,   7,  12,  17],   # seq=3
            [   2,   7,  12,  17],   # seq=4
            [   2,   7,  12,  17],   # seq=5
            [   2,   7,  12,  17],   # seq=6
            [   2,   7,  12,  17],   # seq=7
            [   2,   7,  12,  17],   # seq=8
            [   2,   7,  12,  17],   # seq=9
            [   2,   7,  12,  17],   # seq=10
            [   2,   7,  12,  17],   # seq=11
            [   2,   7,  12,  17],   # seq=12
            [   2,   7,  12,  17],   # seq=13
            [   2,   7,  12,  17],   # seq=14
            [   2,   7,  12,  17],   # seq=15
            [   2,   7,  12,  17],   # seq=16
            [   2,   7,  12,  17],   # seq=17
            [   2,   7,  12,  17],   # seq=18
            [   2,   7,  12,  17],   # seq=19
            [   2,   7,  12,  17],   # seq=20
            [   2,   7,  12,  17],   # seq=21
            [   2,   7,  12,  17],   # seq=22
            [   2,   7,  12,  17],   # seq=23
            [   2,   7,  12,  17],   # seq=24
            [   2,   7,  12,  17],   # seq=25
            [   2,   7,  12,  17],   # seq=26
            [   2,   7,  12,  17],   # seq=27
            [   2,   7,  12,  17],   # seq=28
            [   2,   7,  12,  17],   # seq=29
            [   2,   7,  12,  17],   # seq=30
            [   2,   7,  12,  17],   # seq=31
            [   2,   7,  12,  17],   # seq=32
            [   2,   7,  12,  17],   # seq=33
            [   2,   7,  12,  17],   # seq=34
            [   2,   7,  12,  17],   # seq=35
            [   2,   7,  12,  17],   # seq=36
            [   2,   7,  12,  17],   # seq=37
            [   2,   7,  12,  17],   # seq=38
            [   2,   7,  12,  17],   # seq=39
            [   2,   7,  12,  17],   # seq=40
            [   2,   7,  12,  17],   # seq=41
            [   2,   7,  12,  17],   # seq=42
            [   2,   7,  12,  17],   # seq=43
            [   2,   7,  12,  17],   # seq=44
            [   2,   7,  12,  17],   # seq=45
            [   2,   7,  12,  17],   # seq=46
            [   2,   7,  12,  17],   # seq=47
            [   2,   7,  12,  17],   # seq=48
            [   2,   7,  12,  17],   # seq=49
        );
        @qps_l = (
            [   0,   0,   0,   0],   # seq=1
            [   0,   0,   0,   0],   # seq=2
            [   0,   0,   0,   0],   # seq=3
            [   0,   0,   0,   0],   # seq=4
            [   0,   0,   0,   0],   # seq=5
            [   0,   0,   0,   0],   # seq=6
            [   2,   7,  12,  17],   # seq=7
            [   2,   7,  12,  17],   # seq=8
            [   2,   7,  12,  17],   # seq=9
            [   2,   7,  12,  17],   # seq=10
            [   2,   7,  12,  17],   # seq=11
            [   2,   7,  12,  17],   # seq=12
            [   2,   7,  12,  17],   # seq=13
            [   2,   7,  12,  17],   # seq=14
            [   2,   7,  12,  17],   # seq=15
            [   2,   7,  12,  17],   # seq=16
            [   2,   7,  12,  17],   # seq=17
            [   2,   7,  12,  17],   # seq=18
            [   2,   7,  12,  17],   # seq=19
            [   2,   7,  12,  17],   # seq=20
            [   2,   7,  12,  17],   # seq=21
            [   2,   7,  12,  17],   # seq=22
            [   2,   7,  12,  17],   # seq=23
            [   2,   7,  12,  17],   # seq=24
            [   2,   7,  12,  17],   # seq=25
            [   2,   7,  12,  17],   # seq=26
            [   2,   7,  12,  17],   # seq=27
            [   2,   7,  12,  17],   # seq=28
            [   2,   7,  12,  17],   # seq=29
            [   2,   7,  12,  17],   # seq=30
            [   2,   7,  12,  17],   # seq=31
            [   2,   7,  12,  17],   # seq=32
            [   2,   7,  12,  17],   # seq=33
            [   2,   7,  12,  17],   # seq=34
            [   2,   7,  12,  17],   # seq=35
            [   2,   7,  12,  17],   # seq=36
            [   2,   7,  12,  17],   # seq=37
            [   2,   7,  12,  17],   # seq=38
            [   2,   7,  12,  17],   # seq=39
            [   2,   7,  12,  17],   # seq=40
            [   2,   7,  12,  17],   # seq=41
            [   2,   7,  12,  17],   # seq=42
            [   2,   7,  12,  17],   # seq=43
            [   2,   7,  12,  17],   # seq=44
            [   2,   7,  12,  17],   # seq=45
            [   2,   7,  12,  17],   # seq=46
            [   2,   7,  12,  17],   # seq=47
            [   2,   7,  12,  17],   # seq=48
            [   2,   7,  12,  17],   # seq=49
        );
        @qps_p = (
            [   0,   0,   0,   0],   # seq=1
            [   0,   0,   0,   0],   # seq=2
            [   0,   0,   0,   0],   # seq=3
            [   0,   0,   0,   0],   # seq=4
            [   0,   0,   0,   0],   # seq=5
            [   0,   0,   0,   0],   # seq=6
            [   2,   7,  12,  17],   # seq=7
            [   2,   7,  12,  17],   # seq=8
            [   2,   7,  12,  17],   # seq=9
            [   2,   7,  12,  17],   # seq=10
            [   2,   7,  12,  17],   # seq=11
            [   2,   7,  12,  17],   # seq=12
            [   2,   7,  12,  17],   # seq=13
            [   2,   7,  12,  17],   # seq=14
            [   2,   7,  12,  17],   # seq=15
            [   2,   7,  12,  17],   # seq=16
            [   2,   7,  12,  17],   # seq=17
            [   2,   7,  12,  17],   # seq=18
            [   2,   7,  12,  17],   # seq=19
            [   2,   7,  12,  17],   # seq=20
            [   2,   7,  12,  17],   # seq=21
            [   2,   7,  12,  17],   # seq=22
            [   2,   7,  12,  17],   # seq=23
            [   2,   7,  12,  17],   # seq=24
            [   2,   7,  12,  17],   # seq=25
            [   2,   7,  12,  17],   # seq=26
            [   2,   7,  12,  17],   # seq=27
            [   2,   7,  12,  17],   # seq=28
            [   2,   7,  12,  17],   # seq=29
            [   2,   7,  12,  17],   # seq=30
            [   2,   7,  12,  17],   # seq=31
            [   2,   7,  12,  17],   # seq=32
            [   2,   7,  12,  17],   # seq=33
            [   2,   7,  12,  17],   # seq=34
            [   2,   7,  12,  17],   # seq=35
            [   2,   7,  12,  17],   # seq=36
            [   2,   7,  12,  17],   # seq=37
            [   2,   7,  12,  17],   # seq=38
            [   2,   7,  12,  17],   # seq=39
            [   2,   7,  12,  17],   # seq=40
            [   2,   7,  12,  17],   # seq=41
            [   2,   7,  12,  17],   # seq=42
            [   2,   7,  12,  17],   # seq=43
            [   2,   7,  12,  17],   # seq=44
            [   2,   7,  12,  17],   # seq=45
            [   2,   7,  12,  17],   # seq=46
            [   2,   7,  12,  17],   # seq=47
            [   2,   7,  12,  17],   # seq=48
            [   2,   7,  12,  17],   # seq=49
        );
    }
    else
    {
        @qps_i = (
            [  22,  27,  32,  37],   # seq=1
            [  22,  27,  32,  37],   # seq=2
            [  22,  27,  32,  37],   # seq=3
            [  22,  27,  32,  37],   # seq=4
            [  22,  27,  32,  37],   # seq=5
            [  22,  27,  32,  37],   # seq=6
            [  22,  27,  32,  37],   # seq=7
            [  22,  27,  32,  37],   # seq=8
            [  22,  27,  32,  37],   # seq=9
            [  22,  27,  32,  37],   # seq=10
            [  22,  27,  32,  37],   # seq=11
            [  22,  27,  32,  37],   # seq=12
            [  22,  27,  32,  37],   # seq=13
            [  22,  27,  32,  37],   # seq=14
            [  22,  27,  32,  37],   # seq=15
            [  22,  27,  32,  37],   # seq=16
            [  22,  27,  32,  37],   # seq=17
            [  22,  27,  32,  37],   # seq=18
            [  22,  27,  32,  37],   # seq=19
            [  22,  27,  32,  37],   # seq=20
            [  22,  27,  32,  37],   # seq=21
            [  22,  27,  32,  37],   # seq=22
            [  22,  27,  32,  37],   # seq=23
            [  22,  27,  32,  37],   # seq=24
            [  22,  27,  32,  37],   # seq=25
            [  22,  27,  32,  37],   # seq=26
            [  22,  27,  32,  37],   # seq=27
            [  22,  27,  32,  37],   # seq=28
            [  22,  27,  32,  37],   # seq=29
            [  22,  27,  32,  37],   # seq=30
            [  22,  27,  32,  37],   # seq=31
            [  22,  27,  32,  37],   # seq=32
            [  22,  27,  32,  37],   # seq=33
            [  22,  27,  32,  37],   # seq=34
            [  22,  27,  32,  37],   # seq=35
            [  22,  27,  32,  37],   # seq=36
            [  22,  27,  32,  37],   # seq=37
            [  22,  27,  32,  37],   # seq=38
            [  22,  27,  32,  37],   # seq=39
            [  22,  27,  32,  37],   # seq=40
            [  22,  27,  32,  37],   # seq=41
            [  22,  27,  32,  37],   # seq=42
            [  22,  27,  32,  37],   # seq=43
            [  22,  27,  32,  37],   # seq=44
            [  22,  27,  32,  37],   # seq=45
            [  22,  27,  32,  37],   # seq=46
            [  22,  27,  32,  37],   # seq=47
            [  22,  27,  32,  37],   # seq=48
            [  22,  27,  32,  37],   # seq=49
        );
        @qps_r = (
            [  22,  27,  32,  37],   # seq=1
            [  22,  27,  32,  37],   # seq=2
            [  22,  27,  32,  37],   # seq=3
            [  22,  27,  32,  37],   # seq=4
            [  22,  27,  32,  37],   # seq=5
            [  22,  27,  32,  37],   # seq=6
            [  22,  27,  32,  37],   # seq=7
            [  22,  27,  32,  37],   # seq=8
            [  22,  27,  32,  37],   # seq=9
            [  22,  27,  32,  37],   # seq=10
            [  22,  27,  32,  37],   # seq=11
            [  22,  27,  32,  37],   # seq=12
            [  22,  27,  32,  37],   # seq=13
            [  22,  27,  32,  37],   # seq=14
            [  22,  27,  32,  37],   # seq=15
            [  22,  27,  32,  37],   # seq=16
            [  22,  27,  32,  37],   # seq=17
            [  22,  27,  32,  37],   # seq=18
            [  22,  27,  32,  37],   # seq=19
            [  22,  27,  32,  37],   # seq=20
            [  22,  27,  32,  37],   # seq=21
            [  22,  27,  32,  37],   # seq=22
            [  22,  27,  32,  37],   # seq=23
            [  22,  27,  32,  37],   # seq=24
            [  22,  27,  32,  37],   # seq=25
            [  22,  27,  32,  37],   # seq=26
            [  22,  27,  32,  37],   # seq=27
            [  22,  27,  32,  37],   # seq=28
            [  22,  27,  32,  37],   # seq=29
            [  22,  27,  32,  37],   # seq=30
            [  22,  27,  32,  37],   # seq=31
            [  22,  27,  32,  37],   # seq=32
            [  22,  27,  32,  37],   # seq=33
            [  22,  27,  32,  37],   # seq=34
            [  22,  27,  32,  37],   # seq=35
            [  22,  27,  32,  37],   # seq=36
            [  22,  27,  32,  37],   # seq=37
            [  22,  27,  32,  37],   # seq=38
            [  22,  27,  32,  37],   # seq=39
            [  22,  27,  32,  37],   # seq=40
            [  22,  27,  32,  37],   # seq=41
            [  22,  27,  32,  37],   # seq=42
            [  22,  27,  32,  37],   # seq=43
            [  22,  27,  32,  37],   # seq=44
            [  22,  27,  32,  37],   # seq=45
            [  22,  27,  32,  37],   # seq=46
            [  22,  27,  32,  37],   # seq=47
            [  22,  27,  32,  37],   # seq=48
            [  22,  27,  32,  37],   # seq=49
        );
        @qps_l = (
            [   0,   0,   0,   0],   # seq=1
            [   0,   0,   0,   0],   # seq=2
            [   0,   0,   0,   0],   # seq=3
            [   0,   0,   0,   0],   # seq=4
            [   0,   0,   0,   0],   # seq=5
            [   0,   0,   0,   0],   # seq=6
            [  22,  27,  32,  37],   # seq=7
            [  22,  27,  32,  37],   # seq=8
            [  22,  27,  32,  37],   # seq=9
            [  22,  27,  32,  37],   # seq=10
            [  22,  27,  32,  37],   # seq=11
            [  22,  27,  32,  37],   # seq=12
            [  22,  27,  32,  37],   # seq=13
            [  22,  27,  32,  37],   # seq=14
            [  22,  27,  32,  37],   # seq=15
            [  22,  27,  32,  37],   # seq=16
            [  22,  27,  32,  37],   # seq=17
            [  22,  27,  32,  37],   # seq=18
            [  22,  27,  32,  37],   # seq=19
            [  22,  27,  32,  37],   # seq=20
            [  22,  27,  32,  37],   # seq=21
            [  22,  27,  32,  37],   # seq=22
            [  22,  27,  32,  37],   # seq=23
            [  22,  27,  32,  37],   # seq=24
            [  22,  27,  32,  37],   # seq=25
            [  22,  27,  32,  37],   # seq=26
            [  22,  27,  32,  37],   # seq=27
            [  22,  27,  32,  37],   # seq=28
            [  22,  27,  32,  37],   # seq=29
            [  22,  27,  32,  37],   # seq=30
            [  22,  27,  32,  37],   # seq=31
            [  22,  27,  32,  37],   # seq=32
            [  22,  27,  32,  37],   # seq=33
            [  22,  27,  32,  37],   # seq=34
            [  22,  27,  32,  37],   # seq=35
            [  22,  27,  32,  37],   # seq=36
            [  22,  27,  32,  37],   # seq=37
            [  22,  27,  32,  37],   # seq=38
            [  22,  27,  32,  37],   # seq=39
            [  22,  27,  32,  37],   # seq=40
            [  22,  27,  32,  37],   # seq=41
            [  22,  27,  32,  37],   # seq=42
            [  22,  27,  32,  37],   # seq=43
            [  22,  27,  32,  37],   # seq=44
            [  22,  27,  32,  37],   # seq=45
            [  22,  27,  32,  37],   # seq=46
            [  22,  27,  32,  37],   # seq=47
            [  22,  27,  32,  37],   # seq=48
            [  22,  27,  32,  37],   # seq=49
        );
        @qps_p = (
            [   0,   0,   0,   0],   # seq=1
            [   0,   0,   0,   0],   # seq=2
            [   0,   0,   0,   0],   # seq=3
            [   0,   0,   0,   0],   # seq=4
            [   0,   0,   0,   0],   # seq=5
            [   0,   0,   0,   0],   # seq=6
            [  22,  27,  32,  37],   # seq=7
            [  22,  27,  32,  37],   # seq=8
            [  22,  27,  32,  37],   # seq=9
            [  22,  27,  32,  37],   # seq=10
            [  22,  27,  32,  37],   # seq=11
            [  22,  27,  32,  37],   # seq=12
            [  22,  27,  32,  37],   # seq=13
            [  22,  27,  32,  37],   # seq=14
            [  22,  27,  32,  37],   # seq=15
            [  22,  27,  32,  37],   # seq=16
            [  22,  27,  32,  37],   # seq=17
            [  22,  27,  32,  37],   # seq=18
            [  22,  27,  32,  37],   # seq=19
            [  22,  27,  32,  37],   # seq=20
            [  22,  27,  32,  37],   # seq=21
            [  22,  27,  32,  37],   # seq=22
            [  22,  27,  32,  37],   # seq=23
            [  22,  27,  32,  37],   # seq=24
            [  22,  27,  32,  37],   # seq=25
            [  22,  27,  32,  37],   # seq=26
            [  22,  27,  32,  37],   # seq=27
            [  22,  27,  32,  37],   # seq=28
            [  22,  27,  32,  37],   # seq=29
            [  22,  27,  32,  37],   # seq=30
            [  22,  27,  32,  37],   # seq=31
            [  22,  27,  32,  37],   # seq=32
            [  22,  27,  32,  37],   # seq=33
            [  22,  27,  32,  37],   # seq=34
            [  22,  27,  32,  37],   # seq=35
            [  22,  27,  32,  37],   # seq=36
            [  22,  27,  32,  37],   # seq=37
            [  22,  27,  32,  37],   # seq=38
            [  22,  27,  32,  37],   # seq=39
            [  22,  27,  32,  37],   # seq=40
            [  22,  27,  32,  37],   # seq=41
            [  22,  27,  32,  37],   # seq=42
            [  22,  27,  32,  37],   # seq=43
            [  22,  27,  32,  37],   # seq=44
            [  22,  27,  32,  37],   # seq=45
            [  22,  27,  32,  37],   # seq=46
            [  22,  27,  32,  37],   # seq=47
            [  22,  27,  32,  37],   # seq=48
            [  22,  27,  32,  37],   # seq=49
        );
    }
}

# ==QP increment frame== (suppoted max 999, set 0 is disable.)
sub set_qp_inc_frm()
{
    @qp_inc_frm_i = (
        [   0,   0,   0,   0],   # seq=1
        [   0,   0,   0,   0],   # seq=2
        [   0,   0,   0,   0],   # seq=3
        [   0,   0,   0,   0],   # seq=4
        [   0,   0,   0,   0],   # seq=5
        [   0,   0,   0,   0],   # seq=6
        [   0,   0,   0,   0],   # seq=7
        [   0,   0,   0,   0],   # seq=8
        [   0,   0,   0,   0],   # seq=9
        [   0,   0,   0,   0],   # seq=10
        [   0,   0,   0,   0],   # seq=11
        [   0,   0,   0,   0],   # seq=12
        [   0,   0,   0,   0],   # seq=13
        [   0,   0,   0,   0],   # seq=14
        [   0,   0,   0,   0],   # seq=15
        [   0,   0,   0,   0],   # seq=16
        [   0,   0,   0,   0],   # seq=17
        [   0,   0,   0,   0],   # seq=18
        [   0,   0,   0,   0],   # seq=19
        [   0,   0,   0,   0],   # seq=20
        [   0,   0,   0,   0],   # seq=21
        [   0,   0,   0,   0],   # seq=22
        [   0,   0,   0,   0],   # seq=23
        [   0,   0,   0,   0],   # seq=24
        [   0,   0,   0,   0],   # seq=25
        [   0,   0,   0,   0],   # seq=26
        [   0,   0,   0,   0],   # seq=27
        [   0,   0,   0,   0],   # seq=28
        [   0,   0,   0,   0],   # seq=29
        [   0,   0,   0,   0],   # seq=30
        [   0,   0,   0,   0],   # seq=31
        [   0,   0,   0,   0],   # seq=32
        [   0,   0,   0,   0],   # seq=33
        [   0,   0,   0,   0],   # seq=34
        [   0,   0,   0,   0],   # seq=35
        [   0,   0,   0,   0],   # seq=36
        [   0,   0,   0,   0],   # seq=37
        [   0,   0,   0,   0],   # seq=38
        [   0,   0,   0,   0],   # seq=39
        [   0,   0,   0,   0],   # seq=40
        [   0,   0,   0,   0],   # seq=41
        [   0,   0,   0,   0],   # seq=42
        [   0,   0,   0,   0],   # seq=43
        [   0,   0,   0,   0],   # seq=44
        [   0,   0,   0,   0],   # seq=45
        [   0,   0,   0,   0],   # seq=46
        [   0,   0,   0,   0],   # seq=47
        [   0,   0,   0,   0],   # seq=48
        [   0,   0,   0,   0],   # seq=49
    );
    @qp_inc_frm_r = (
        [   0,   0,   0,   0],   # seq=1
        [   0,   0,   0,   0],   # seq=2
        [   0,   0,   0,   0],   # seq=3
        [   0,   0,   0,   0],   # seq=4
        [   0,   0,   0,   0],   # seq=5
        [   0,   0,   0,   0],   # seq=6
        [   0,   0,   0,   0],   # seq=7
        [   0,   0,   0,   0],   # seq=8
        [   0,   0,   0,   0],   # seq=9
        [   0,   0,   0,   0],   # seq=10
        [   0,   0,   0,   0],   # seq=11
        [   0,   0,   0,   0],   # seq=12
        [   0,   0,   0,   0],   # seq=13
        [   0,   0,   0,   0],   # seq=14
        [   0,   0,   0,   0],   # seq=15
        [   0,   0,   0,   0],   # seq=16
        [   0,   0,   0,   0],   # seq=17
        [   0,   0,   0,   0],   # seq=18
        [   0,   0,   0,   0],   # seq=19
        [   0,   0,   0,   0],   # seq=20
        [   0,   0,   0,   0],   # seq=21
        [   0,   0,   0,   0],   # seq=22
        [   0,   0,   0,   0],   # seq=23
        [   0,   0,   0,   0],   # seq=24
        [   0,   0,   0,   0],   # seq=25
        [   0,   0,   0,   0],   # seq=26
        [   0,   0,   0,   0],   # seq=27
        [   0,   0,   0,   0],   # seq=28
        [   0,   0,   0,   0],   # seq=29
        [   0,   0,   0,   0],   # seq=30
        [   0,   0,   0,   0],   # seq=31
        [   0,   0,   0,   0],   # seq=32
        [   0,   0,   0,   0],   # seq=33
        [   0,   0,   0,   0],   # seq=34
        [   0,   0,   0,   0],   # seq=35
        [   0,   0,   0,   0],   # seq=36
        [   0,   0,   0,   0],   # seq=37
        [   0,   0,   0,   0],   # seq=38
        [   0,   0,   0,   0],   # seq=39
        [   0,   0,   0,   0],   # seq=40
        [   0,   0,   0,   0],   # seq=41
        [   0,   0,   0,   0],   # seq=42
        [   0,   0,   0,   0],   # seq=43
        [   0,   0,   0,   0],   # seq=44
        [   0,   0,   0,   0],   # seq=45
        [   0,   0,   0,   0],   # seq=46
        [   0,   0,   0,   0],   # seq=47
        [   0,   0,   0,   0],   # seq=48
        [   0,   0,   0,   0],   # seq=49
    );
    @qp_inc_frm_l = (
        [   0,   0,   0,   0],   # seq=1
        [   0,   0,   0,   0],   # seq=2
        [   0,   0,   0,   0],   # seq=3
        [   0,   0,   0,   0],   # seq=4
        [   0,   0,   0,   0],   # seq=5
        [   0,   0,   0,   0],   # seq=6
        [   0,   0,   0,   0],   # seq=7
        [   0,   0,   0,   0],   # seq=8
        [   0,   0,   0,   0],   # seq=9
        [   0,   0,   0,   0],   # seq=10
        [   0,   0,   0,   0],   # seq=11
        [   0,   0,   0,   0],   # seq=12
        [   0,   0,   0,   0],   # seq=13
        [   0,   0,   0,   0],   # seq=14
        [   0,   0,   0,   0],   # seq=15
        [   0,   0,   0,   0],   # seq=16
        [   0,   0,   0,   0],   # seq=17
        [   0,   0,   0,   0],   # seq=18
        [   0,   0,   0,   0],   # seq=19
        [   0,   0,   0,   0],   # seq=20
        [   0,   0,   0,   0],   # seq=21
        [   0,   0,   0,   0],   # seq=22
        [   0,   0,   0,   0],   # seq=23
        [   0,   0,   0,   0],   # seq=24
        [   0,   0,   0,   0],   # seq=25
        [   0,   0,   0,   0],   # seq=26
        [   0,   0,   0,   0],   # seq=27
        [   0,   0,   0,   0],   # seq=28
        [   0,   0,   0,   0],   # seq=29
        [   0,   0,   0,   0],   # seq=30
        [   0,   0,   0,   0],   # seq=31
        [   0,   0,   0,   0],   # seq=32
        [   0,   0,   0,   0],   # seq=33
        [   0,   0,   0,   0],   # seq=34
        [   0,   0,   0,   0],   # seq=35
        [   0,   0,   0,   0],   # seq=36
        [   0,   0,   0,   0],   # seq=37
        [   0,   0,   0,   0],   # seq=38
        [   0,   0,   0,   0],   # seq=39
        [   0,   0,   0,   0],   # seq=40
        [   0,   0,   0,   0],   # seq=41
        [   0,   0,   0,   0],   # seq=42
        [   0,   0,   0,   0],   # seq=43
        [   0,   0,   0,   0],   # seq=44
        [   0,   0,   0,   0],   # seq=45
        [   0,   0,   0,   0],   # seq=46
        [   0,   0,   0,   0],   # seq=47
        [   0,   0,   0,   0],   # seq=48
        [   0,   0,   0,   0],   # seq=49
    );
    @qp_inc_frm_p = (
        [   0,   0,   0,   0],   # seq=1
        [   0,   0,   0,   0],   # seq=2
        [   0,   0,   0,   0],   # seq=3
        [   0,   0,   0,   0],   # seq=4
        [   0,   0,   0,   0],   # seq=5
        [   0,   0,   0,   0],   # seq=6
        [   0,   0,   0,   0],   # seq=7
        [   0,   0,   0,   0],   # seq=8
        [   0,   0,   0,   0],   # seq=9
        [   0,   0,   0,   0],   # seq=10
        [   0,   0,   0,   0],   # seq=11
        [   0,   0,   0,   0],   # seq=12
        [   0,   0,   0,   0],   # seq=13
        [   0,   0,   0,   0],   # seq=14
        [   0,   0,   0,   0],   # seq=15
        [   0,   0,   0,   0],   # seq=16
        [   0,   0,   0,   0],   # seq=17
        [   0,   0,   0,   0],   # seq=18
        [   0,   0,   0,   0],   # seq=19
        [   0,   0,   0,   0],   # seq=20
        [   0,   0,   0,   0],   # seq=21
        [   0,   0,   0,   0],   # seq=22
        [   0,   0,   0,   0],   # seq=23
        [   0,   0,   0,   0],   # seq=24
        [   0,   0,   0,   0],   # seq=25
        [   0,   0,   0,   0],   # seq=26
        [   0,   0,   0,   0],   # seq=27
        [   0,   0,   0,   0],   # seq=28
        [   0,   0,   0,   0],   # seq=29
        [   0,   0,   0,   0],   # seq=30
        [   0,   0,   0,   0],   # seq=31
        [   0,   0,   0,   0],   # seq=32
        [   0,   0,   0,   0],   # seq=33
        [   0,   0,   0,   0],   # seq=34
        [   0,   0,   0,   0],   # seq=35
        [   0,   0,   0,   0],   # seq=36
        [   0,   0,   0,   0],   # seq=37
        [   0,   0,   0,   0],   # seq=38
        [   0,   0,   0,   0],   # seq=39
        [   0,   0,   0,   0],   # seq=40
        [   0,   0,   0,   0],   # seq=41
        [   0,   0,   0,   0],   # seq=42
        [   0,   0,   0,   0],   # seq=43
        [   0,   0,   0,   0],   # seq=44
        [   0,   0,   0,   0],   # seq=45
        [   0,   0,   0,   0],   # seq=46
        [   0,   0,   0,   0],   # seq=47
        [   0,   0,   0,   0],   # seq=48
        [   0,   0,   0,   0],   # seq=49
    );
}

######################################################
 ## main
###################################################### 

use File::Copy;
use Cwd;
my $Cwd = cwd();
use Getopt::Std;
my %opts = ();
getopts ("v", \%opts);
if(0)
{
    foreach my $key(keys %opts ) {
        print "$key = $opts{$key}\n";
    }
}

srand(time ^ ($$ + ($$ << 15)));

my $fatal_error = 0; 
 
 
## read table sid to width, height, fnum, fname

ReadDataTable();
FreadRunEncCfg();

foreach my $sid (keys %sid2nfr1)
{
    if($nfrm_is eq 'full')      { $sid2nfr{$sid} = $sid2nfr1{$sid}; }
    elsif($nfrm_is eq 'short')  { $sid2nfr{$sid} = $sid2nfr2{$sid}; }
    elsif($nfrm_is eq 'fns')    { $sid2nfr{$sid} = $sid2nfr1{$sid}; }
    elsif($nfrm_is == 0)        { $sid2nfr{$sid} = $sid2nfr2{$sid}; }
    else                        { $sid2nfr{$sid} = $nfrm_is; }
}


FreadRunEncCfg();


## confirm setting


if(0)
{
    my $i; my $j;
    foreach $i (sort keys %CommonParam) 
    {
        print "[$i]=>[$CommonParam{$i}]\n";
        if($CommonParam{$i} =~ /CDP/)
        {
            foreach $j (sort keys %ClassDependentParam) 
            {
                print "\t[$j]=>[", $ClassDependentParam{$j}, "]\n";
            }
        }
    }   
}   

#print "\n";
#print "cwd   = $Cwd\n";
for(my $setid=0; $setid < @set; $setid++)
{
    my $cset = $set[$setid];
    my $dir  = ${cset}->Dir;
    my $enc  = $cset->Encoder;    
    my $dec  = $cset->Decoder;
    my @prmKey = @{$cset->Param};
    my $prmStr = GetParamStr("", @prmKey);
    
    if(0)
    {
	    print "   [set $setid] Dir: $dir\n";
	    print "           Enc: $enc\n";
	    print "           Dec: $dec\n";
	    print "       PRM Key: @prmKey \n";
        print "       PRM Str: $prmStr \n";    
    }

    if($prmStr =~ /ERROR/) { print "ERROR! either of prmKey(@prmKey) may not be defined\n"; $fatal_error++; }
    if(! -e $enc){ print "ERROR! encoder $enc is not found\n"; $fatal_error++; }
    if(! -e $dec){ print "ERROR! decoder $dec is not found\n"; $fatal_error++; }
}

if( $opt_print_qp != 0 )
{
    # QP (AI)
    foreach my $sid (@seq_AI)
    {
        my $i;
        my $tmp = sprintf("qps_i[%2d] = ", $sid);
        print "$tmp";
        my $num_qps = @{$qps_i[$sid-$sid_min]};
        for ($i=0; $i<$num_qps-1; $i++)
        {
            $tmp = sprintf("%2d, ", $qps_i[$sid-$sid_min][$i]);
            print "$tmp";
        }
        $tmp = sprintf("%2d\n", $qps_i[$sid-$sid_min][$i]);
        print "$tmp";
    }# QP (RA)
    foreach my $sid (@seq_RA)
    {
        my $i;
        my $tmp = sprintf("qps_r[%2d] = ", $sid);
        print "$tmp";
        my $num_qps = @{$qps_r[$sid-$sid_min]};
        for ($i=0; $i<$num_qps-1; $i++)
        {
            $tmp = sprintf("%2d, ", $qps_r[$sid-$sid_min][$i]);
            print "$tmp";
        }
        $tmp = sprintf("%2d\n", $qps_r[$sid-$sid_min][$i]);
        print "$tmp";
    }
    # QP (LD)
    foreach my $sid (@seq_LD)
    {
        my $i;
        my $tmp = sprintf("qps_l[%2d] = ", $sid);
        print "$tmp";
        my $num_qps = @{$qps_l[$sid-$sid_min]};
        for ($i=0; $i<$num_qps-1; $i++)
        {
            $tmp = sprintf("%2d, ", $qps_l[$sid-$sid_min][$i]);
            print "$tmp";
        }
        $tmp = sprintf("%2d\n", $qps_l[$sid-$sid_min][$i]);
        print "$tmp";
    }
    # QP (LP)
    foreach my $sid (@seq_LD)
    {
        my $i;
        my $tmp = sprintf("qps_p[%2d] = ", $sid);
        print "$tmp";
        my $num_qps = @{$qps_p[$sid-$sid_min]};
        for ($i=0; $i<$num_qps-1; $i++)
        {
            $tmp = sprintf("%2d, ", $qps_p[$sid-$sid_min][$i]);
            print "$tmp";
        }
        $tmp = sprintf("%2d\n", $qps_p[$sid-$sid_min][$i]);
        print "$tmp";
    }
    # QP increment frame (AI)
    foreach my $sid (@seq_AI)
    {
        my $i;
        my $tmp = sprintf("qp_inc_frm_i[%2d] = ", $sid);
        print "$tmp";
        my $num_qp_inc_frm = @{$qp_inc_frm_i[$sid-$sid_min]};
        for ($i=0; $i<$num_qp_inc_frm-1; $i++)
        {
            $tmp = sprintf("%3d, ", $qp_inc_frm_i[$sid-$sid_min][$i]);
            print "$tmp";
        }
        $tmp = sprintf("%3d\n", $qp_inc_frm_i[$sid-$sid_min][$i]);
        print "$tmp";
    }# QP increment frame (RA)
    foreach my $sid (@seq_RA)
    {
        my $i;
        my $tmp = sprintf("qp_inc_frm_r[%2d] = ", $sid);
        print "$tmp";
        my $num_qp_inc_frm = @{$qp_inc_frm_r[$sid-$sid_min]};
        for ($i=0; $i<$num_qp_inc_frm-1; $i++)
        {
            $tmp = sprintf("%3d, ", $qp_inc_frm_r[$sid-$sid_min][$i]);
            print "$tmp";
        }
        $tmp = sprintf("%3d\n", $qp_inc_frm_r[$sid-$sid_min][$i]);
        print "$tmp";
    }
    # QP increment frame (LD)
    foreach my $sid (@seq_LD)
    {
        my $i;
        my $tmp = sprintf("qp_inc_frm_l[%2d] = ", $sid);
        print "$tmp";
        my $num_qp_inc_frm = @{$qp_inc_frm_l[$sid-$sid_min]};
        for ($i=0; $i<$num_qp_inc_frm-1; $i++)
        {
            $tmp = sprintf("%3d, ", $qp_inc_frm_l[$sid-$sid_min][$i]);
            print "$tmp";
        }
        $tmp = sprintf("%3d\n", $qp_inc_frm_l[$sid-$sid_min][$i]);
        print "$tmp";
    }
    # QP increment frame (LP)
    foreach my $sid (@seq_LD)
    {
        my $i;
        my $tmp = sprintf("qp_inc_frm_p[%2d] = ", $sid);
        print "$tmp";
        my $num_qp_inc_frm = @{$qp_inc_frm_p[$sid-$sid_min]};
        for ($i=0; $i<$num_qp_inc_frm-1; $i++)
        {
            $tmp = sprintf("%3d, ", $qp_inc_frm_p[$sid-$sid_min][$i]);
            print "$tmp";
        }
        $tmp = sprintf("%3d\n", $qp_inc_frm_p[$sid-$sid_min][$i]);
        print "$tmp";
    }
}
if(0)
{
	print "cstr   = @cstr\n";
	print "pcs   = "; foreach my $pc (@simpc) {  print "$pc($pc2core{$pc}) "; } print "\n";
	
	print "encdec = $opt_encdec "; 
	if   ($opt_encdec==1){ print "(encoding only) \n"; }
	elsif($opt_encdec==2){ print "(decoding only) \n"; }
	elsif($opt_encdec==3){ print "(both encoding and decoding)\n"; }
	else                 { print "(decoding only) \n"; }
	
	foreach my $cstr (@cstr)
	{
	    if( $cstr eq "JI" ){
	        print "seq(AI) = ";
	        foreach my $sid (@seq_AI){ print "$sid2shortname{$sid}($sid2nfr{$sid}) "; } print "\n";
	    }
	    if( $cstr eq "JR" ){
	        print "seq(RA) = ";
	        foreach my $sid (@seq_RA){ print "$sid2shortname{$sid}($sid2nfr{$sid}) "; } print "\n";
	    }
	    if(( $cstr eq "JL" ) || ( $cstr eq "JP" )){
	        print "seq(LD) = ";
	        foreach my $sid (@seq_LD){ print "$sid2shortname{$sid}($sid2nfr{$sid}) "; } print "\n";
	    }
	}
}

##
my @job;

foreach my $cstr (@cstr)
{
    if(( $cstr eq "JI" ) || ( $cstr eq "HI" ))
    {
        foreach my $sid (@seq_AI)
        {
            my $num_qps = @{$qps_i[$sid-$sid_min]};
            for (my $i=0; $i<$num_qps; $i++)
            {
                my $qpid = $num_qps-$i;
                my $qp = $qps_i[$sid-$sid_min][$i];
                my $qpinc = $qp_inc_frm_i[$sid-$sid_min][$i];
                my $jobkey = sprintf("%s-%03d-%03d-%03d-%1d", $cstr, $sid, $qp, $qpinc, $qpid);
#               print "jobkey = $jobkey\n";
                if( $qp == 0 ) { next };
                push(@job, $jobkey);
            }
        }
    }
    elsif(( $cstr eq "JR" ) || ( $cstr eq "HR" ))
    {
        foreach my $sid (@seq_RA)
        {
            my $num_qps = @{$qps_r[$sid-$sid_min]};
            for (my $i=0; $i<$num_qps; $i++)
            {
                my $qpid = $num_qps-$i;
                my $qp = $qps_r[$sid-$sid_min][$i];
                my $qpinc = $qp_inc_frm_r[$sid-$sid_min][$i];
                my $jobkey = sprintf("%s-%03d-%03d-%03d-%1d", $cstr, $sid, $qp, $qpinc, $qpid);
#               print "jobkey = $jobkey\n";
                if( $qp == 0 ) { next };
                push(@job, $jobkey);
            }
        }
    }
    elsif(( $cstr eq "JL" ) || ( $cstr eq "HL" ))
    {
        foreach my $sid (@seq_LD)
        {
            my $num_qps = @{$qps_l[$sid-$sid_min]};
            for (my $i=0; $i<$num_qps; $i++)
            {
                my $qpid = $num_qps-$i;
                my $qp = $qps_l[$sid-$sid_min][$i];
                my $qpinc = $qp_inc_frm_l[$sid-$sid_min][$i];
                my $jobkey = sprintf("%s-%03d-%03d-%03d-%1d", $cstr, $sid, $qp, $qpinc, $qpid);
#               print "jobkey = $jobkey\n";
                if( $qp == 0 ) { next };
                push(@job, $jobkey);
            }
        }
    }
    elsif(( $cstr eq "JP" ) || ( $cstr eq "HP" ))
    {
        foreach my $sid (@seq_LD)
        {
            my $num_qps = @{$qps_p[$sid-$sid_min]};
            for (my $i=0; $i<$num_qps; $i++)
            {
                my $qpid = $num_qps-$i;
                my $qp = $qps_p[$sid-$sid_min][$i];
                my $qpinc = $qp_inc_frm_p[$sid-$sid_min][$i];
                my $jobkey = sprintf("%s-%03d-%03d-%03d-%1d", $cstr, $sid, $qp, $qpinc, $qpid);
#               print "jobkey = $jobkey\n";
                if( $qp == 0 ) { next };
                push(@job, $jobkey);
            }
        }
    }
}


## confirm total encoding time
if(0)
{
    my $num_exe = @job * @set;
    print "total  = $num_exe exe on $num_core core.\n";
}

if($fatal_error>0){ print "fatal error happened. aborted.\n"; exit; }

#print "<HIT ENTER KEY> "; <STDIN>;

#-------------------------------------------------------------------------------------

my $done_exe=0;
my $last_pc_remain=0;
my $last_pc = "";
my $task_name = "";
my $concat_task_name = "";

JOB: while(@job)
{
    my $remain_num_key =@job; 
    my $key = shift(@job);  
    my ($cstr,$sid,$qp,$qpincfrm,$qpid) = ($key =~ /^([^-]*)-(\d+)-(-?\d+)-(-?\d+)-(\d+)$/); $sid = int($sid); $qp = int($qp); $qpincfrm = int($qpincfrm); $qpid = int($qpid);
    my ($csApart, $csBpart) = ($cstr =~ /^(.)(.)$/);
    #FORSETID: for(my $setid=0; $setid < @set; $setid++)
    for(my $setid=0; $setid < @set; $setid++)
    {
        my $setDir  = $set[$setid]->Dir;
        my $setEnc  = $set[$setid]->Encoder;     
        my $setDec  = $set[$setid]->Decoder;  
        
        my $pictSizeClass = GetPictSizeClass($sid);
        my $prmbody = GetParamStr($pictSizeClass, @{$set[$setid]->Param}); 
        if($prmbody =~ /ERROR/)
        { 
            print $prmbody;
            print "parameter difinition may have error\n";  exit; 
        }
        else
        {
          #  print $prmbody; <STDIN>;
        }
        $prmbody =~ s/=/ : /mg; $prmbody =~ s/,/\n/mg; 

#	    my $qpid;
#       if   ($qp==22){ $qpid=4; }
#       elsif($qp==27){ $qpid=3; }
#       elsif($qp==32){ $qpid=2; }
#       elsif($qp==37){ $qpid=1; }  
#       else          { $qpid = 5; }
        $qp2id{$qp} = $qpid;

        my $ExpDir     = "${Cwd}/F3_${setDir}";
                
		my $rapnum = 1;	
		my $concat_execution = $ConcatExe;
		if (( $cstr eq "JR" ) && ($nfrm_is =~ /full/i)){
			if ( $sid2nfr{$sid} % $sid2ipr{$sid} == 0 ) { $rapnum = $sid2nfr{$sid} / $sid2ipr{$sid}; }
			else { $rapnum = int($sid2nfr{$sid} / $sid2ipr{$sid}) + 1; }
		}		
		#for (my $ras=0; $ras<$rapnum; $ras++) {
		FORSETID: for (my $ras=0; $ras<$rapnum; $ras++) {
			my $common_fname =  $ExpDir . "/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rapF", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp});
			my $common_dec_fname =  $ExpDir . "/DecoderLOG/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rapF", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp});
			$task_name       =  sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rapF", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp});
			my $FrameSkip    = $ras * $sid2ipr{$sid};
			
		if (( $cstr eq "JR" ) && ($nfrm_is =~ /full/i)){
				$common_fname =  $ExpDir . "/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rap%d", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp}, $ras);
				$common_dec_fname =  $ExpDir . "/DecoderLOG/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rap%d", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp}, $ras);
				$common_concat_fname =  $ExpDir . "/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rapF", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp});
				$task_name    =  sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rap%d", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp}, $ras);
				$concat_task_name    =  sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rapF", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp});
			}
			
			mkdir $ExpDir;
			mkdir "${ExpDir}/DecoderLOG";

			my $log_fname = $common_fname . ".log";
			my $rec_fname = $common_fname . "_rec.yuv";
			my $bin_fname = $common_fname . ".bin";
			my $cfg_fname = $common_fname . ".cfg";
			my $dec_log_fname = $common_dec_fname . ".log";
			my $dec_concat_log_fname = $ExpDir . "/DecoderLOG/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rapF", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, $qpincfrm, $qp2id{$qp}) . ".log";
			my $concat_bin_fname = $common_concat_fname . ".bin";

			my $more_argument = "-c $cfg_fname -b $bin_fname";
			my $concat_more_argument = "-b $concat_bin_fname";
 
			if(( $cstr eq "JR" ) && ($nfrm_is =~ /full/i) && ($FastReEnc) && ($qpincfrm!=0)) {
				my $top_frame = $ras * $sid2ipr{$sid};
				my $end_frame = $top_frame + $sid2ipr{$sid} - 1;
				if($qpincfrm - 1 < $top_frame) {
					# copy configuration and result files from higher integer QP
					my $common_iqph_fname = $ExpDir . "/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rap%d", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp+1, 0, $qp2id{$qp}, $ras);
					my $dec_iqph_fname = $ExpDir . "/DecoderLOG/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rap%d", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp+1, 0, $qp2id{$qp}, $ras) . ".log";
					my $log_iqph_fname = $common_iqph_fname . ".log";
					my $bin_iqph_fname = $common_iqph_fname . ".bin";
					my $cfg_iqph_fname = $common_iqph_fname . ".cfg";
					if(-e $log_iqph_fname) {
						copy($log_iqph_fname, $log_fname) or die "Copy failed: $!";
					} else {
						print ">> integer QP result file is not exist: $log_iqph_fname.\n";
						next FORSETID;
					}
					if(-e $bin_iqph_fname) {
						copy($bin_iqph_fname, $bin_fname) or die "Copy failed: $!";
					} else {
						print ">> integer QP result file is not exist: $bin_iqph_fname.\n";
						next FORSETID;
					}
					if(-e $cfg_iqph_fname) {
						copy($cfg_iqph_fname, $cfg_fname) or die "Copy failed: $!";
					} else {
						print ">> integer QP result file is not exist: $cfg_iqph_fname.\n";
						next FORSETID;
					}
					if(-e $dec_iqph_fname) {
						copy($dec_iqph_fname, $dec_log_fname) or die "Copy failed: $!";
					} else {
						print ">> integer QP result file is not exist: $dec_iqph_fname.\n";
						next FORSETID;
					}
					
					next;	# skip encode and decode
				}
				
				
				if($end_frame < $qpincfrm - 1) {
					# copy configuration and result files from lower integer QP
					
					my $common_iqpl_fname = $ExpDir . "/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rap%d", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, 0, $qp2id{$qp}, $ras);
					my $dec_iqpl_fname = $ExpDir . "/DecoderLOG/" . sprintf("%s_F3_C%01d_S%02d_%s_%02d_%03d_R%01d_rap%d", $setDir, $csBpart2path{$csBpart},  $sid, $sid2shortname{$sid}, $qp, 0, $qp2id{$qp}, $ras) . ".log";
					my $log_iqpl_fname = $common_iqpl_fname . ".log";
					my $bin_iqpl_fname = $common_iqpl_fname . ".bin";
					my $cfg_iqpl_fname = $common_iqpl_fname . ".cfg";
					if(-e $log_iqpl_fname) {
						copy($log_iqpl_fname, $log_fname) or die "Copy failed: $!";
					} else {
						print ">> integer QP result file is not exist: $log_iqpl_fname.\n";
						next FORSETID;
					}
					if(-e $bin_iqpl_fname) {
						copy($bin_iqpl_fname, $bin_fname) or die "Copy failed: $!";
					} else {
						print ">> integer QP result file is not exist: $bin_iqpl_fname.\n";
						next FORSETID;
					}
					if(-e $cfg_iqpl_fname) {
						copy($cfg_iqpl_fname, $cfg_fname) or die "Copy failed: $!";
					} else {
						print ">> integer QP result file is not exist: $cfg_iqpl_fname.\n";
						next FORSETID;
					}
					if(-e $dec_iqpl_fname) {
						copy($dec_iqpl_fname, $dec_log_fname) or die "Copy failed: $!";
					} else {
						print ">> integer QP result file is not exist: $dec_iqpl_fname.\n";
						next FORSETID;
					}
				
					next;	# skip encode and decode
				}
			}

			if($opt_encdec==3 || $opt_encdec==1) # encoding
			{
				if($opt_nooverwrite)
				{
					my $modtime = (stat($log_fname))[9];
					my $time_diff = time() - $modtime;
					#if ($time_diff < 60*60*24*5) #5days
					if (-e $log_fname) #existing
					{
						#printf("file %s existing already\n", $log_fname);  
						next FORSETID;
					}
            
					open L, $log_fname;
					my $completed = 0;
					while(<L>)
					{
						/Total Time:/ and $completed=1; 
						/Total Frames:/ and $completed=1;                  
					}
					close L;
					if($completed)
					{
						#print ">> encoding is already completed. encoding is skipped: $bin_fname.\n";
						next FORSETID;
					}
					#print ">> next valid target: $log_fname.\n";    
				}
			}
			if($opt_encdec==2) # decoding only
			{
				unless (-e $bin_fname)
				{
					#print ">> bitstream does not exist and decoding is skipped: $bin_fname.\n";
					next FORSETID;              
				}
				if($opt_nooverwrite)
				{
					my $modtime = (stat($dec_log_fname))[9];
					my $time_diff = time() - $modtime;
					#if ($time_diff < 10*60)
					if (-e $dec_log_fname) #existing
					{
						#print ">> last modified time is $time_diff sec before. decoding seems being ongoing and to be skipped. $bin_fname.\n";
						next FORSETID;
					}
				
					open L, $dec_log_fname;
					my $completed = 0;
					while(<L>)
					{
						/Total Time:/ and $completed=1;
						/Total decoding time :/ and $completed=1;
					}
					close L;
					
					if($completed)
					{
						#print ">> decoding is already completed and decoding is skipped: $bin_fname.\n";
						next FORSETID;
					}
	
					#print ">> next valid target: $bin_fname.\n";
				}
			}	
			if($opt_encdec==4) # decoding only(concat stream)
			{
				unless (-e $bin_fname)
				{
					#print ">> bitstream does not exist and decoding is skipped: $bin_fname.\n";
					next FORSETID;              
				}
				
				$concat_execution = $concat_execution . " $bin_fname";
					
				if($ras == $rapnum-1)
				{
					if($opt_nooverwrite)
					{
						my $modtime = (stat($dec_concat_log_fname))[9];
						my $time_diff = time() - $modtime;
						#if ($time_diff < 10*60)
						if (-e $dec_concat_log_fname) #existing
						{
							#print ">> last modified time is $time_diff sec before. decoding seems being ongoing and to be skipped. $bin_fname.\n";
							next FORSETID;
						}
				
						open L, $dec_concat_log_fname;
						my $completed = 0;
						while(<L>)
						{
							/Total Time:/ and $completed=1;
							/Total decoding time :/ and $completed=1;
						}
						close L;
					
						if($completed)
						{
							#print ">> decoding is already completed and decoding is skipped: $bin_fname.\n";
							next FORSETID;
						}
	
					}

					# If the last stream, concat all.
					$concat_execution = $concat_execution . " $concat_bin_fname";
					system($concat_execution);
				}
				else
				{
					print ">> find input stream: $bin_fname.\n";
					next;
				}
			}	
	
			if($opt_encdec != 2 && $opt_encdec != 4)
			{
			copy ($cs2cfg{$cstr}, $cfg_fname) or print "copy of $cfg_fname is failed.\n";
			open (C, ">>$cfg_fname");
#       	     print C "\n";
			print C "#================================================= \n";
			
			print C "FrameRate                     : " . ${sid2fps}{$sid}   . "\n"; 
			print C "SourceWidth                   : " . ${sid2width}{$sid} . "\n"; 
			print C "SourceHeight                  : " . $sid2height{$sid}  . "\n";
			if ($csBpart =~ /^[rR]$/){
				print C "IntraPeriod                   : $sid2ipr{$sid}\n"; 
			}
			if($sid2fname{$sid} =~ /10bit/)
			{  
				print C "InputBitDepth                 : 10\n"; 
			}else{
				print C "InputBitDepth                 : 8\n";      
			}
			print C "InputFile                     : ${OrgPath}$sid2fname{$sid}.yuv\n";
			print C "QP                            : $qp\n";
			if($qpincfrm > 0) {
				print C "QPIncrementFrame              : $qpincfrm\n";
			}
			print C "FrameSkip                     : " . $FrameSkip  . "\n";
			if ($csBpart =~ /^[rR]$/){
				my $temp = $sid2ipr{$sid} + 1;
				if ( $rapnum - 1 == $ras ) { $temp = $sid2nfr{$sid} - $FrameSkip; }
				print C "FramesToBeEncoded             : $temp\n";
			} else {
				print C "FramesToBeEncoded             : $sid2nfr{$sid}\n";
			}
			print C "\n";
			if($opt_addlevel){
				print C "Level                         : $sid2level{$sid}\n";	# terada
			}

			if(length($prmbody))
			{
				print C $prmbody, "\n";
			}
			
			if( ($opt_IBC) or (($opt_ClassF_TGM_IBC) and (((23 <= $sid) and ($sid <= 26)) or ((33 <= $sid) and ($sid <= 36)))) )
			{
				print C "IBC                           : 1\n";
			}
			if(($opt_ClassF_TGM_HashME) and (((23 <= $sid) and ($sid <= 26)) or ((33 <= $sid) and ($sid <= 36))))
			{
				print C "HashME                        : 1\n";
				print C "BDPCM                         : 1\n";
			}
			if($opt_inter_MTS)
			{
				print C "MTS                           : 3\n";
			}
			
			close C;
			}
		
			my $time_message;
			my $remain_num_enc = $remain_num_key * @set - $setid;
			$time_message .= "remain=$remain_num_enc, started=$done_exe";
			$time_message .= ", next: cstr=$cstr, qp=$qp, seq=$sid2shortname{$sid}($sid2nfr{$sid})";
	
			my $simpc_ssh;            
			my $cnt = 0;
			END: while(1)   # search loop for free CPU
			{
				sleep 2;   

				FreadRunEncCfg();
	
				foreach my $pc (@simpc)
				{
					my $core   = $pc2core {$pc};
					my $used   = GetNumJob($pc, $core);
					my $remain = $pc2core {$pc} - $used;
					if($remain <= 0)
					{
					    next;
					}
					printf ("%s) core=%d, used=%d, remain=%d\n", $pc, $core, $used, $remain);
					$simpc_ssh = $pc;
					last END;  
				}
				$cnt++;
				if ($cnt > 10) #20sec
				{
				    last JOB;
				}
			}
			
			my $com;
			
			if($opt_encdec == 4)
			{
				# for decoding concat bitstream
				$com = "ssh $simpc_ssh $Cwd/RunOne_r020yuv.pl $yuv_out $csApart2path{$csApart} 2 $Cwd/$setDec $Cwd/$setEnc $ExpDir $concat_task_name $concat_more_argument & \n";
			}
			else
			{
				$com = "ssh $simpc_ssh $Cwd/RunOne_r020yuv.pl $yuv_out $csApart2path{$csApart} $opt_encdec $Cwd/$setDec $Cwd/$setEnc $ExpDir $task_name $more_argument & \n";
			}
	
			if($opt_debug_config_only==0 and $opt_debug==0) 
			{ 
				system "$com"; #print " <<<<< started at $simpc_ssh >>>>>\n";
			}
			
			#write start time into file
			my $file_start = "start.tim";
			if(-e $file_start)
			{
			}
			else
			{
				open my $fh, '>', 'start.tim' or die "Can't create start.tim\n";
				my $timestamp = localtime(time);
				print $fh $timestamp;
				close $fh;
			}			
			
			$done_exe++;
		} #FORSETID: for (my $ras=0; $ras<$ras_num; $ras++)
    } #for(my $setid=0; $setid < @set; $setid++)
}

#write complete time into file
my $alldone = 1;
for(my $setid=0; $setid < @set; $setid++)
{
	my $setDir  = $set[$setid]->Dir;
	my $ExpDir  = "${Cwd}/F3_${setDir}";
	my $cnt1 = 0;
	my $cnt2 = 0;
	++$cnt1 while glob "$ExpDir/*.cfg";
	++$cnt2 while glob "$ExpDir/DecoderLOG/*.log";
	if($cnt1==0 || $cnt2==0 || ($cnt1 != $cnt2))
	{
		$alldone = 0;
		last;
	}
}
if ($alldone == 1)
{
	open my $fh, '>', 'done.tim' or die "Can't create done.tim\n";
	my $timestamp = localtime(time);
	print $fh $timestamp;
	close $fh;
}

if ($done_exe > 0)
{
    print "run=$done_exe\n";
}
else
{
    printf ("no cores or all started\n");
}





__DATA__
---IMAGE---
#   sid     Sequence ID
#   nf      Frames to be encoded with "full"
#   nf2     Frames to be encoded with "0"
#   image   YUV file name
#   short   short file name
#sid    nf  nf2 image   short   level

1   294 65 Tango2_3840x2160_60fps_10bit_420.yuv						Tango2				5.1
2   300 65 FoodMarket4_3840x2160_60fps_10bit_420.yuv				FoodMarket4			5.1
3   300 33 Campfire_3840x2160_30fps_10bit_420_videoRange.yuv		Campfire			5.1

4   300 65 CatRobot1_3840x2160_60_10bit_420.yuv						CatRobot1			5.1
5   300 65 DaylightRoad2_3840x2160_60fps_10bit_420.yuv				DaylightRoad2		5.1
6   300 49 ParkRunning3_3840x2160_50fps_10bit_420.yuv				ParkRunning3		5.1

7   600 65 MarketPlace_1920x1080_60fps_10bit_420.yuv				MarketPlace			4.1
8   600 65 RitualDance_1920x1080_60fps_10bit_420.yuv				RitualDance			4.1
9   500 49 Cactus_1920x1080_50.yuv									Cactus				4.1
10  500 49 BasketballDrive_1920x1080_50.yuv							BasketballDrive		4.1
11  600 65 BQTerrace_1920x1080_60.yuv								BQTerrace			4.1

12  500 49 BasketballDrill_832x480_50.yuv							BasketballDrill		3.1
13  600 65 BQMall_832x480_60.yuv									BQMall				3.1
14  500 49 PartyScene_832x480_50.yuv								PartyScene			3.1
15  300 33 RaceHorses_832x480_30.yuv								RaceHorses			3.1

16  500 49 BasketballPass_416x240_50.yuv							BasketballPass		2.1
17  600 65 BQSquare_416x240_60.yuv									BQSquare			2.1
18  500 49 BlowingBubbles_416x240_50.yuv							BlowingBubbles		2.1
19  300 33 Racehorses_416x240_30.yuv								RaceHorses			2.1

20  600 65 FourPeople_1280x720_60.yuv								FourPeople			4
21  600 65 Johnny_1280x720_60.yuv									Johnny				4
22  600 65 KristenAndSara_1280x720_60.yuv							KristenAndSara		4

23  500 49 BasketballDrillText_832x480_50.yuv						BasketballDrillText	3.1
24  600 65 ArenaOfValor_1920x1080_60_8bit_420.yuv					ArenaOfValor		3.1
25  300 33 SlideEditing_1280x720_30.yuv								SlideEditing		3.1
26  500 17 SlideShow_1280x720_20.yuv								SlideShow			3.1

27  294 65 Tango2_crop_1920x1080_60fps_10bit_420.yuv				Tango2Crop2K		4.1
28  300 65 FoodMarket4_crop_1920x1080_60fps_10bit_420.yuv			FoodMarket4Crop2K	4.1
29  300 33 Campfire_crop_1920x1080_30fps_10bit_420_videoRange.yuv	CampfireCrop2K		4.1

30  300 65 CatRobot1_crop_1920x1080_60_10bit_420.yuv				CatRobot1Crop2K		4.1
31  300 65 DaylightRoad2_crop_1920x1080_60fps_10bit_420.yuv			DaylightRoad2Crop2K	4.1
32  300 49 ParkRunning3_crop_1920x1080_50fps_10bit_420.yuv			ParkRunning3Crop2K	4.1

33  300 65 sc_flyingGraphics_1920x1080_60_8bit_420.yuv				flyingGraphics		4.1
34  600 65 sc_desktop_1920x1080_60_8bit_420.yuv						desktop				4.1
35  600 65 sc_console_1920x1080_60_8bit_420.yuv						console				4.1
36  600 65 ChineseEditing_1920x1080_60_8bit_420.yuv					ChineseEditing		4.1
# JY
37  1809 30 HiEve_20_1280x652_30.yuv					hmInWaitingHall		4.1
38  500 24 HiEve_21_352x258_24.yuv					hmInBus		4.1
39  700 30 HiEve_22_1920x1080_30.yuv					hmInDiningRoom2		4.1
40  2556 30 HiEve_23_1280x720_30.yuv					hmInLab2		4.1
41  1409 30 HiEve_24_704x576_30.yuv					hmInSubwayStation		4.1
42  3070 30 HiEve_25_1920x1080_30.yuv					hmInPassage		4.1
43  1705 30 HiEve_26_456x344_30.yuv					hmInFighting4		4.1
44  1054 30 HiEve_27_1280x720_30.yuv					hmInShoppingMall3		4.1
45  1052 24 HiEve_28_1280x720_24.yuv					hmInRestaurant	4.1
46  766 30 HiEve_29_624x360_30.yuv					hmInAccident		4.1
47  954 30 HiEve_30_640x480_30.yuv					hmInStairs3		4.1
48  423 30 HiEve_31_1280x720_30.yuv					hmInCrossroad		4.1
49  879 30 HiEve_32_1280x720_30.yuv					hmInRobbery		4.1
