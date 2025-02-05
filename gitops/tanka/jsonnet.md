# Using Jsonnet

The most powerful piece of Tanka is the [Jsonnet data templating
language](https://jsonnet.org). Jsonnet is a superset of JSON, adding variables,
functions, patching (deep merging), arithmetic, conditionals and many more to
it.

It has a lot in common with more _real_ programming languages such as JavaScript
than with markup languages, still it is tailored specifically to representing
data and configuration. As opposed to JSON (and YAML) it is a language meant for
humans, not for computers.

## Creating a new project

To get started with Tanka and Jsonnet, let's initiate a new project, in which we will install both Prometheus and Grafana into our Kubernetes cluster:

```bash
$ mkdir prom-grafana && cd prom-grafana # create a new folder for the project and change to it
$ tk init # initiate a new project
```

This gives us the following directory structure:

```sh
├── environments
│   └── default # default environment
│       ├── main.jsonnet # main file (important!)
│       └── spec.json # environment's config
├── jsonnetfile.json
├── lib # libraries
└── vendor # external libraries
```

For the moment, we only really care about the `environments/default` folder. The
purpose of the other directories will be explained later in this guide (mostly
related to libraries).

## Environments

When using Tanka, you apply **configuration** for an **Environment** to a
Kubernetes **cluster**. An Environment is some logical group of pieces that form
an application stack.

[Grafana Labs](https://grafana.com) for example runs [Loki](https://grafana.com/oss/loki/),
[Cortex](https://cortexmetrics.io) and of course
[Grafana](https://grafana.com/grafana/) for our [Grafana
Cloud](https://grafana.com/products/cloud/) hosted offering. For each of these, we have a
separate environment. Furthermore, we like to see changes to our code in
separate `dev` setups to make sure they are all good for production usage – so
we have `dev` and `prod` environments for each app as well, as `prod`
environments usually require other configuration (secrets, scale, etc) than
`dev`. This roughly leaves us with the following:

|        | Loki                                                          | Cortex                                                            | Grafana                                                             |
| ------ | ------------------------------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------- |
| `prod` | Name: `/environments/loki/prod` <br /> Namespace: `loki-prod` | Name: `/environments/cortex/prod` <br /> Namespace: `cortex-prod` | Name: `/environments/grafana/prod` <br /> Namespace: `grafana-prod` |
| `dev`  | Name: `/environments/loki/dev` <br /> Namespace: `loki-dev`   | Name: `/environments/cortex/dev` <br /> Namespace: `cortex-dev`   | Name: `/environments/grafana/dev` <br /> Namespace: `grafana-dev`   |

There is no limit in Environment complexity, create as many as you need to model
your own requirements. Grafana Labs for example also has all of these multiplied per
high-availability region.

To get started, a single environment is enough. Lets use the automatically
created `environnments/default` for that.

## Defining Resources

While `kubectl` loads all `.yaml` files in a certain folder, Tanka has a single
file that serves as the canonical source for all contents of an environment,
called `main.jsonnet`. This is just like Go has the `main.go` or C++ the
`main.cpp`.

Similar to JSON, each `.jsonnet` file holds a single object. The one returned by
`main.jsonnet` will hold all of your Kubernetes resources:

```jsonnet
// main.jsonnet
{
    "some_deployment": { /* ... */ },
    "some_service": { /* ... */ }
}
```

They may be deeply nested, Tanka extracts everything that looks like a
Kubernetes resource automatically.

So let's rewrite the [previous `.yaml`](/tutorial/refresher#writing-the-yaml) to
very basic `.jsonnet`:

##### environments/default/main.jsonnet:

```jsonnet
{
  // Grafana
  grafana: {
    deployment: {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'grafana',
      },
      spec: {
        selector: {
          matchLabels: {
            name: 'grafana',
          },
        },
        template: {
          metadata: {
            labels: {
              name: 'grafana',
            },
          },
          spec: {
            containers: [
              {
                image: 'grafana/grafana',
                name: 'grafana',
                ports: [{
                    containerPort: 3000,
                    name: 'ui',
                }],
              },
            ],
          },
        },
      },
    },
    service: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        labels: {
          name: 'grafana',
        },
        name: 'grafana',
      },
      spec: {
        ports: [{
            name: 'grafana-ui',
            port: 3000,
            targetPort: 3000,
        }],
        selector: {
          name: 'grafana',
        },
        type: 'NodePort',
      },
    },
  },

  // Prometheus
  prometheus: {
    deployment: {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'prometheus',
      },
      spec: {
        minReadySeconds: 10,
        replicas: 1,
        revisionHistoryLimit: 10,
        selector: {
          matchLabels: {
            name: 'prometheus',
          },
        },
        template: {
          metadata: {
            labels: {
              name: 'prometheus',
            },
          },
          spec: {
            containers: [
              {
                image: 'prom/prometheus',
                imagePullPolicy: 'IfNotPresent',
                name: 'prometheus',
                ports: [
                  {
                    containerPort: 9090,
                    name: 'api',
                  },
                ],
              },
            ],
          },
        },
      },
    },
    service: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        labels: {
          name: 'prometheus',
        },
        name: 'prometheus',
      },
      spec: {
        ports: [
          {
            name: 'prometheus-api',
            port: 9090,
            targetPort: 9090,
          },
        ],
        selector: {
          name: 'prometheus',
        },
      },
    },
  },
}
```

At the moment, this is even more verbose because we have effectively converted
YAML to JSON, which requires more characters by design.

But Jsonnet opens up enough possibilities to improve this a lot, which will be
covered in the next sections.

## Taking a look at the generated resources

So far so good, but can we make sure Tanka correctly finds our resources? We
can! By running `tk show` you can see the good old yaml, just as `kubectl`
receives it:

```yaml
# run from the project root:
/prom-grafana$ tk show environments/default
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
spec:
  selector:
# ...
```

Spend some time here and try to identify resources from the output in the
`.jsonnet` source.

> **Bonus:** There is also `tk eval`, which displays the raw JSON object
> `main.jsonnet` evaluates to. Tanka won't extract resources or mutate the structure
> here, so you can verify how your Jsonnet works.

## Connecting to the cluster

The YAML looks as expected? Let's apply it to the cluster. To do so, Tanka needs
some additional configuration.

While `kubectl` uses a `$KUBECONFIG` environment variable and a file in the home
directory to store the currently selected cluster, Tanka takes a more explicit
approach:

Each environment has a file called `spec.json`, which includes the information
to select a cluster:

```js
{
  "apiVersion": "tanka.dev/v1alpha1",
  "kind": "Environment",
  "metadata": {
    "name": "default"
  },
  "spec": {
    "apiServer": "https://127.0.0.1:6443", // cluster to use
    "namespace": "monitoring" // default namespace for all created resources
  }
}
```

You still have to setup a cluster in `$KUBECONFIG` that matches this IP – Tanka
will automatically find and use it. This also means that all of your `kubectl`
clusters just work.

This allows us to make sure that you will never accidentally apply to the wrong
cluster.

> **Note**: Tanka won't create the namespace for you -- you need to include it in
> Jsonnet by adding it to `environments/default/main.jsonnet`:
> ```jsonnet
> {
>   my_namespace: {
>     apiVersion: "v1",
>     kind: "Namespace",
>     metadata: {
>       name: "monitoring"
>     }
>   }
> }
> ```
>
> Alternatively, you can create the namespace manually:
>
> ```bash
> $ kubectl create ns monitoring
> ```
>
> This, however, will create an object that is not tracked by Tanka
> and thus needs to be taken care of via other means.

## Verifying the changes

Before applying to the cluster, Tanka gives you a chance to check that your
changes actually behave as expected: `tk diff` works just like `git diff` – you
see what will be changed.

```diff
/prom-grafana$ tk diff environments/default
--- /tmp/LIVE-610130621/apps.v1.Deployment.monitoring.grafana        2019-12-17 20:14:45.213363586 +0100
+++ /tmp/MERGED-517481208/apps.v1.Deployment.monitoring.grafana      2019-12-17 20:14:45.213363586 +0100
@@ -0,0 +1,45 @@
+apiVersion: apps/v1
+kind: Deployment
+metadata:
+  name: grafana
+  namespace: monitoring
+  # ...
+spec:
+  selector:
+    matchLabels:
+      name: grafana
+  strategy:
+    rollingUpdate:
+      maxSurge: 25%
+      maxUnavailable: 25%
+    type: RollingUpdate
+  template:
+    metadata:
+      creationTimestamp: null
+      labels:
+        name: grafana
+    spec:
+      containers:
+      - image: grafana/grafana
+        imagePullPolicy: IfNotPresent
+    # ...
```

As you can see, it shows everything as to-be created .. just as we'd expect,
since we are using a blank namespace.

> **Note**: Diff may fail before the first apply when the namespace does not yet
> exist. This is a limitation of `kubectl` which is used for computing the
> differences.

## Applying to the cluster

Once it's all looking good, `tk apply` serves the exact same purpose as `kubectl apply`:

```bash
/prom-grafana$ tk apply environments/default
Applying to namespace 'monitoring' of cluster 'default' at 'https://127.0.0.1:6443' using context 'default'.
Please type 'yes' to confirm: yes
deployment.apps/grafana created
deployment.apps/prometheus created
service/grafana created
service/prometheus created
```

It shows you the diff first and the chosen cluster once more and requires
interactive approval (type `yes`).

After that, `kubectl` is used to apply to the cluster. By **piping to
`kubectl`** Tanka makes sure it **behaves exactly** as you would expect it. No
edge-cases of differing Kubernetes client implementations should ever occur.

## Checking it worked

Again, let's connect to Grafana:

```bash
$ kubectl port-forward --namespace=monitoring deployments/grafana 8080:3000

