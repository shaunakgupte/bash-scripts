#!/bin/bash
#===============================================================================
#
#         FILE: tester.sh
#
#        USAGE: tester.sh [options] /path/to/tests/file
#
#  DESCRIPTION: Script to automate testing of programs.
#
#      OPTIONS: see function 'usage' below
#
#       AUTHOR: Shaunak Gupte <gupte.shaunak@gmail.com>
#
#===============================================================================

NUM_ITER=1
TEST_TIMEOUT=0
PROFILING=0
VALID_DEC_REGEX='^[0-9]+([.][0-9]+)?$'
VALID_NUM_REGEX='^[0-9]+$'
TESTS_OUTPUT="tester_$(date +"%Y%m%d_%H%M")"
TEST_TIME_STEP="0.1"

function usage {
echo "
usage: tester.sh [-h] [-n count] [-t timeout] [-o output_dir] /path/to/tests/file

  -n count       Global Iteration count (Default = 1, Infinite = 0)
  -t timeout     Global Timeout in seconds (Default = 1, Infinite = 0)
  -o output_dir  Path to output directory
  -p             Enable profiling. [Currently only time profiling is supported]
  -h             This help message

The global iteration count and timeout can be overridden for individual tests
in the test vectors file.

Report bugs to: Shaunak Gupte <gupte.shaunak@gmail.com>

Format of the Test Vectors File:

# This is a comment
# This test fails
test=>sleep 10
timeout=>5

# This test passes
test=>sleep 4
timeout=>5
count=>3

# You can write your own programs/scripts to verify the program output
# It should return proper error codes to detect failure

# This will fail
test=>touch log.txt
verify=>ls log.txt1

# This will pass
test=>touch log.txt2
verify=>ls log.txt2
"
}

while getopts ":n:t:hpo:" opt; do
  case $opt in
    n)
      if ! [[ $OPTARG =~ $VALID_NUM_REGEX ]] ; then
        echo "Invalid argument for -n. Number is expected"
        exit 0
      fi
      NUM_ITER=$OPTARG ;;
    t)
      if ! [[ $OPTARG =~ $VALID_DEC_REGEX ]] ; then
        echo "Invalid argument for -t. Number is expected"
        exit 0
      fi
      TEST_TIMEOUT=$OPTARG ;;
    h)
      usage
      exit 0 ;;
    o)
      if [[ ! -d "$OPTARG" ]]; then
        echo "Error output directoy '$OPTARG' not found"
        exit 0
      fi
      TESTS_OUTPUT=$OPTARG ;;
    p)
      PROFILING=1 ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 0 ;;
    :)
      echo "Option -$OPTARG requires an argument" >&2
      exit 0;;
    *)
      TESTS_FILE=$OPTARG
      if [ ! -f "$TESTS_FILE" ]; then
        echo "File $TESTS_FILE not found" >&2
        exit 0
      fi ;;
  esac
done

shift $((OPTIND - 1))
TESTS_FILE=$1

if [ -z "$TESTS_FILE" ]; then
  echo "Specify a tests file" >&2
  usage
  exit 0
fi

if [ ! -f "$TESTS_FILE" ]; then
  echo "Tests file '$TESTS_FILE' not found" >&2
  exit 0
fi

if [ $PROFILING -eq 1 ]; then
  TEST_TIMEOUT=0
fi

##### PARSE FILE ########
PARSE_ERROR=0

TESTS=()
COUNTS=()
TIMEOUTS=()
VERIFYS=()
IS_IGNORES=()
IS_NEGATIVES=()

ICOUNT=$NUM_ITER
ITIMEOUT=$TEST_TIMEOUT
IVERIFY=""
ICMD=""
IIS_NEGATIVE=0
IIS_IGNORE=0

TEST_CNT=0

i=0

while read line
do
i=$((i+1))
line=`echo "$line" | xargs`
if [[ $line == \#* ]]; then
  continue;
fi

if [ -z "$line" ]; then
  continue;
fi

key=`echo $line | awk -F"=>" '{print $1}' | xargs`
value=`echo $line | awk -F"=>" '{print $2}' | xargs`
if [ -z "$key" ]; then
  echo "Error in line $i: Key not found" >&2
  PARSE_ERROR=1
fi
if [ -z "$value" ]; then
  echo "Error in line $i: Value not found" >&2
  PARSE_ERROR=1
fi

case $key in
  timeout)
      if ! [[ $value =~ $VALID_DEC_REGEX ]] ; then
        echo "Error in line $i: Value for timeout should be a number. Got '$value'" >&2
        PARSE_ERROR=1
      elif [ $PROFILING -eq 0 ]; then
        ITIMEOUT=$value
      fi ;;
  count)
      if ! [[ $value =~ $VALID_NUM_REGEX ]] ; then
        echo "Error in line $i: Value for count should be a number. Got '$value'" >&2
        PARSE_ERROR=1
      else
        ICOUNT=$value
      fi ;;
  test)
    PROG=`echo $value | awk '{print $1}'`
    if [ -z "`which $PROG`" ]; then
        echo "Error in line $i: Value for test should be an executable with arguments. Got '$value'" >&2
        PARSE_ERROR=1
      else
        if [ ! -z "${ICMD}" ]; then
          TESTS+=("$ICMD")
          COUNTS+=($ICOUNT)
          TIMEOUTS+=($ITIMEOUT)
          VERIFYS+=("$IVERIFY")
          IS_NEGATIVES+=($IIS_NEGATIVE)
          IS_IGNORES+=($IIS_IGNORE)
          TEST_CNT=$((TEST_CNT + 1))
        fi
        ICOUNT=$NUM_ITER
        ITIMEOUT=$TEST_TIMEOUT
        IVERIFY=""
        ICMD=$value
        IIS_IGNORE=0
        IIS_NEGATIVE=0
      fi ;;
  verify)
    PROG=`echo $value | awk '{print $1}'`
    if [ -z "`which $PROG`" ]; then
        echo "Error in line $i: Value for verify should be an executable with arguments. Got '$value'" >&2
        PARSE_ERROR=1
      else
        IVERIFY=$value
      fi ;;
  negative)
      if ! [[ $value =~ $VALID_NUM_REGEX ]] ; then
        echo "Error in line $i: Value for count should be a number. Got '$value'" >&2
        PARSE_ERROR=1
      else
        IIS_NEGATIVE=$value
      fi ;;
  ignore)
      if ! [[ $value =~ $VALID_NUM_REGEX ]] ; then
        echo "Error in line $i: Value for count should be a number. Got '$value'" >&2
        PARSE_ERROR=1
      else
        IIS_IGNORE=$value
      fi ;;
  *)
  echo "Error in line $i: Not a valid key '$key'" >&2
  PARSE_ERROR=1;;
esac
done < $TESTS_FILE

if [ ! -z "${ICMD}" ]; then
  TESTS+=("$ICMD")
  COUNTS+=($ICOUNT)
  TIMEOUTS+=($ITIMEOUT)
  VERIFYS+=("$IVERIFY")
  TEST_CNT=$((TEST_CNT + 1))
  IS_NEGATIVES+=($IIS_NEGATIVE)
  IS_IGNORES+=($IIS_IGNORE)
fi

if [ $PARSE_ERROR -eq 1 ]; then
  echo "Error parsing File '$TESTS_FILE'" >&2
  exit 0;
fi

mkdir -p $TESTS_OUTPUT


# Run all the tests
function run_test_timed {
  local ITEST=$1
  local ITIMEOUT=$2
  local IITER=$3
  local ICOUNT=$4
  local ITESTNO=$5
  local IVERIFY=$6
  local IIS_NEGATIVE=$7

  LOG_FILE="$TESTS_OUTPUT/${ITESTNO}_$(echo "$ITEST" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
  mkdir -p "$LOG_FILE"
  LOG_FILE="$LOG_FILE/$IITER"

  local ret=0

  echo -e "\nTEST = \"$ITEST\"\n"
  echo -e "========================================================================================\n"

  $ITEST >>"$LOG_FILE" 2>&1 || echo $? > fail &

  local START_TIME=`date +%s%3N`
  CUR_TEST_TIME=0

  while [[ `echo "$ITIMEOUT==0" | bc` -eq 1 || `echo "$CUR_TEST_TIME < $ITIMEOUT" | bc` -eq 1 ]]; do
    echo -ne "$IITER/$ICOUNT.......[$CUR_TEST_TIME sec]\r"
    local CUR_TIME=`date +%s%3N`
    CUR_TEST_TIME=`echo "scale=2; ($CUR_TIME -$START_TIME) / 1000 " | bc`
    jobs > /dev/null
    NUM_JOBS=$(jobs | wc -l)
    [[ $NUM_JOBS -eq 0 ]] && break
    sleep $TEST_TIME_STEP
  done

    jobs > /dev/null
    NUM_JOBS=$(jobs | wc -l)
    [[ $NUM_JOBS -eq 0 ]] || ret=2
    if [ $ret -eq 2 ]; then
      kill -9 %1 2>/dev/null >/dev/null
      echo -e "\n-------------------------- TIMED OUT & KILLED [Timeout = $ITIMEOUT sec] -------------------------"
    else
      if [ -f fail ]; then
        if [[ $IIS_NEGATIVE -ne 0 ]]; then
          if cat fail | grep 139 > /dev/null ; then
            rm fail
            ret=1
            echo -e "\n-------------------- NEGATIVE TEST FAILED [Running Time = $CUR_TEST_TIME sec] -------------------"
          else
            rm fail
            echo -e "\n-------------------- NEGATIVE TEST PASSED [Running Time = $CUR_TEST_TIME sec] -------------------"
          fi
        else
          ret=1
          rm fail
          echo -e "\n-------------------------- FAILED [Running Time = $CUR_TEST_TIME sec] -------------------------"
        fi
      else
        if [[ $IIS_NEGATIVE -ne 0 ]]; then
          ret=1
          rm fail
          echo -e "\n-------------------- NEGATIVE TEST FAILED [Running Time = $CUR_TEST_TIME sec] -------------------"
        else
          if [ -z "$IVERIFY" ]; then
            echo -e "\n-------------------------- PASSED [Running Time = $CUR_TEST_TIME sec] -------------------------"
          else
            echo -e "========================================================================================\n"
            $IVERIFY || ret=1
            if [ $ret -eq 0 ]; then
              echo -e "\n-------------------------- PASSED [Running Time = $CUR_TEST_TIME sec] -------------------------"
            else
              echo -e "\n------------------ VERIFICATION FAILED [Running Time = $CUR_TEST_TIME sec] -----------------"
            fi
          fi
        fi
      fi
    fi
  return $ret
}

echo Total Tests=$TEST_CNT

TESTS_SUCCESSFUL=()
TESTS_FAILED=()
TESTS_TIMEDOUT=()
TESTS_IGNORED=()

i=0
while [ $i -lt $TEST_CNT ];
do
  j=0
  ITEST=${TESTS[$i]}
  ICOUNT=${COUNTS[$i]}
  ITIMEOUT=${TIMEOUTS[$i]}
  IVERIFY=${VERIFYS[$i]}
  IIS_NEGATIVE=${IS_NEGATIVES[$i]}
  IIS_IGNORE=${IS_IGNORES[$i]}
  TOTAL_TIME=0

  echo -e "\n\n"
  echo ================================================================================================
  echo TEST = $ITEST
  echo COUNT = $ICOUNT
  echo TIMEOUT = $ITIMEOUT
  echo VERIFICATION = $IVERIFY
  echo IS_NEGATIVE = $IIS_NEGATIVE
  echo IS_IGNORE = $IIS_IGNORE
  SUCCESS=1

  while [[ $ICOUNT -eq 0 || $j -lt $ICOUNT ]];
  do
    k=$((j+1))

    LOG_FILE="$TESTS_OUTPUT/${i}_$(echo "$ITEST" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
    mkdir -p "$LOG_FILE"
    LOG_FILE="$LOG_FILE/$k"

    run_test_timed "$ITEST" $ITIMEOUT $k $ICOUNT $i "$IVERIFY" "$IIS_NEGATIVE" >(tee "$LOG_FILE")
    TEST_RET=$?
    echo -n "$k/$ICOUNT......."
    case $TEST_RET in
      0)
        echo "[Passed]"
        TOTAL_TIME=`echo "scale=2; $TOTAL_TIME + $CUR_TEST_TIME" | bc`
        ;;
      1)
        echo "[Failed]"
        SUCCESS=0
        if [[ $IIS_IGNORE -eq 0 ]]; then
          TESTS_FAILED+=("[$i] $ITEST Iteration = $k")
        fi
        j=$ICOUNT;
        ;;
      2)
        echo "[Timed Out]"
        SUCCESS=0
        if [[ $IIS_IGNORE -eq 0 ]]; then
          TESTS_TIMEDOUT+=("[$i] $ITEST Iteration = $k")
        fi
        j=$ICOUNT;
        ;;
    esac
    j=$((j+1))
  done

  if [[ $IIS_IGNORE -ne 0 ]]; then
    echo "SUCCESS=$SUCCESS"
      if [[ $SUCCESS -eq 0 ]]; then
        TESTS_IGNORED+=("[$i] $ITEST : FAILED")
      else
        TESTS_IGNORED+=("[$i] $ITEST : PASSED")
      fi
  elif [ $SUCCESS -eq 1 ]; then
    if [ $PROFILING -eq 1 ]; then
      AVG_TIME=`echo "scale=2; $TOTAL_TIME / $ICOUNT" | bc`
      TESTS_SUCCESSFUL+=("[$i] $ITEST (Avg. Time = $AVG_TIME sec)")
    else
      TESTS_SUCCESSFUL+=("[$i] $ITEST")
    fi
  fi

  echo ================================================================================================
  i=$((i+1))
done

SUCCESS=1
if [ ${#TESTS_FAILED[@]} -ne 0 ]; then
  SUCCESS=0
  echo -e "\n\nFollowing Tests Failed. Check logs in $TESTS_OUTPUT"
  echo -e "------------------------------------------------------------------------------------------------\n"
  for i in "${TESTS_FAILED[@]}"
  do
    echo $i
    echo
  done
  echo "------------------------------------------------------------------------------------------------"
fi

if [ ${#TESTS_TIMEDOUT[@]} -ne 0 ]; then
  SUCCESS=0
  echo -e "\n\nFollowing Tests Timed out. Check logs in $TESTS_OUTPUT"
  echo -e "------------------------------------------------------------------------------------------------\n"
  for i in "${TESTS_TIMEDOUT[@]}"
  do
    echo $i
    echo
  done
  echo "------------------------------------------------------------------------------------------------"
fi

if [ ${#TESTS_IGNORED[@]} -ne 0 ]; then
  echo -e "\n\nFollowing Tests were Ignored. Check logs in $TESTS_OUTPUT"
  echo -e "------------------------------------------------------------------------------------------------\n"
  for i in "${TESTS_IGNORED[@]}"
  do
    echo $i
    echo
  done
  echo "------------------------------------------------------------------------------------------------"
fi

if [[ $SUCCESS -eq 1 && $PROFILING -eq 0 ]]; then
  echo "All Tests Successful"
else
  if [ ${#TESTS_SUCCESSFUL[@]} -ne 0 ]; then
    echo -e "\n\nFollowing Tests Passed. Check logs in $TESTS_OUTPUT"
    echo -e "------------------------------------------------------------------------------------------------\n"
    for i in "${TESTS_SUCCESSFUL[@]}"
    do
      echo $i
      echo
    done
    echo "------------------------------------------------------------------------------------------------"
  fi
fi
