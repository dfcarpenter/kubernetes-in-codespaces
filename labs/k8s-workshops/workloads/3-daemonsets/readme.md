# DaemonSets

DaemonSets ensure that all nodes matching certain criteria will run an instance of the supplied Pod.

They bypass default scheduling mechanisms and restrictions, and are ideal for cluster wide services such as
log forwarding, or health monitoring.

---

### Exercise: Managing DaemonSets
**Objective:** Experience creating, updating, and rolling back a DaemonSet. Additionally delve into the process of
how they are scheduled and how an update occurs.

---

1) Create DaemonSet `ds-example` and pass the `--record` flag. Use the example yaml block below as a base, or use
the manifest `manifests/ds-example.yaml` directly.

**manifests/ds-example.yaml**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ds-example
spec:
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        nodeType: edge
      containers:
      - name: nginx
        image: nginx:stable-alpine
        ports:
        - containerPort: 80
```

**Command**
```
$ kubectl create -f manifests/ds-example.yaml --record
```

2) View the current DaemonSets.
```
$ kubectl get daemonset
```
As there are no matching nodes, no Pods should be scheduled.

3) Label the `minikube` node with `nodeType=edge`
```
$ kubectl label node minikube nodeType=edge
```

4) View the current DaemonSets once again.
```
$ kubectl get daemonsets
```
There should now be a single instance of the DaemonSet `ds-example` deployed.

5) View the current Pods and display their labels with `--show-labels`.
```
$ kubectl get pods --show-labels
```
Note that the deployed Pod has a `controller-revision-hash` label. This is used like the `pod-template-hash` in a
Deployment to track and allow for rollback functionality.

6) Describing the DaemonSet will provide you with status information regarding it's Deployment cluster wide.
```
$ kubectl describe ds ds-example
```
**Tip:** `ds` can be substituted for `daemonset` when using `kubectl`.

7) Update the DaemonSet by adding a few additional labels to the Pod Template and use the `--record` flag.
```
$ kubectl apply -f manifests/ds-example.yaml --record
  < or >
$ kubectl edit ds ds-example --record
```

8) Watch the Pods and be sure to show the labels.
```
$ kubectl get pods --show-labels --watch
```
The old version of the DaemonSet will be phased out one at a time and instances of the new version will take its
place. Similar to Deployments, DaemonSets have their own equivalent to a Deployment's `strategy` in the form of
`updateStrategy`. The defaults are generally suitable, but other tuning options may be set. For reference, see the
[Updating DaemonSet Documentation](https://kubernetes.io/docs/tasks/manage-daemon/update-daemon-set/#performing-a-rolling-update).

---

**Summary:** DaemonSets are usually used for important cluster-wide support services such as Pod Networking, Logging,
or Monitoring. They differ from other workloads in that their scheduling bypasses normal mechanisms, and is centered
around node placement. Like Deployments, they have their own `pod-template-hash` in the form of
`controller-revision-hash` used for keeping track of Pod Template revisions and enabling rollback functionality.

---

### Optional: Working with DaemonSet Revisions

**Objective:** Explore using the `rollout` command to rollback to a specific version of a DaemonSet.

**Note:** This exercise is functionally identical to the Exercise[Rolling Back a Deployment](#exercise-rolling-back-deployment).
If you have completed that exercise, then this may be considered optional. Additionally, this exercise builds off
the previous exercise [Managing DaemonSets](#exercise-managing-daemonsets) and it must be completed before continuing.

---

1) Use the `rollout` command to view the `history` of the DaemonSet `ds-example`
```
$ kubectl rollout history ds ds-example
```
There should be two revisions. One for when the Deployment was first created, and another when the additional Labels
were added. The number of revisions saved is based off of the `revisionHistoryLimit` attribute in the DaemonSet spec.

2) Look at the details of a specific revision by passing the `--revision=<revision number>` flag.
```
$ kubectl rollout history ds ds-example --revision=1
$ kubectl rollout history ds ds-example --revision=2
```
Viewing the specific revision will display the Pod Template.

3) Choose to go back to revision `1` by using the `rollout undo` command.
```
$ kubectl rollout undo ds ds-example --to-revision=1
```
**Tip:** The `--to-revision` flag can be omitted if you wish to just go back to the previous configuration.

4) Immediately watch the Pods.
```
$ kubectl get pods --show-labels --watch
```
They will cycle through rolling back to the previous revision.

5) Describe the DaemonSet `ds-example`.
```
$ kubectl describe ds ds-example
```
The events will be sparse with a single host, however in an actual Deployment they will describe the status of
updating the DaemonSet cluster wide, cycling through hosts one-by-one.

---

**Summary:** Being able to use the `rollout` command with DaemonSets is import in scenarios where one may have
to quickly go back to a previously known-good version. This becomes even more important for 'infrastructure' like
services such as Pod Networking.

---

**Clean Up Command**
```
kubectl delete ds ds-example
```