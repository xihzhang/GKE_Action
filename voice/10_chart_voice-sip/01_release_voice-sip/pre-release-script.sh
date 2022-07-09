
###############################################################################
# 					Update DNS ip address
#
# https://all.docs.genesys.com/VM/Current/VMPEGuide/Deploy#Deploy_the_Voice_Services
###############################################################################
DNS_SERVER=$(kubectl get -n kube-system svc kube-dns -o \
			custom-columns=:spec.clusterIP --no-headers)

cat override_values.yaml | \
	sed "s/127\.0\.0\.1/${DNS_SERVER}/g" > override_values.tmp \
	&& mv override_values.tmp override_values.yaml
###############################################################################