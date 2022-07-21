# Deployments
Deployments are a declarative method of managing Pods via ReplicaSets. They provide rollback functionality in addition
to more granular update control mechanisms.

---

### Exercise: Using Deployments
**Objective:** Create, update and scale a Deployment as well as explore the relationship of Deployment, ReplicaSet
and Pod.

---

1) Create a Deployment `deploy-example`. Configure it using the example yaml block below or use the manifest 
`manifests/deploy-example.yaml`. Additionally pass the `--record` flag to `kubectl` when you create the Deployment. 
The `--record` flag saves the command as an annotation, and it can be thought of similar to a git commit message.

**manifests/deployment-example.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-example
spec:
  replicas: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:stable-alpine
        ports:
        - containerPort: 80
```

**Command**
```
$ kubectl create -f manifests/deploy-example.yaml --record
```

2) Check the status of the Deployment.
```
$ kubectl get deployments
```

3) Once the Deployment is ready, view the current ReplicaSets and be sure to show the labels.
```
$ kubectl get rs --show-labels
```
Note the name and `pod-template-hash` label of the newly created ReplicaSet. The created ReplicaSet's name will
include the `pod-template-hash`.

4) Describe the generated ReplicaSet.
```
$ kubectl describe rs deploy-example-<pod-template-hash>
```
Look at both the `Labels` and the `Selectors` fields. The `pod-template-hash` value has automatically been added to
both the Labels and Selector of the ReplicaSet. Then take note of the `Controlled By` field. This will reference the
direct parent object, and in this case the original `deploy-example` Deployment.

5) Now, get the Pods and pass the `--show-labels` flag.
```
$ kubectl get pods --show-labels
```
Just as with the ReplicaSet, the Pods name are labels include the `pod-template-hash`.

6) Describe one of the Pods.
```
$ kubectl describe pod deploy-example-<pod-template-hash-<random>
```
Look at the `Controlled By` field. It will contain a reference to the parent ReplicaSet, but not the parent Deployment.

Now that the relationship from Deployment to ReplicaSet to Pod is understood. It is time to update the
`deploy-example` and see an update in action.

7) Update the `deploy-example` manifest and add a few additional labels to the Pod template. Once done, apply the
change with the `--record` flag.
```
$ kubectl apply -f manifests/deploy-example.yaml --record
  < or >
$ kubectl edit deploy deploy-example --record
```
**Tip:** `deploy` can be substituted for `deployment` when using `kubectl`.

8) Immediately watch the Pods.
```
$ kubectl get pods --show-labels --watch
```
The old version of the Pods will be phased out one at a time and instances of the new version will take its place.
The way in which this is controlled is through the `strategy` stanza. For specific documentation this feature, see
the [Deployment Strategy Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy).

9) Now view the ReplicaSets.
```
$ kubectl get rs --show-labels
```
There will now be two ReplicaSets, with the previous version of the Deployment being scaled down to 0.

10) Now, scale the Deployment up as you would a ReplicaSet, and set the `replicas=5`.
```
$ kubectl scale deploy deploy-example --replicas=5
```

11) List the ReplicaSets.
```
$ kubectl get rs --show-labels
```
Note that there is **NO** new ReplicaSet generated. Scaling actions do **NOT** trigger a change in the Pod Template.

12) Just as before, describe the Deployment, ReplicaSet and one of the Pods. Note the `Events` and `Controlled By`
fields. It should present a clear picture of relationship between objects during an update of a Deployment.
```
$ kubectl describe deploy deploy-example
$ kubectl describe rs deploy-example-<pod-template-hash>
$ kubectl describe pod deploy-example-<pod-template-hash-<random>
```

---

**Summary:** Deployments are the main method of managing applications deployed within Kubernetes. They create and
supervise targeted ReplicaSets by generating a unique hash called the `pod-template-hash` and attaching it to child
objects as a Label along with automatically including it in their Selector. This method of managing rollouts along with
being able to define the methods and tolerances in the update strategy permits for a safe and seamless way of updating
an application in place.

---

### Exercise: Rolling Back a Deployment
**Objective:** Learn how to view the history of a Deployment and rollback to older revisions.

**Note:** This exercise builds off the previous exercise: [Using Deployments](#exercise-using-deployments). If you
have not, complete it first before continuing.

---

1) Use the `rollout` command to view the `history` of the Deployment `deploy-example`.
```
$ kubectl rollout history deployment deploy-example
```
There should be two revisions. One for when the Deployment was first created, and another when the additional Labels
were added. The number of revisions saved is based off of the `revisionHistoryLimit` attribute in the Deployment spec.

2) Look at the details of a specific revision by passing the `--revision=<revision number>` flag.
```
$ kubectl rollout history deployment deploy-example --revision=1
$ kubectl rollout history deployment deploy-example --revision=2
```
Viewing the specific revision will display a summary of the Pod Template.

3) Choose to go back to revision `1` by using the `rollout undo` command.
```
$ kubectl rollout undo deployment deploy-example --to-revision=1
```
**Tip:** The `--to-revision` flag can be omitted if you wish to just go back to the previous configuration.

4) Immediately watch the Pods.
```
$ kubectl get pods --show-labels --watch
```
They will cycle through rolling back to the previous revision.

5) Describe the Deployment `deploy-example`.
```
$ kubectl describe deployment deploy-example
```
The events will describe the scaling back of the previous and switching over to the desired revision.

---

**Summary:** Understanding how to use `rollout` command to both get a diff of the different revisions as well as
be able to roll-back to a previously known good configuration is an important aspect of Deployments that cannot
be left out.

---

**Clean Up Command**
```
kubectl delete deploy deploy-example
```
