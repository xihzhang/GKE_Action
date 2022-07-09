###############################################################################
# All secrets sould be saved in secrets: deployment-secrets
#                 Using it! 
# We extract secrets to environment variables. It will evaluate variables in
# override values by workflow.
###############################################################################
function get_secret {
  # Using: get_secret secret_name
  echo $( kubectl get secrets deployment-secrets -o custom-columns=:data.$1 \
      --no-headers | base64 -d )
}

function replace_overrides {
  # Using: replace_overrides old_value new_value
  ESCAPED_S=$(printf '%s' "$2" | sed -e 's/[\/&]/\\&/g')
  cat override_values.yaml | sed "s/$1/$ESCAPED_S/g" > override_values.tmp \
     && mv override_values.tmp override_values.yaml 
}

###############################################################################
#             Exporting variable from deployment secret
###############################################################################
#-------POSTGRES
export POSTGRES_ADDR=$( get_secret POSTGRES_ADDR )
export POSTGRES_PORT=$( get_secret POSTGRES_PORT )
export POSTGRES_USER=$( get_secret POSTGRES_USER )
export POSTGRES_PASSWORD=$( get_secret POSTGRES_PASSWORD )
#-------REDIS
export redis_host=$( get_secret redis_host )
export redis_port=$( get_secret redis_port )
export redis_key=$( get_secret redis_key )
#-------GWS credentials
export gws_ClientId=$( get_secret gws_ClientId )
export gws_Client_Secret=$( get_secret gws_Client_Secret )
#-------Tenant 
export tenant_id=$( get_secret tenant_id )
export tenant_sid=$( get_secret tenant_sid )
###############################################################################


###############################################################################
# Creating gauth pulse if not exist
###############################################################################
envsubst < create_pulse_db.sh > create_pulse_db.sh_
kubectl run busybox -i --rm --image=alpine --restart=Never -- sh -c "$(<create_pulse_db.sh_)"


###############################################################################
#           Redis
# pulse doesn`t support clustered redis. So if there is not unclustered version
# of Redis in your infrastructure you can use Redis intalled by code below.
# In other case you should define your redis parameters in deployment-secrets 
# and comment the code installing redis below (all if section) and define 
###############################################################################

if [ ! "$(helm list -n $NS | grep pulse-redis)" ]; then
  HELMPACK="redis"
  REPO_NAME="bitnami"
  BITNAMI_URL="$REPO_NAME https://charts.bitnami.com/bitnami"
  ARGS="--set master.podSecurityContext.fsGroup=null  \
      --set master.containerSecurityContext.runAsUser=null \
      --set replica.podSecurityContext.fsGroup=null \
      --set replica.containerSecurityContext.runAsUser=null"
  HELMCHART="$REPO_NAME/$HELMPACK -n $NS --set auth.password=$redis_key \
    --set master.resources.limits.cpu="500m" --set master.resources.limits.memory="512Mi" \
    --set master.resources.requests.cpu="200m" --set master.resources.requests.memory="256Mi" \
    --set replica.resources.limits.cpu="500m" --set replica.resources.limits.memory="512Mi" \
    --set replica.resources.requests.cpu="200m" --set replica.resources.requests.memory="256Mi"\
    $ARGS"

  echo "Install Redis"
  helm repo add $BITNAMI_URL
  helm install pulse-redis $HELMCHART  --wait --timeout 300s
  [[ ! $redis_host ]] && export redis_host="pulse-redis-master.${NS}.svc.cluster.local"
  [[ ! $redis_port ]] && export redis_port="6379"
  echo "$(kubectl get pods | grep pulse-redis)"
fi
###############################################################################
