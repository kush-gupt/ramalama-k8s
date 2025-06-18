FROM quay.io/kugupta/qwen3-4b-q4-k-m:latest AS model_source

# Stage 2: Use the Ramalama application image as our final base
FROM quay.io/ramalama/ramalama:0.9.2

# Copy the entire /models directory from the "model_source" stage
# into the final application image.
COPY --from=model_source /models /models

# This is a sanity check for OpenShift's random user ID.
RUN chmod -R a+rX /models

# Optional: Add labels to describe your new all-in-one image
LABEL maintainer="Kush Gupta"
LABEL description="All-in-one Ramalama server with embedded Qwen-4B model."