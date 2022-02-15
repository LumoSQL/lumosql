# Spawning LumoSQL Benchmarks on Kubernetes

This service is deployed on the VUB OpenCloudEdge Kubernetes cluster, so your
cluster will look different but the [results should be similar](https://lumosql.opencloudedge.be/results).

The generated files are:

- give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite (the actual benchmark data)
- give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite.stdout (stdout of `make benchmark`)
- give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite.stderr (stderr of `make benchmark`)
- give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite.txt (`Makefile.local` contents)
- give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite.{cpuinfo,meminfo} (information about the system that ran the job)

If the .sqlite file appears corrupt the job probably hasn't finished running
yet. You can test for corruption/incompletion with the command:
```
sqlite3 $filename.sqlite "PRAGMA integrity_check"
```

To operate the job system:

1. Set your DNS names in setup.yaml.  Probably you want to look for lumosql.opencloudedge.be and change that to something you control, and possibly also change your ingress and PVC settings to something that your cluster supports.
2. Create swq token: `kubectl create secret generic swq-token --from-literal=token=your-very-secret-token`
3. Deploy the thing: `kubectl apply -f ./setup.yaml`
4. Send work with curl: `curl -L -H "Authorization: Bearer your-very-secret-token" -X PUT lumosql.opencloudedge.be/job/give-your-job-a-sensible-name  --data-binary @Makefile.local`

# Linux Image

A Linux image satisfying the [Build Environment and
Dependencies](https://lumosql.org/src/lumosql/doc/trunk/README.md) is invoked
for every run. The LumoSQL tree is updated with the command "fossil update",
the supplied Makefile.local is copied to the top level and then make is invoked
with the parameters in the yaml files. Not-forking does have the ability to
upgrade itself, but instead we keep it manually up to date in the image for
now.
