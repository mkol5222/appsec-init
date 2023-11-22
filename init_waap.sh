#!/bin/bash

print_help() {
    echo "usage: init_waap.sh [-h|--help|--dns-name|--dns-primary|--dns-secondary]"
    echo "Options and arguments: "
    echo "  -h|--help: print this help"
    echo "  --dns-name: set dns search name"
    echo "  --dns-primary: set primary dns server"
    echo "  --dns-secondary: set secondary dns server"
}

print_unknown_option() {
    echo "Unknown option: $1"
    echo "usage: init_waap.sh [-h|--help|--dns-name|--dns-primary|--dns-secondary]"
    echo "Try 'init_waap.sh -h' for more information"
    exit 1
}

parse_args() {
    POSITIONAL=()
    while [[ $# -gt 0 ]]; do
        arg="$1"
        case ${arg} in
        -h)
            print_help
            exit 0
            ;;
        --help)
            print_help
            exit 0
            ;;
        "start")
            shift
            ;;
        "stop")
            shift
            ;;
        *)
            print_unknown_option "$1"
            ;;
        esac
    done
    set -- "${POSITIONAL[@]}"
}

error() {
    echo "$@" 1>&2
}

fail() {
    error "$@"
    exit 1
}

create_log_file() {
    : >"$log_file"
    echo "$(date) : Starting init_waap.sh"
}

configure_gaia() {
    chkconfig --del cpri_d
    start_cp_watchdog

    # unload FW policy if exiting
    fw unloadlocal &> /dev/null

    # Disable FW on the machine if running
    is_firewall=$(cpprod_util FwIsFirewallModule)
    if [[ "$is_firewall" != "0" ]]; then
        chkconfig --del cpboot
        chkconfig --del fw1boot
    fi
    gaia_api stop
}

start_cp_watchdog()
{
    . /opt/CPshrd-R80.40/tmp/.CPprofile.sh
    echo "Starting cpWatchdog"
    local count=0
    local is_cpwd_up=false

    while [[ $count -le 10 ]]; do
        if "$CPDIR"/bin/cpwd >& /dev/null; then
            is_cpwd_up=true
            break
        fi
        ((count += 1))
        sleep 1
    done

    if ! "$is_cpwd_up"; then
        fail "Failed to start CPWD. Aborting"
    fi

    # Enable Deployment Agent
    da_status=$(cpwd_admin list | grep DASERVICE)
    if [[ -z "$da_status" ]]; then
        dbget installer:start
    fi
}

run_on_reboot() {
    # Run this script every startup
    local base=zzzz_init_waap

    if [[ ! -f /etc/rc3.d/S99$base ]]; then
        cp /opt/CPWAAP/init_waap.sh /etc/init.d/$base
        ln -s /etc/init.d/$base /etc/rc3.d/S99$base
    fi
}

release_port_443() {
    # Release port 443
    dbset httpd:ssl_port 30443
    dbset webuiparams:displaymode basic
    dbset :save
}

disable_first_time_wizard() {
    # Disable first time wizard
    touch /etc/.wizard_accepted
}

setting_docker() {
    # Setting docker
    ln -sfn /usr/libexec/docker/docker-proxy-current /usr/bin/docker-proxy
    sed -i /etc/init.d/docker -e 's/IS_MGMT=.*/IS_MGMT=1/'
    chkconfig --add docker
    service docker start || true
}

validate_docker_alive() {
    # Check that docker service is up
    count=0
    docker_not_running=true
    while [[ ${count} -le 10 ]]; do
        if docker ps &>/dev/null; then
            docker_not_running=false
            break
        fi
        echo "Docker is not yet running. Trying again. Number of counts: $count"
        sleep 1
        ((count += 1))
    done

    if ${docker_not_running}; then
        fail "Failed to start docker. exiting"
    fi
}

redesign_web_ui() {
    # redesign the web ui.
    /opt/CPWAAP/adjust_web_ui.sh || true
}

unconifugre_CPwaap()
{
    cpprod_util CPPROD_SetValue CPwaap IsConfigured 1 0 0 >/dev/null 2>&1
}

configure_CPwaap() {
  # create file instead of this
  cpprod_util CPPROD_SetValue CPwaap IsConfigured 1 1 0 >/dev/null 2>&1
}

print_info() {
  echo "$@"
}

main() {
    parse_args "$@"
    create_log_file
    print_info "Set CPwaap as unconifugre"
    unconifugre_CPwaap
    print_info "Disable firewall"
    configure_gaia
    print_info "Set run on reboot"
    run_on_reboot
    print_info "Release port 443"
    release_port_443
    print_info "Disable first time wizard"
    disable_first_time_wizard
    print_info "Enable docker"
    setting_docker
    print_info "Validate docker is alive"
    validate_docker_alive
    print_info "Redesign web UI"
    redesign_web_ui
    print_info "Set CPwaap as configured"
    configure_CPwaap

    # give executable permissions to agent installation files
    chmod a+x /opt/CPWAAP/agent/cp-nano-egg
}

log_file=/opt/CPWAAP/init_waap.log
main "$@" 2>&1 1>"$log_file" | tee -a "$log_file"
