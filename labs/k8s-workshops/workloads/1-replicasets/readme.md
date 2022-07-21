# ReplicaSets
ReplicaSets are the primary method of managing Pod replicas and their lifecycle. This includes their scheduling,
scaling, and deletion.

Their job is simple, **always** ensure the desired number of `replicas` that match the selector are running.

---

### Exercise: Understanding ReplicaSets
**Objective:** Create and scale a ReplicaSet. Explore and gain an understanding of how the Pods are generated from
the Pod template, and how they are targeted with selectors.

---

1) Begin by creating a ReplicaSet called `rs-example` with `3` `replicas`, using the `nginx:stable-alpine` image and
configure the labels and selectors to target `app=nginx` and `env=prod`. The yaml block below or the manifest
`manifests/rs-example.yaml` may be used.

**manifests/rs-example.yaml**
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: example-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
      env: prod
  template:
    metadata:
      labels:
        app: nginx
        env: prod
    spec:
      containers:
      - name: nginx
        image: nginx:stable-alpine
        ports:
        - containerPort: 80
```

**Command**
```
$ kubectl create -f manifests/rs-example.yaml
```

2) Watch as the newly created ReplicaSet provisions the Pods based off the Pod Template.
```
$ kubectl get pods --watch --show-labels
```
Note that the newly provisioned Pods are given a name based off the ReplicaSet name appended with a 5 character random
string. These Pods are labeled with the labels as specified in the manifest.

3) Scale ReplicaSet `rs-example` up to `5` replicas with the below command.
```
$ kubectl scale replicaset rs-example --replicas=5
```
**Tip:** `replicaset` can be substituted with `rs` when using `kubectl`.

4) Describe `rs-example` and take note of the `Replicas` and `Pod Status` field in addition to the `Events`.
```
$ kubectl describe rs rs-example
```

5) Now, using the `scale` command bring the replicas back down to `3`.
```
$ kubectl scale rs rs-example --replicas=3
```

6) Watch as the ReplicaSet Controller terminates 2 of the Pods to bring the cluster back into it's desired state of
3 replicas.
```
$ kubectl get pods --show-labels --watch
```

7) Once `rs-example` is back down to 3 Pods. Create an independent Pod manually with the same labels as the one
targeted by `rs-example` from the manifest `manifests/pod-rs-example.yaml`.

**manifests/pod-rs-example.yaml**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-example
  labels:
    app: nginx
    env: prod
spec:
  containers:
  - name: nginx
    image: nginx:stable-alpine
    ports:
    - containerPort: 80
```

**Command**
```
$ kubectl create -f manifests/pod-rs-example.yaml
```

8) Immediately watch the Pods.
```
$ kubectl get pods --show-labels --watch
```
Note that the Pod is created and immediately terminated.

9) Describe `rs-example` and look at the `events`.
```
$ kubectl describe rs rs-example
```
There will be an entry with `Deleted pod: pod-example`. This is because a ReplicaSet targets **ALL** Pods matching
the labels supplied in the selector.

---

**Summary:** ReplicaSets ensure a desired number of replicas matching the selector are present. They manage the
lifecycle of **ALL** matching Pods. If the desired number of replicas matching the selector currently exist when the
ReplicaSet is created, no new Pods will be created. If they are missing, then the ReplicaSet Controller will create
new Pods based off the Pod Template till the desired number of Replicas are present.

---

**Clean Up Command**
```
kubectl delete rs rs-example
```