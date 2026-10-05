# neurok8s-vs-code

A containerized, browser-based VS Code ([code-server](https://github.com/coder/code-server)) environment built on Red Hat UBI 9, intended as a base image for neuroimaging on OpenShift and Kubernetes.

## Ports

| Port   | Service     |
|--------|-------------|
| `8080` | code-server |
| `2222` | SSH         |
