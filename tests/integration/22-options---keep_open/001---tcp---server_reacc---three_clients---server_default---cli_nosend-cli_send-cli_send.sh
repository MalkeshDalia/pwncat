#!/usr/bin/env bash

set -e
set -u
set -o pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
SOURCEPATH="${SCRIPTPATH}/../../.lib/conf.sh"
BINARY="${SCRIPTPATH}/../../../bin/pwncat"
# shellcheck disable=SC1090
source "${SOURCEPATH}"


# -------------------------------------------------------------------------------------------------
# GLOBALS
# -------------------------------------------------------------------------------------------------

RHOST="${1:-localhost}"
RPORT="${2:-4444}"

STARTUP_WAIT="${3:-4}"
RUNS="${4:-1}"

PYTHON="python${5:-}"
PYVER="$( "${PYTHON}" -V 2>&1 | head -1 || true )"


# -------------------------------------------------------------------------------------------------
# TEST FUNCTIONS
# -------------------------------------------------------------------------------------------------
print_test_case "${PYVER}"

run_test() {
	local srv_opts="${1// / }"
	local cli_opts="${2// / }"
	local curr_mutation="${3}"
	local total_mutation="${4}"
	local curr_round="${5}"
	local total_round="${6}"
	local data=
	local data_or=

	print_h1 "[ROUND: ${curr_round}/${total_round}] (mutation: ${curr_mutation}/${total_mutation}) Starting Test Round (srv '${srv_opts}' vs cli '${cli_opts}')"
	run "sleep 1"

	###
	### Create data and files
	###
	data="abcdefghijklmnopqrstuvwxyz1234567890\\n"
	data_or="abcdefghijklmnopqrstuvwxyz1234567890\\r\\n"
	srv_stdout="$(tmp_file)"
	srv_stderr="$(tmp_file)"

	cli1_stdout="$(tmp_file)"
	cli1_stderr="$(tmp_file)"
	cli2_stdout="$(tmp_file)"
	cli2_stderr="$(tmp_file)"
	cli3_stdout="$(tmp_file)"
	cli3_stderr="$(tmp_file)"


	###
	###
	### Initial Server Start
	###
	###

	# --------------------------------------------------------------------------------
	# START: SERVER
	# --------------------------------------------------------------------------------
	print_h2 "(1/13) Start: Server"

	# Start Server
	print_info "Start Server"
	# shellcheck disable=SC2086
	if ! srv_pid="$( run_bg "" "${PYTHON}" "${BINARY}" ${srv_opts} "${srv_stdout}" "${srv_stderr}" )"; then
		printf ""
	fi

	# Wait until Server is up
	run "sleep ${STARTUP_WAIT}"

	# [SERVER] Ensure Server is running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [SERVER] Ensure Server has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"


	###
	###
	### ROUND-1 (NO SEND)
	###
	###

	# --------------------------------------------------------------------------------
	# [ROUND-1: NO SEND] START: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(2/13) Start: Client (round 1)"

	# Start Client
	print_info "Start Client"
	# shellcheck disable=SC2086
	if ! cli_pid="$( run_bg "" "${PYTHON}" "${BINARY}" ${cli_opts} "${cli1_stdout}" "${cli1_stderr}" )"; then
		printf ""
	fi

	# Wait until Client is up
	run "sleep ${STARTUP_WAIT}"

	# [CLIENT] Ensure Client is running
	test_case_instance_is_running "Client" "${cli_pid}" "${cli1_stdout}" "${cli1_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli1_stdout}" "${cli1_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [SERVER] Ensure Server is still is running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli1_stdout}" "${cli1_stderr}"

	# [SERVER] Ensure Server still has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli1_stdout}" "${cli1_stderr}"


	# --------------------------------------------------------------------------------
	# [ROUND-1: NO SEND] STOP: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(3/13) Stop: Client (round 1)"

	# [CLIENT] Manually stop the Client
	action_stop_instance "Client" "${cli_pid}" "${cli1_stdout}" "${cli1_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client still has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli1_stdout}" "${cli1_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"


	# --------------------------------------------------------------------------------
	# [ROUND-1: NO SEND] TEST: Server stays alive
	# --------------------------------------------------------------------------------
	print_h2 "(4/13) Test: Server stays alive (round 1)"
	run "sleep 2"

	# [SERVER] Ensure Server has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli1_stdout}" "${cli1_stderr}"

	# [SERVER] Ensure Server is still running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli1_stdout}" "${cli1_stderr}"


	###
	###
	### ROUND-2 (SEND)
	###
	###

	# --------------------------------------------------------------------------------
	# [ROUND-2: SEND] START: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(5/13) Start: Client (round 2)"

	# Start Client
	print_info "Start Client"
	# shellcheck disable=SC2086
	if ! cli_pid="$( run_bg "printf ${data}" "${PYTHON}" "${BINARY}" ${cli_opts} "${cli2_stdout}" "${cli2_stderr}" )"; then
		printf ""
	fi

	# Wait until Client is up
	run "sleep ${STARTUP_WAIT}"

	# [CLIENT] Ensure Client is running
	test_case_instance_is_running "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [SERVER] Ensure Server is still is running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}"

	# [SERVER] Ensure Server still has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}"


	# --------------------------------------------------------------------------------
	# [ROUND-2: SEND] DATA TRANSFER
	# --------------------------------------------------------------------------------
	print_h2 "(6/13) Transfer: Client -> Server (round 2)"

	# [CLIENT -> SERVER]
	wait_for_data_transferred "" "${data}" "${data_or}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}"


	# --------------------------------------------------------------------------------
	# [ROUND-2: SEND] STOP: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(7/13) Stop: Client (round 2)"

	# [CLIENT] Manually stop the Client
	action_stop_instance "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client still has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"


	# --------------------------------------------------------------------------------
	# [ROUND-2: SEND] TEST: Server stays alive
	# --------------------------------------------------------------------------------
	print_h2 "(8/13) Test: Server stays alive (round 2)"
	run "sleep 2"

	# [SERVER] Ensure Server has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}"

	# [SERVER] Ensure Server is still running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli2_stdout}" "${cli2_stderr}"


	###
	###
	### ROUND-3 (SEND)
	###
	###

	# --------------------------------------------------------------------------------
	# [ROUND-3: SEND] START: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(9/13) Start: Client (round 3)"

	# Start Client
	print_info "Start Client"
	# shellcheck disable=SC2086
	if ! cli_pid="$( run_bg "printf ${data}" "${PYTHON}" "${BINARY}" ${cli_opts} "${cli3_stdout}" "${cli3_stderr}" )"; then
		printf ""
	fi

	# Wait until Client is up
	run "sleep ${STARTUP_WAIT}"

	# [CLIENT] Ensure Client is running
	test_case_instance_is_running "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [SERVER] Ensure Server is still is running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}"

	# [SERVER] Ensure Server still has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}"


	# --------------------------------------------------------------------------------
	# [ROUND-3: SEND] DATA TRANSFER
	# --------------------------------------------------------------------------------
	print_h2 "(10/13) Transfer: Client -> Server (round 3)"

	# [CLIENT -> SERVER]
	wait_for_data_transferred "" "${data}${data}" "${data_or}${data_or}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}"


	# --------------------------------------------------------------------------------
	# [ROUND-3: SEND] STOP: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(11/13) Stop: Client (round 3)"

	# [CLIENT] Manually stop the Client
	action_stop_instance "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client still has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"


	# --------------------------------------------------------------------------------
	# [ROUND-3: SEND] TEST: Server stays alive
	# --------------------------------------------------------------------------------
	print_h2 "(12/13) Test: Server stays alive (round 3)"
	run "sleep 2"

	# [SERVER] Ensure Server has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}"

	# [SERVER] Ensure Server is still running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}"


	###
	###
	### Final Server Shutdown
	###
	###

	# --------------------------------------------------------------------------------
	# STOP: SERVER
	# --------------------------------------------------------------------------------
	print_h2 "(13/13) Stop: Server"

	# [SERVER] Manually stop the Server
	action_stop_instance "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}"

	# [SERVER] Ensure Server has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli3_stdout}" "${cli3_stderr}"
}


# -------------------------------------------------------------------------------------------------
# MAIN ENTRYPOINT
# -------------------------------------------------------------------------------------------------

for curr_round in $(seq "${RUNS}"); do
	#         server opts            client opts
	# BIND ON ANY
	run_test "-l ${RPORT} --no-shutdown    --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown    -vvvv"  "1" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RPORT} --no-shutdown    --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown -4 -vvvv"  "2" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RPORT} --no-shutdown    --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown -6 -vvvv"  "3" "14" "${curr_round}" "${RUNS}"

	run_test "-l ${RPORT} --no-shutdown -4 --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown    -vvvv"  "4" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RPORT} --no-shutdown -4 --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown -4 -vvvv"  "5" "14" "${curr_round}" "${RUNS}"

	run_test "-l ${RPORT} --no-shutdown -6 --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown    -vvvv"  "6" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RPORT} --no-shutdown -6 --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown -6 -vvvv"  "7" "14" "${curr_round}" "${RUNS}"

	# BIND ON SPECIFIC
	run_test "-l ${RHOST} ${RPORT} --no-shutdown    --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown    -vvvv"   "8" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RHOST} ${RPORT} --no-shutdown    --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown -4 -vvvv"   "9" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RHOST} ${RPORT} --no-shutdown    --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown -6 -vvvv"  "10" "14" "${curr_round}" "${RUNS}"

	run_test "-l ${RHOST} ${RPORT} --no-shutdown -4 --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown    -vvvv"  "11" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RHOST} ${RPORT} --no-shutdown -4 --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown -4 -vvvv"  "12" "14" "${curr_round}" "${RUNS}"

	run_test "-l ${RHOST} ${RPORT} --no-shutdown -6 --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown    -vvvv"  "13" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RHOST} ${RPORT} --no-shutdown -6 --keep-open -vvvv" "${RHOST} ${RPORT} --no-shutdown -6 -vvvv"  "14" "14" "${curr_round}" "${RUNS}"
done
