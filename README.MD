## Descendent Service Chart

This is a wrapper around the archetype chart as an example of creating a standardized pattern for a specific need.

Deploying this chart deploys the docker image from `https://github.com/zloeber/hello-world-pipeline/` by default

## Service Monitoring

Quick Note on the ordering of what is monitoried
```bash
Prometheus Instance
- Matches to a ServiceMonitor label (prometheus: kube-prometheus)
    - Monitors a Service
        - Matches to service labels
            - On a defined namespace
```