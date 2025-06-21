In the project root:

```
podman build -f Containerfile-min -t quay.io/kugupta/centos-ramalama-min .
```

If doing multi-arch:
```
podman manifest create quay.io/kugupta/centos-ramalama-min:latest quay.io/kugupta/centos-ramalama-min:arm64 quay.io/kugupta/centos-ramalama-min:amd64
```
