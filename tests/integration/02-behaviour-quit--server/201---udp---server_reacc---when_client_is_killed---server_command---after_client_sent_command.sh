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

	print_h1 "[ROUND: ${curr_round}/${total_round}] (mutation: ${curr_mutation}/${total_mutation}) Starting Test Round (srv '${srv_opts}' vs cli '${cli_opts}')"
	run "sleep 1"

	###
	### Create data and files
	###
	data="whoami\\n"
	expect="$(whoami)\\n"
	expect_or="$(whoami)\\r\\n"
	srv_stdout="$(tmp_file)"
	srv_stderr="$(tmp_file)"
	cli_stdout="$(tmp_file)"
	cli_stderr="$(tmp_file)"


	# --------------------------------------------------------------------------------
	# START: SERVER
	# --------------------------------------------------------------------------------
	print_h2 "(1/10) Start: Server"

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


	# --------------------------------------------------------------------------------
	# START: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(2/10) Start: Client (round 1)"

	# Start Client
	print_info "Start Client"
	# shellcheck disable=SC2086
	if ! cli_pid="$( run_bg "printf ${data}" "${PYTHON}" "${BINARY}" ${cli_opts} "${cli_stdout}" "${cli_stderr}" )"; then
		printf ""
	fi

	# Wait until Client is up
	run "sleep ${STARTUP_WAIT}"

	# [CLIENT] Ensure Client is running
	test_case_instance_is_running "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [SERVER] Ensure Server is still is running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"

	# [SERVER] Ensure Server still has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"


	# --------------------------------------------------------------------------------
	# DATA TRANSFER
	# --------------------------------------------------------------------------------
	print_h2 "(3/10) Transfer: Client -> Server -> Client (round 1)"

	# [CLIENT -> SERVER -> CLIENT]
	wait_for_data_transferred "" "${expect}" "${expect_or}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"


	# --------------------------------------------------------------------------------
	# STOP: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(4/10) Stop: Client (round 1)"

	# [CLIENT] Manually stop the Client
	action_stop_instance "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client still has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"


	# --------------------------------------------------------------------------------
	# TEST: Server stays alive
	# --------------------------------------------------------------------------------
	print_h2 "(5/10) Test: Server stays alive (round 1)"
	run "sleep 2"

	# [SERVER] Ensure Server has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"

	# [SERVER] Ensure Server is still running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"


	# --------------------------------------------------------------------------------
	# START: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(6/10) Start: Client (round 2)"

	# Start Client
	print_info "Start Client"
	# shellcheck disable=SC2086
	if ! cli_pid="$( run_bg "printf ${data}" "${PYTHON}" "${BINARY}" ${cli_opts} "${cli_stdout}" "${cli_stderr}" )"; then
		printf ""
	fi

	# Wait until Client is up
	run "sleep ${STARTUP_WAIT}"

	# [CLIENT] Ensure Client is running
	test_case_instance_is_running "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [SERVER] Ensure Server is still is running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"

	# [SERVER] Ensure Server still has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"


	# --------------------------------------------------------------------------------
	# DATA TRANSFER
	# --------------------------------------------------------------------------------
	print_h2 "(7/10) Transfer: Client -> Server -> Client (round 2)"

	# [CLIENT -> SERVER -> CLIENT]
	wait_for_data_transferred "" "${expect}" "${expect_or}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"


	# --------------------------------------------------------------------------------
	# STOP: CLIENT
	# --------------------------------------------------------------------------------
	print_h2 "(8/10) Stop: Client (round 2)"

	# [CLIENT] Manually stop the Client
	action_stop_instance "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"

	# [CLIENT] Ensure Client still has no errors
	test_case_instance_has_no_errors "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}" "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}"


	# --------------------------------------------------------------------------------
	# TEST: Server stays alive
	# --------------------------------------------------------------------------------
	print_h2 "(9/10) Test: Server stays alive (round 2)"
	run "sleep 2"

	# [SERVER] Ensure Server has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"

	# [SERVER] Ensure Server is still running
	test_case_instance_is_running "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"


	# --------------------------------------------------------------------------------
	# STOP: SERVER
	# --------------------------------------------------------------------------------
	print_h2 "(10/10) Stop: Server"

	# [SERVER] Manually stop the Server
	action_stop_instance "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"

	# [SERVER] Ensure Server has no errors
	test_case_instance_has_no_errors "Server" "${srv_pid}" "${srv_stdout}" "${srv_stderr}" "Client" "${cli_pid}" "${cli_stdout}" "${cli_stderr}"
}


# -------------------------------------------------------------------------------------------------
# MAIN ENTRYPOINT
# -------------------------------------------------------------------------------------------------

for curr_round in $(seq "${RUNS}"); do
	#         server opts            client opts
	# BIND ON ANY
	run_test "-l ${RPORT} --no-shutdown    -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown    -u -vvvv"  "1" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RPORT} --no-shutdown    -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown -4 -u -vvvv --udp-sconnect --udp-sconnect-word"  "2" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RPORT} --no-shutdown    -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown -6 -u -vvvv"  "3" "14" "${curr_round}" "${RUNS}"

	run_test "-l ${RPORT} --no-shutdown -4 -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown    -u -vvvv --udp-sconnect --udp-sconnect-word"  "4" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RPORT} --no-shutdown -4 -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown -4 -u -vvvv"  "5" "14" "${curr_round}" "${RUNS}"

	run_test "-l ${RPORT} --no-shutdown -6 -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown    -u -vvvv"  "6" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RPORT} --no-shutdown -6 -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown -6 -u -vvvv"  "7" "14" "${curr_round}" "${RUNS}"

	# BIND ON SPECIFIC
	run_test "-l ${RHOST} ${RPORT} --no-shutdown    -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown    -u -vvvv"   "8" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RHOST} ${RPORT} --no-shutdown    -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown -4 -u -vvvv"   "9" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RHOST} ${RPORT} --no-shutdown    -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown -6 -u -vvvv"  "10" "14" "${curr_round}" "${RUNS}"

	run_test "-l ${RHOST} ${RPORT} --no-shutdown -4 -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown    -u -vvvv --udp-sconnect --udp-sconnect-word"  "11" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RHOST} ${RPORT} --no-shutdown -4 -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown -4 -u -vvvv"  "12" "14" "${curr_round}" "${RUNS}"

	run_test "-l ${RHOST} ${RPORT} --no-shutdown -6 -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown    -u -vvvv"  "13" "14" "${curr_round}" "${RUNS}"
	run_test "-l ${RHOST} ${RPORT} --no-shutdown -6 -e /bin/sh -u -vvvv" "${RHOST} ${RPORT} --no-shutdown -6 -u -vvvv"  "14" "14" "${curr_round}" "${RUNS}"
done
