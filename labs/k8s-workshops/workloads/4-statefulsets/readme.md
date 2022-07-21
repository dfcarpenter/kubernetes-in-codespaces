# StatefulSets
The StatefulSet controller is tailored to managing Pods that must persist or maintain state. Pod identity including
hostname, network, and storage can be considered **persistent**.

They ensure persistence by making use of three things:
* The StatefulSet controller enforcing predicable naming, and ordered provisioning/updating/deletion.
* A headless service to provide a unique network identity.
* A volume template to ensure stable per-instance storage.
---

### Exercise: Managing StatefulSets
**Objective:** Create, update, and delete a `StatefulSet` to gain an understanding of how the StatefulSet lifecycle
differs from other workloads with regards to updating, deleting and the provisioning of storage.

---

1) Create StatefulSet `sts-example` using the yaml block below or the manifest `manifests/sts-example.yaml`.

**manifests/sts-example.yaml**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: sts-example
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: stateful
  serviceName: app
  updateStrategy:
    type: OnDelete
  template:
    metadata:
      labels:
        app: stateful
    spec:
      containers:
      - name: nginx
        image: nginx:stable-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: standard
      resources:
        requests:
          storage: 1Gi
```

**Command**
```
$ kubectl create -f manifests/sts-example.yaml
```

2) Immediately watch the Pods being created.
```
$ kubectl get pods --show-labels --watch
```
Unlike Deployments or DaemonSets, the Pods of a StatefulSet are created one-by-one, going by their ordinal index.
Meaning, `sts-example-0` will fully be provisioned before `sts-example-1` starts up. Additionally, take notice of
the `controller-revision-hash` label. This serves the same purpose as the `controller-revision-hash` label in a
DaemonSet or the `pod-template-hash` in a Deployment. It provides a means of tracking the revision of the Pod
Template and enables rollback functionality.

3) More information on the StatefulSet can be gleaned about the state of the StatefulSet by describing it.
```
$ kubectl describe statefulset sts-example
```
Within the events, notice that it is creating claims for volumes before each Pod is created.

4) View the current Persistent Volume Claims.
```
$ kubectl get pvc
```
The StatefulSet controller creates a volume for each instance based off the `volumeClaimTemplate`. It prepends
the volume name to the Pod name. e.g. `www-sts-example-0`.

5) Update the StatefulSet's Pod Template and add a few additional labels.
```
$ kubectl apply -f manifests/sts-example.yaml --record
  < or >
$ kubectl edit statefulset sts-example --record
```

6) Return to watching the Pods.
```
$ kubectl get pods --show-labels
```
None of the Pods are being updated to the new version of the Pod.

7) Delete the `sts-example-2` Pod.
```
$ kubectl delete pod sts-example-2
```

8) Immediately get the Pods.
```
$ kubectl get pods --show-labels --watch
```
The new `sts-example-2` Pod should be created with the new additional labels. The `OnDelete` Update Strategy will
not spawn a new iteration of the Pod until the previous one was **deleted**. This allows for manual gating the
update process for the StatefulSet.

9) Update the StatefulSet and change the Update Strategy Type to `RollingUpdate`.
```
$ kubectl apply -f manifests/sts-example.yaml --record
  < or >
$ kubectl edit statefulset sts-example --record
```

10) Immediately watch the Pods once again.
```
$ kubectl get pods --show-labels --watch
```
Note that the Pods are sequentially updated in descending order, or largest to smallest based on the
Pod's ordinal index. This means that if `sts-example-2` was not updated already, it would be updated first, then
`sts-example-1` and finally `sts-example-0`.

11) Delete the StatefulSet `sts-example`
```
$ kubectl delete statefulset sts-example
```

12) View the Persistent Volume Claims.
```
$ kubectl get pvc
```
Created PVCs are **NOT** garbage collected automatically when a StatefulSet is deleted. They must be reclaimed
independently of the StatefulSet itself.

13) Recreate the StatefulSet using the same manifest.
```
$ kubectl create -f manifests/sts-example.yaml --record
```

14) View the Persistent Volume Claims again.
```
$ kubectl get pvc
```
Note that new PVCs were **NOT** provisioned. The StatefulSet controller assumes if the matching name is present,
that PVC is intended to be used for the associated Pod.

---

**Summary:** Like many applications where state must be taken into account, the planning and usage of StatefulSets
requires forethought. The consistency brought by standard naming, ordered updates/deletes and templated storage
does however make this task easier.

---

### Exercise: Understanding StatefulSet Network Identity

**Objective:** Create a _"headless service"_ or a service without a `ClusterIP` (`ClusterIP=None`) for use with the
StatefulSet `sts-example`, then explore how this enables consistent service discovery.

---

1) Create the headless service `app` using the `app=stateful` selector from the yaml below or the manifest
`manifests/service-sts-example.yaml`.

**manifests/service-sts-example.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  clusterIP: None
  selector:
    app: stateful
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

**Command**
```
$ kubectl create -f manifests/service-sts-example.yaml
```

2) Describe the newly created service
```
$ kubectl describe svc app
```
Notice that it does not have a `clusterIP`, but does have the Pod Endpoints listed. Headless services are unique
in this behavior.

3) Query the DNS entry for the `app` service.
```
$ kubectl exec sts-example-0 -- nslookup app.default.svc.cluster.local
```
An A record will have been returned for each instance of the StatefulSet. Querying the service directly will do
simple DNS round-robin load-balancing.

4) Finally, query one of instances directly.
```
$ kubectl exec sts-example-0 -- nslookup sts-example-1.app.default.svc.cluster.local
```
This is a unique feature to StatefulSets. This allows for services to directly interact with a specific instance
of a Pod. If the Pod is updated and obtains a new IP, the DNS record will immediately point to it enabling consistent
service discovery.

---

**Summary:** StatefulSet service discovery is unique within Kubernetes in that it augments a headless service
(A service without a unique `ClusterIP`) to provide a consistent mapping to the individual Pods. These mappings
take the form of an A record in format of: `<StatefulSet Name>-<ordinal>.<service name>.<namespace>.svc.cluster.local`
and can be used consistently throughout other Workloads.

---

**Clean Up Command**
```
kubectl delete svc app
kubectl delete statefulset sts-example
kubectl delete pvc www-sts-example-0 www-sts-example-1 www-sts-example-2
```