# Jobs and CronJobs
The Job Controller ensures one or more Pods are executed and successfully terminate. Essentially a task executor
that can be run in parallel.

CronJobs are an extension of the Job Controller, and enable Jobs to be run on a schedule.

---

### Exercise: Creating a Job
**Objective:** Create a Kubernetes `Job` and work to understand how the Pods are managed with `completions` and
`parallelism` directives.

---

1) Create job `job-example` using the yaml below, or the manifest located at `manifests/job-example.yaml`

**manifests/job-example.yaml**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-example
spec:
  backoffLimit: 4
  completions: 4
  parallelism: 2
  template:
    spec:
      containers:
      - name: hello
        image: alpine:latest
        command: ["/bin/sh", "-c"]
        args: ["echo hello from $HOSTNAME!"]
      restartPolicy: Never
```

**Command**
```
$ kubectl create -f manifests/job-example.yaml
```

2) Watch the Pods as they are being created.
```
$ kubectl get pods --show-labels --watch
```
Only two Pods are being provisioned at a time; adhering to the `parallelism` attribute. This is done until the total
number of `completions` is satisfied. Additionally, the Pods are labeled with `controller-uid`, this acts as a
unique ID for that specific Job. 

When done, the Pods persist in a `Completed` state. They are not deleted after the Job is completed or failed. 
This is intentional to better support troubleshooting.

3) A summary of these events can be seen by describing the Job itself.
```
$ kubectl describe job job-example
```

4) Delete the job.
```
$ kubectl delete job job-example
```

5) View the Pods once more.
```
$ kubectl get pods
```
The Pods will now be deleted. They are cleaned up when the Job itself is removed.

---

**Summary:** Jobs are fire and forget one off tasks, batch processing or as an executor for a workflow engine.
They _"run to completion"_ or terminate gracefully adhering to the `completions` and `parallelism` directives.

---

### Exercise: Scheduling a CronJob
**Objective:** Create a CronJob based off a Job Template. Understand how the Jobs are generated and how to suspend
a job in the event of a problem.

---

1) Create CronJob `cronjob-example` based off the yaml below, or use the manifest `manifests/cronjob-example.yaml`
It is configured to run the Job from the earlier example every minute, using the cron schedule `"*/1 * * * *"`.
This schedule is **UTC ONLY**.

**manifests/cronjob-example.yaml**
```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: cronjob-example
spec:
  schedule: "*/1 * * * *"
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      completions: 4
      parallelism: 2
      template:
        spec:
          containers:
          - name: hello
            image: alpine:latest
            command: ["/bin/sh", "-c"]
            args: ["echo hello from $HOSTNAME!"]
          restartPolicy: Never
```

**Command**
```
$ kubectl create -f manifests/cronjob-example.yaml
```

2) Give it some time to run, and then list the Jobs.
```
$ kubectl get jobs
```
There should be at least one Job named in the format `<cronjob-name>-<unix time stamp>`. Note the timestamp of
the oldest Job.

3) Give it a few minutes and list the Jobs once again
```
$ kubectl get jobs
```
The oldest Job should have been removed. The CronJob controller will purge Jobs according to the
`successfulJobHistoryLimit` and `failedJobHistoryLimit` attributes. In this case, it is retaining strictly the
last 3 successful Jobs.

4) Describe the CronJob `cronjob-example` 
```
$ kubectl describe CronJob cronjob-example
```
The events will show the records of the creation and deletion of the Jobs.

5) Edit the CronJob `cronjob-example` and locate the `Suspend` field. Then set it to true.
```
$ kubectl edit CronJob cronjob-example
```
This will prevent the cronjob from firing off any future events, and is useful to do to initially troubleshoot
an issue without having to delete the CronJob directly.


5) Delete the CronJob
```
$ kubectl delete cronjob cronjob-example
```
Deleting the CronJob **WILL** delete all child Jobs. Use `Suspend` to _'stop'_ the Job temporarily if attempting
to troubleshoot.

---

**Summary:** CronJobs are a useful extension of Jobs. They are great for backup or other day-to-day tasks, with the
only caveat being they adhere to a **UTC ONLY** schedule.

---

**Clean Up Commands**
```
kubectl delete CronJob cronjob-example
```