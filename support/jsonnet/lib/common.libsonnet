local utils = import "lib/utils.libsonnet";

{
    _local:: {
        # imports go here, modify if version gets bumped
        kube: import "vendor/github.com/jsonnet-libs/k8s-libsonnet/1.23/main.libsonnet",
        flux: import "vendor/github.com/jsonnet-libs/fluxcd-libsonnet/0.28.5/main.libsonnet",
        certs: import "vendor/github.com/jsonnet-libs/cert-manager-libsonnet/1.7/main.libsonnet",
        prom: import "vendor/github.com/jsonnet-libs/kube-prometheus-libsonnet/0.10/main.libsonnet",
        kapitan: import "lib/kapitan.libsonnet",
    },

    kube: $._local.kube + {
        networking+: {
            v1+: {
                networkPolicyIngressRule+: {
                    withFromCidrs(cidrs):: super.withFrom([
                        $.kk.networkPolicyPeer.ipBlock.withCidr(cidr)
                        for cidr in cidrs
                    ])
                }
            }
        }
    },

    flux: $._local.flux,
    certs: $._local.certs,
    prom: $._local.prom,
    kapitan: $._local.kapitan,

    kk: {
        # common aliases for k8s resources
        configMap: $.kube.core.v1.configMap,
        container: $.kube.core.v1.container,
        containerPort: $.kube.core.v1.containerPort,
        deployment: $.kube.apps.v1.deployment,
        ingress: $.kube.networking.v1.ingress,
        localObjectReference: $.kube.core.v1.localObjectReference,
        networkPolicy: $.kube.networking.v1.networkPolicy,
        networkPolicyIngressRule: $.kube.networking.v1.networkPolicyIngressRule,
        networkPolicyPeer: $.kube.networking.v1.networkPolicyPeer,
        networkPolicyPort: $.kube.networking.v1.networkPolicyPort,
        persistentVolumeClaim: $.kube.core.v1.persistentVolumeClaim,
        resourceRequirements: $.kube.core.v1.resourceRequirements,
        secret: $.kube.core.v1.secret,
        service: $.kube.core.v1.service,
        serviceAccount: $.kube.core.v1.serviceAccount,
        servicePort: $.kube.core.v1.servicePort,
        storageClass: $.kube.storage.v1.storageClass,
        volume: $.kube.core.v1.volume,
        volumeMount: $.kube.core.v1.volumeMount,

        # cert-manager stuff
        certificate: $.certs.nogroup.v1.certificate,
        certificateRequest: $.certs.nogroup.v1.certificateRequest,
        clusterIssuer: $.certs.nogroup.v1.clusterIssuer,
        issuer: $.certs.nogroup.v1.issuer,

        # prometheus stuff
        podMonitor: $.prom.monitoring.v1.podMonitor,
        serviceMonitor: $.prom.monitoring.v1.serviceMonitor,

        # replaces the namespace of a resource
        replaceNamespace(data, namespace):: data {
            metadata+: { namespace: namespace }
        },

        # replaces the namespaces on a dict of resources
        replaceNamespaces(data, namespace):: std.mapWithKey(
            function(k, v) if std.isArray(v) then
                std.map(function(vv) self.replaceNamespace(vv, namespace), v)
            else self.replaceNamespace(v, namespace), data
        ),
    }
}
+ utils
