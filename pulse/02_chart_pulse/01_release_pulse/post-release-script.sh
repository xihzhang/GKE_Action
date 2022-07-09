###############################################################################
#           Helper functions
###############################################################################
function wait_status {
  #############################################
  # Using: wait_status pod status time_limit
  #############################################
    pod=$1; pod_status=$2; time_limit=$3
    n=$(expr $time_limit / 5)
    echo "Validate pods <$pod> have status <$pod_status>"
    for i in $(seq 1 $n); do
      echo "${i}) waiting for pods to get status $pod_status ..." && sleep 5
      kubectl get pods -l servicename=$pod --no-headers 
      PSTAT=$(kubectl get pods -l servicename=$pod --no-headers | awk '{print $3}' | sort | uniq)
      if [[ "$PSTAT" == "$pod_status" ]]; then
        if [[ "$PSTAT" == "Running" ]]; then
          echo "Checking all of containers is running..."
          s=$(kubectl get pods -l servicename=$pod --no-headers | awk '{print $2}' | sort | uniq)
          echo "Containers STATUS: $s"
          c_run=$(echo $s | sed 's/\/.*//')
          c_plan=$(echo $s | sed 's/.*\///')
          [[ "$c_run" == "$c_plan" ]] && break
        else
          break
        fi
      fi
      [[ $i == $n ]] && echo "ERROR: can't get pods in status: $pod_status" && exit 1
    done
    echo "<$pod> in <$pod_status> status!"
}
###############################################################################
function check_pulse_health {
  #############################################
  # Using: check_pulse_health time_limit
  #############################################
    time_limit=$1
    n=$(expr $time_limit / 5)
    echo "Validating Pulse health status "
    kubectl -n $NS port-forward svc/pulse 8090:8090 >>/dev/null 2>&1 &
    for i in $(seq 1 $n); do
      echo "$i waiting Pulse health status ..." && sleep 5
      res=$(curl -s -X GET http://127.0.0.1:8090/actuator/metrics/pulse.health.all | \
        jq '.measurements[] | select(.statistic|test("VALUE")) | .value')
      echo "Pulse health status: res=$res"
      [[ "$res" == "1" ]] || [[ "$res" == "1.0" ]]  && break
      [[ $i == $n ]] && echo "ERROR: pulse is unhealthy" && kill %1 && exit 1
    done
    kill %1
    echo "Pulse is healthy!"
}
###############################################################################


wait_status pulse Running 300

check_pulse_health 120