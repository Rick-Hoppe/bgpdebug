#!/bin/bash

# BGP and RouteD daemon debug on Gaia 0.2.1
#
#
# Version History
# 0.1    Initial version. Only Security Gateways in VSX are supported.
# 0.2    Security Gateway in Gateway Mode is now supported.
#        Added new menu options: - Show debug status
#                                - Switch to other Virtual System (VSX only)
#                                - Quit the script
# 0.2.1  FIX: Option 6 now only works in VSX mode.
#        Minor quality updates
#
#
#====================================================================================================
# Global variables
#====================================================================================================
if [[ -e /etc/profile.d/CP.sh ]]; then
    source /etc/profile.d/CP.sh
fi

if [[ -e /etc/profile.d/vsenv.sh ]]; then
    source /etc/profile.d/vsenv.sh
fi


#====================================================================================================
# Variables
#====================================================================================================
HOSTNAME=$(hostname -s)
DATE=$(date +%Y%m%d-%H%M%S)
OUTPUTDIR="/var/log/tmp/$HOSTNAME/$DATE"
VERSION="0.2.1"


#====================================================================================================
# Environment checks
#====================================================================================================
clear
printf "BGP and RouteD daemon debug on Gaia v$VERSION\n\n"
printf "Checking my environment...\n"

if [[ ! $ISMGMT -eq 0 ]]; then
   printf "NOT PASSED\nINFO: This script is not intended for management servers.\n"
   exit 1
fi

CLCHK=$(clish -c exit)

if [[ ! -z "$CLCHK" ]]; then
   printf "Clish returns error: $CLCHK\n"
   printf "Please resolve this before executing the script again.\n\n"
   exit 1
fi


#====================================================================================================
# Functions
#====================================================================================================
gw_type_check() {
ISVSX=`$CPDIR/bin/cpprod_util FwIsVSX`

if [[ $ISVSX -eq 1 ]]; then
   printf "Security Gateway runs in VSX Mode\n\n"
   select_vs
else
   printf "Security Gateway runs in Gateway Mode\n\n"
fi
}


select_vs () {
ALL_VSID=$(clish -c "show virtual-system all")
printf "$ALL_VSID\n\n"
read -p "Select Virtual System ID: " -r VIRTUAL_SYSTEM
printf "\n"
vsenv $VIRTUAL_SYSTEM
VSOK=$(echo $?)

if [[ ! $VSOK -eq 0 ]]; then
   printf "\n"
   select_vs
fi
}


questionnaire () {
printf "\n"
printf "  1) Enable BGP and RouteD debug\n"
printf "  2) Disable BGP and RouteD debug\n"
printf "  3) Show debug status\n"
printf "  4) Collect debug information\n"
printf "  5) Collect debug information and CPinfo\n"

if [[ $ISVSX -eq 1 ]]; then
   printf "  6) Change the context to other Virtual System\n"
fi

printf "  q) Quit\n\n"
read -p "Select: " -r ON_OFF
if [[ $ON_OFF == "1" ]]; then
   debug_on
elif [[ $ON_OFF == "2" ]]; then
     debug_off
elif [[ $ON_OFF == "3" ]]; then
     show_debug_status
elif [[ $ON_OFF == "4" ]]; then
     get_bgppeers
     collect_debug
     printf "\nAll collected files are in $OUTPUTDIR\n\n"
elif [[ $ON_OFF == "5" ]]; then
     get_bgppeers
     collect_debug
     get_cpinfo
     printf "\nAll collected files are in $OUTPUTDIR\n\n"
elif [[ $ON_OFF == "6" && $ISVSX -eq 1 ]]; then
     printf "\n"
     select_vs
     questionnaire
elif [[ $ON_OFF == "q" ]]; then
     if [[ ! $COLLECT -eq 1 && -d "$OUTPUTDIR" ]]; then
        printf "\nRemoving temporary directory $OUTPUTDIR\n\n"
        rm -rf $OUTPUTDIR
     fi
     exit 0
else
     printf "\n\nERROR: $ON_OFF is not a valid selection\n\n"
     questionnaire
fi
}


debug_on () {
if [[ $ISVSX -eq 1 ]]; then
   printf "Enabling BGP and RouteD debug for VS$VIRTUAL_SYSTEM\n"
   DEBUG_ON_SCRIPT=$OUTPUTDIR"/VS"$VIRTUAL_SYSTEM"_DEBUG_ENABLE.clish"
   echo "set virtual-system $VIRTUAL_SYSTEM" >$DEBUG_ON_SCRIPT
else
   printf "Enabling BGP and RouteD debug\n"
   DEBUG_ON_SCRIPT="$OUTPUTDIR/DEBUG_ENABLE.clish"
   if [ -f "$DEBUG_ON_SCRIPT" ]; then
      rm $DEBUG_ON_SCRIPT
      touch $DEBUG_ON_SCRIPT
   fi
fi

echo "set tracefile size 10" >>$DEBUG_ON_SCRIPT
echo "set tracefile maxnum 20" >>$DEBUG_ON_SCRIPT
echo "set trace kernel all on" >>$DEBUG_ON_SCRIPT
echo "set trace bgp all on" >>$DEBUG_ON_SCRIPT
echo "save config" >>$DEBUG_ON_SCRIPT
clish -i -f $DEBUG_ON_SCRIPT
rm $DEBUG_ON_SCRIPT
show_debug_status
}


debug_off () {
if [[ $ISVSX -eq 1 ]]; then
   printf "Disabling BGP and RouteD debug for VS$VIRTUAL_SYSTEM\n"
   DEBUG_OFF_SCRIPT=$OUTPUTDIR"/VS"$VIRTUAL_SYSTEM"_DEBUG_DISABLE.clish"
   echo "set virtual-system $VIRTUAL_SYSTEM" >$DEBUG_OFF_SCRIPT
else
   printf "Disabling BGP and RouteD debug\n"
   DEBUG_OFF_SCRIPT="$OUTPUTDIR/DEBUG_DISABLE.clish"
   if [ -f "$DEBUG_OFF_SCRIPT" ]; then
      rm $DEBUG_OFF_SCRIPT
      touch $DEBUG_OFF_SCRIPT
   fi
fi

echo "set trace kernel all off" >>$DEBUG_OFF_SCRIPT
echo "set trace bgp all off" >>$DEBUG_OFF_SCRIPT
echo "save config" >>$DEBUG_OFF_SCRIPT
clish -f $DEBUG_OFF_SCRIPT
rm $DEBUG_OFF_SCRIPT
show_debug_status
}


show_debug_status () {
if [[ $ISVSX -eq 1 ]]; then
   printf "\n"
   vsenv $VIRTUAL_SYSTEM
fi

printf "\n"
dbget -rv routed | grep traceoptions
printf "\n\n"
questionnaire
}

get_bgppeers () {
if [[ $ISVSX -eq 1 ]]; then
   GET_BGP_SCRIPT=$OUTPUTDIR"/VS"$VIRTUAL_SYSTEM"_GET_BGP_PEERS.clish"
   BGP_OUTPUT_TMP=$OUTPUTDIR"/VS"$VIRTUAL_SYSTEM"bgppeers.tmp"
   BGP_OUTPUT=$OUTPUTDIR"/VS"$VIRTUAL_SYSTEM"bgppeers.txt"
   echo "set virtual-system $VIRTUAL_SYSTEM" >$GET_BGP_SCRIPT
else
   GET_BGP_SCRIPT="$OUTPUTDIR/GET_BGP_PEERS.clish"
   if [ -f "$GET_BGP_SCRIPT" ]; then
      rm $GET_BGP_SCRIPT
      touch $GET_BGP_SCRIPT
   fi
   BGP_OUTPUT_TMP="$OUTPUTDIR/bgppeers.tmp"
   if [ -f "$BGP_OUTPUT_TMP" ]; then
      rm $BGP_OUTPUT_TMP
      touch $BGP_OUTPUT_TMP
   fi
   BGP_OUTPUT="$OUTPUTDIR/bgppeers.txt"
   if [ -f "$BGP_OUTPUT" ]; then
      rm $BGP_OUTPUT
      touch $BGP_OUTPUT
   fi
fi

echo "show configuration bgp" >>$GET_BGP_SCRIPT
clish -i -f $GET_BGP_SCRIPT >$BGP_OUTPUT_TMP
grep peer $BGP_OUTPUT_TMP | sed 's/.*\(peer\)/\1/g' | awk '{ print $2 }' | uniq >$BGP_OUTPUT
}


collect_debug () {
if [[ $ISVSX -eq 1 ]]; then
   printf "\nCollecting debug information for VS$VIRTUAL_SYSTEM\n\n"
   COLLECT_SCRIPT=$OUTPUTDIR"/VS"$VIRTUAL_SYSTEM"_COLLECT_DEBUG.clish"
   echo "set virtual-system $VIRTUAL_SYSTEM" >$COLLECT_SCRIPT
else
   printf "\nCollecting debug information\n\n"
   COLLECT_SCRIPT="$OUTPUTDIR/COLLECT_DEBUG.clish"
   if [ -f "$COLLECT_SCRIPT" ]; then
      rm $COLLECT_SCRIPT
      touch $COLLECT_SCRIPT
   fi
fi

echo "show configuration bgp" >>$COLLECT_SCRIPT
echo "show bgp summary" >>$COLLECT_SCRIPT
echo "show bgp errors" >>$COLLECT_SCRIPT
echo "show bgp groups" >>$COLLECT_SCRIPT
echo "show bgp memory" >>$COLLECT_SCRIPT
echo "show bgp paths" >>$COLLECT_SCRIPT
echo "show bgp peers" >>$COLLECT_SCRIPT
echo "show bgp peers detailed" >>$COLLECT_SCRIPT
echo "show bgp peers established" >>$COLLECT_SCRIPT

while read PEER_IP_ADDRESS
do
echo "show bgp peer $PEER_IP_ADDRESS advertise" >>$COLLECT_SCRIPT
echo "show bgp peer $PEER_IP_ADDRESS detailed" >>$COLLECT_SCRIPT
echo "show bgp peer $PEER_IP_ADDRESS received" >>$COLLECT_SCRIPT
done < $BGP_OUTPUT

echo "show bgp routemap" >>$COLLECT_SCRIPT
echo "show route all bgp" >>$COLLECT_SCRIPT
echo "show route bgp" >>$COLLECT_SCRIPT
echo "show route bgp aspath" >>$COLLECT_SCRIPT
echo "show route bgp communities" >>$COLLECT_SCRIPT
echo "show route bgp detailed" >>$COLLECT_SCRIPT
echo "show route bgp metrics" >>$COLLECT_SCRIPT
echo "show route bgp suppressed" >>$COLLECT_SCRIPT
echo "show route inactive bgp" >>$COLLECT_SCRIPT

if [[ $ISVSX -eq 1 ]]; then
   CLISH_OUTPUT_TMP=$OUTPUTDIR/"VS"$VIRTUAL_SYSTEM"_CLISH_OUTPUT.tmp"
   CLISH_OUTPUT=$OUTPUTDIR/"VS"$VIRTUAL_SYSTEM"_CLISH_OUTPUT.log"
   clish -i -o pretty -f $COLLECT_SCRIPT >$CLISH_OUTPUT_TMP
   tr "\015" "\n" <$CLISH_OUTPUT_TMP >$CLISH_OUTPUT
   cp -p /var/log/routed_$VIRTUAL_SYSTEM.lo* $OUTPUTDIR
   vsenv
   cp -p $CPDIR/log/cpwd.el* $OUTPUTDIR
else
   CLISH_OUTPUT_TMP="$OUTPUTDIR/CLISH_OUTPUT.tmp"
   CLISH_OUTPUT="$OUTPUTDIR/CLISH_OUTPUT.log"
   clish -i -o pretty -f $COLLECT_SCRIPT >$CLISH_OUTPUT_TMP
   tr "\015" "\n" <$CLISH_OUTPUT_TMP >$CLISH_OUTPUT
   cp -p /var/log/routed.lo* $OUTPUTDIR
fi

cp -p /var/log/message* $OUTPUTDIR

rm $CLISH_OUTPUT_TMP
rm $GET_BGP_SCRIPT
rm $BGP_OUTPUT_TMP
rm $BGP_OUTPUT
rm $COLLECT_SCRIPT

COLLECT=1
}


get_cpinfo () {
printf "Collecting CPinfo file\n"
cpinfo -D -z -o $OUTPUTDIR/$(uname -n)_BGP_issue.cpinfo
}


#Start
mkdir -p $OUTPUTDIR
gw_type_check
questionnaire
exit 0
