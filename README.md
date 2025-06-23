# Chainguard Libraries for Python Demo

This branch shows a simple Flask application containerized using Chainguard Images and served with Gunicorn. In the demo for the Chainguard Libraries for Python Learning Lab, we'll switch this project to use Chainguard Libraries for Python to source dependencies.

Build with:

```bash
docker build . -t libraries-demo
```

Run with:

```bash
docker run -it -p 8000:8000 libraries-demo
```
