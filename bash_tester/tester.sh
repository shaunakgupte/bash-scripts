#!/bin/bash
#===============================================================================
#
#         FILE: tester.sh
#
#        USAGE: tester.sh [-n count] [-t timeout] -f <Tests File>
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
VALID_NUM_REGEX='^[0-9]+$'

function usage {
echo "
usage: tester.sh [-h] [-n count] [-t timeout] -f <Tests File>

  -n count       Global Iteration count (Default = 1, Infinite = 0)
  -t timeout     Global Timeout in seconds (Default = 1, Infinite = 0)
  -f <file>      File that contains the test vectors

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

while getopts ":n:t:h" opt; do
  case $opt in
    n)
      if ! [[ $OPTARG =~ $VALID_NUM_REGEX ]] ; then
        echo "Invalid argument for -n. Number is expected"
        exit 0
      fi
      NUM_ITER=$OPTARG ;;
    t)
      if ! [[ $OPTARG =~ $VALID_NUM_REGEX ]] ; then
        echo "Invalid argument for -t. Number is expected"
        exit 0
      fi
      TEST_TIMEOUT=$OPTARG ;;
    h)
      usage
      exit 0 ;;
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

##### PARSE FILE ########
PARSE_ERROR=0

TESTS=()
COUNTS=()
TIMEOUTS=()
VERIFYS=()

ICOUNT=$NUM_ITER
ITIMEOUT=$TEST_TIMEOUT
IVERIFY=""
ICMD=""

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
      if ! [[ $value =~ $VALID_NUM_REGEX ]] ; then
        echo "Error in line $i: Value for timeout should be a number. Got '$value'" >&2
        PARSE_ERROR=1
      else
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
          TEST_CNT=$((TEST_CNT + 1))
        fi
        ICOUNT=$NUM_ITER
        ITIMEOUT=$TEST_TIMEOUT
        IVERIFY=""
        ICMD=$value
      fi ;;
  verify)
    PROG=`echo $value | awk '{print $1}'`
    if [ -z "`which $PROG`" ]; then
        echo "Error in line $i: Value for verify should be an executable with arguments. Got '$value'" >&2
        PARSE_ERROR=1
      else
        IVERIFY=$value
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
fi

if [ $PARSE_ERROR -eq 1 ]; then
  echo "Error parsing File '$TESTS_FILE'" >&2
  exit 0;
fi

rm -rf test_logs
mkdir -p test_logs


# Run all the tests
function run_test_timed {
  local ITEST=$1
  local ITIMEOUT=$2
  local IITER=$3
  local ICOUNT=$4
  local ITESTNO=$5
  local IVERIFY=$6
  it=0
#LOG_FILE="test_logs/$(echo "$ITEST" | sed -e 's/[^A-Za-z0-9._-]/_/g')_$IITER"
  LOG_FILE="test_logs/${ITESTNO}_$(echo "$ITEST" | sed -e 's/[^A-Za-z0-9._-]/_/g')"
  mkdir -p "$LOG_FILE"
  LOG_FILE="$LOG_FILE/$IITER"

  ret=0

  echo -e "\nTEST = \"$ITEST\"\n" >"$LOG_FILE"
  echo -e "========================================================================================\n" >>"$LOG_FILE"

  $ITEST >>"$LOG_FILE" 2>&1 || touch fail &
  PID=$!

  while [[ $ITIMEOUT -eq 0 || $it -ne $ITIMEOUT ]]; do
    echo -ne "$IITER/$ICOUNT.......[$it sec]\r"
    kill -0 $PID 2>/dev/null >/dev/null || break
    it=$((it+1))
    sleep 1
  done 

    kill -0 $PID 2>/dev/null >/dev/null && ret=2
    if [ $ret -eq 2 ]; then
      kill -9 $PID 2>/dev/null >/dev/null
      echo -e "\n-------------------------- TIMED OUT & KILLED [Timeout = $ITIMEOUT sec] -------------------------" >> "$LOG_FILE"
    else
      if [ -f fail ]; then
        ret=1
        rm fail
        echo -e "\n-------------------------- FAILED [Running Time = $it sec] -------------------------" >> "$LOG_FILE"
      else
        if [ -z "$IVERIFY" ]; then
          echo -e "\n-------------------------- PASSED [Running Time = $it sec] -------------------------" >> "$LOG_FILE"
        else
          echo -e "========================================================================================\n" >>"$LOG_FILE"
          $IVERIFY >> "$LOG_FILE" 2>&1 || ret=1
          if [ $ret -eq 0 ]; then
            echo -e "\n-------------------------- PASSED [Running Time = $it sec] -------------------------" >> "$LOG_FILE"
          else
            echo -e "\n------------------ VERIFICATION FAILED [Running Time = $it sec] -----------------" >> "$LOG_FILE"
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

i=0
while [ $i -lt $TEST_CNT ];
do
  j=0
  ITEST=${TESTS[$i]}
  ICOUNT=${COUNTS[$i]}
  ITIMEOUT=${TIMEOUTS[$i]}
  IVERIFY=${VERIFYS[$i]}
  
  echo -e "\n\n"
  echo ================================================================================================
  echo TEST = $ITEST
  echo COUNT = $ICOUNT
  echo TIMEOUT = $ITIMEOUT
  echo VERIFICATION = $IVERIFY
  SUCCESS=1
  
  while [[ $ICOUNT -eq 0 || $j -lt $ICOUNT ]];
  do
    k=$((j+1))
    run_test_timed "$ITEST" $ITIMEOUT $k $ICOUNT $i "$IVERIFY"
    echo -n "$k/$ICOUNT......."
    case $ret in
      0)
        echo "[Passed]"
        ;;
      1)
        echo "[Failed]"
        SUCCESS=0
        TESTS_FAILED+=("[$i] $ITEST Iteration = $k")
        j=$ICOUNT;
        ;;
      2)
        echo "[Timed Out]"
        SUCCESS=0
        TESTS_TIMEDOUT+=("[$i] $ITEST Iteration = $k")
        j=$ICOUNT;
        ;;
    esac
    j=$((j+1))
  done

  if [ $SUCCESS -eq 1 ]; then
    TESTS_SUCCESSFUL+=("[$i] $ITEST")
  fi
   
  echo ================================================================================================
  i=$((i+1))
done

SUCCESS=1
if [ ${#TESTS_FAILED[@]} -ne 0 ]; then
  SUCCESS=0
  echo -e "\n\nFollowing Tests Failed. Check logs in test_logs"
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
  echo -e "\n\nFollowing Tests Timed out. Check logs in test_logs"
  echo -e "------------------------------------------------------------------------------------------------\n"
  for i in "${TESTS_TIMEDOUT[@]}"
  do
    echo $i
    echo
  done
  echo "------------------------------------------------------------------------------------------------"
fi
if [ $SUCCESS -eq 1 ]; then
  echo "All Tests Successful"
else
  if [ ${#TESTS_SUCCESSFUL[@]} -ne 0 ]; then
    echo -e "\n\nFollowing Tests Passed. Check logs in test_logs"
    echo -e "------------------------------------------------------------------------------------------------\n"
    for i in "${TESTS_SUCCESSFUL[@]}"
    do
      echo $i
      echo
    done
    echo "------------------------------------------------------------------------------------------------"
  fi
fi
