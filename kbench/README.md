# Spawning benchmarks on Kubernetes

1. Set your DNS names in setup.yaml.  Probably you want to look for lumosql.opencloudedge.be and change that to something you control, and possibly also change your ingress and PVC settings to something that your cluster supports.
2. Create swq token: `kubectl create secret generic swq-token --from-literal=token=your-very-secret-token`
3. Deploy the thing: `kubectl apply -f ./setup.yaml`
4. Send work with curl: `curl -L -H "Authorization: Bearer your-very-secret-token" -X PUT lumosql.opencloudedge.be/job/give-your-job-a-sensible-name  --data-binary @Makefile.local`

Currently, this service is deployed on the VUB OpenCloudEdge cluster,
and results can be seen on https://lumosql.opencloudedge.be/results
The generated files are:

- lumosql-give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite (the actual benchmark data)
- lumosql-give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite.stdout (stdout of `make benchmark`)
- lumosql-give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite.stderr (stderr of `make benchmark`)
- lumosql-give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite.txt (`Makefile.local` contents)
- lumosql-give-your-job-a-sensible-name-$(date +%Y-%m-%d).sqlite.{cpuinfo,meminfo} (information about the system that ran the job)
